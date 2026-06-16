import uuid
from datetime import datetime, timezone, timedelta
from app.core.supabase_client import supabase
from app.db.queries import get_contacts_sorted
from app.services.notification_service import send_push, trigger_call

async def periodic_check_job() -> None:
    """
    Periodic check job executing every 1 minute.
    Ref: Section 9 Background Jobs & Section 6
    """
    await check_camera_heartbeats()
    await check_pending_escalations()

async def check_camera_heartbeats() -> None:
    """
    Check cameras where last_heartbeat is older than 5 minutes.
    Marks them as offline and dispatches a SYSTEM alert event.
    Ref: Section 9 & Section 4.11
    """
    five_minutes_ago = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    try:
        # Get active cameras with stale heartbeat
        response = supabase.table("cameras")\
            .select("*")\
            .eq("status", "online")\
            .lt("last_heartbeat", five_minutes_ago)\
            .execute()
        
        for camera in (response.data or []):
            camera_id = camera.get("id")
            camera_name = camera.get("name", "Camera")
            household_id = camera.get("household_id")
            
            # 1. Update camera status to offline
            supabase.table("cameras").update({"status": "offline"}).eq("id", camera_id).execute()
            
            # 2. Insert SYSTEM event
            event_id = str(uuid.uuid4())
            system_event = {
                "id": event_id,
                "event_id": f"SYS-ERR-{camera_id[:8]}",
                "household_id": household_id,
                "camera_id": camera_id,
                "event_type": "camera_offline",
                "severity": "SYSTEM",
                "confidence": 1.0,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "status": "pending",
                "llm_message": f"Cảnh báo: {camera_name} mất kết nối liên tục hơn 5 phút. Vui lòng kiểm tra lại thiết bị."
            }
            supabase.table("events").insert(system_event).execute()
            
            # 3. Push SYSTEM alert to all family members
            contacts = await get_contacts_sorted(household_id)
            for contact in contacts:
                await send_push(contact.get("user_id"), system_event)
                
    except Exception as e:
        print(f"Error checking camera heartbeats: {e}")

async def check_pending_escalations() -> None:
    """
    Retrieve and process events past their escalate_after time.
    Ref: Section 6 check_pending_escalations
    """
    now = datetime.now(timezone.utc).isoformat()
    try:
        # Query pending events past escalation time
        response = supabase.table("events")\
            .select("*")\
            .eq("status", "pending")\
            .not_ = {"escalate_after": "is.null"}\
            .lte("escalate_after", now)\
            .execute()
            
        for event in (response.data or []):
            await run_escalation(event)
    except Exception as e:
        print(f"Error querying pending escalations: {e}")

async def run_escalation(event: dict) -> None:
    """
    Escalate the alert to backup contacts in order of priority.
    Ref: Section 6 run_escalation
    """
    event_id = event.get("id")
    household_id = event.get("household_id")
    severity = event.get("severity")

    contacts = await get_contacts_sorted(household_id)
    
    # Section 6: Guard — nếu không có contact backup thì không escalate được
    if len(contacts) < 2:
        try:
            supabase.table("events").update({"escalate_after": None}).eq("id", event_id).execute()
        except Exception as e:
            print(f"Failed to clear escalate_after: {e}")
        return

    try:
        if severity == "CRITICAL":
            # For CRITICAL: escalate to all backup contacts (contacts[1:]) via push and VoIP call
            for c in contacts[1:]:
                await trigger_call(c, event)
                await send_push(c.get("user_id"), event)
                # Log escalation
                escalation_log = {
                    "event_id": event_id,
                    "contact_id": c.get("id"),
                    "channel": "call",
                    "status": "sent"
                }
                supabase.table("escalations").insert(escalation_log).execute()
        else: # HIGH
            # For HIGH: escalate to the next contact (contacts[1]) via VoIP call
            next_contact = contacts[1]
            await trigger_call(next_contact, event)
            # Log escalation
            escalation_log = {
                "event_id": event_id,
                "contact_id": next_contact.get("id"),
                "channel": "call",
                "status": "sent"
            }
            supabase.table("escalations").insert(escalation_log).execute()

        # Update event escalation status in database
        supabase.table("events").update({
            "escalate_after": None,
            "status": "escalated"
        }).eq("id", event_id).execute()
        
    except Exception as e:
        print(f"Failed to execute escalation process for event {event_id}: {e}")
