import uuid
import asyncio
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
    Ref: Section 9 & Section 4.19
    """
    five_minutes_ago = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    try:
        # Get active cameras with stale heartbeat (deleted_at IS NULL, status = 'online', last_heartbeat < 5 mins ago)
        response = supabase.table("cameras")\
            .select("*")\
            .eq("status", "online")\
            .is_("deleted_at", "null")\
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
            
            # 3. Push SYSTEM alert to the owner of the household
            owner_notified = False
            try:
                # First check households table for owner_user_id
                hh_res = supabase.table("households").select("owner_user_id").eq("id", household_id).execute()
                if hh_res.data and hh_res.data[0].get("owner_user_id"):
                    owner_user_id = hh_res.data[0]["owner_user_id"]
                    await send_push(owner_user_id, system_event)
                    owner_notified = True
                else:
                    # Fallback to household_members table check for owner role
                    members_res = supabase.table("household_members")\
                        .select("user_id")\
                        .eq("household_id", household_id)\
                        .eq("role", "owner")\
                        .execute()
                    for m in (members_res.data or []):
                        if m.get("user_id"):
                            await send_push(m["user_id"], system_event)
                            owner_notified = True
            except Exception as e:
                print(f"Failed to find or notify household owner for camera offline alert: {e}")

            # Backup fallback if no owner was notified
            if not owner_notified:
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
        response = supabase.table("events")\
            .select("*")\
            .eq("status", "pending")\
            .not_.is_("escalate_after", "null")\
            .lte("escalate_after", now)\
            .execute()
            
        for event in (response.data or []):
            await run_escalation(event)
    except Exception as e:
        print(f"Error querying pending escalations: {e}")

async def retry_critical_calls():
    """
    Chạy mỗi 2 phút. Tìm event CRITICAL còn pending 
    (chưa được acknowledge) và gọi lại.
    """
    try:
        now = datetime.now(timezone.utc).isoformat()
        # Tìm event CRITICAL còn pending, đã tạo > 2 phút trước
        two_min_ago = (datetime.now(timezone.utc) - timedelta(minutes=2)).isoformat()
        
        response = supabase.table("events")\
            .select("*")\
            .eq("severity", "CRITICAL")\
            .eq("status", "pending")\
            .lte("created_at", two_min_ago)\
            .execute()

        for event in response.data:
            household_id = event["household_id"]
            
            # Lấy contacts
            contacts_res = supabase.table("contacts")\
                .select("user_id, priority_order, users(phone)")\
                .eq("household_id", household_id)\
                .order("priority_order")\
                .execute()
            
            phone_numbers = [
                c["users"]["phone"] 
                for c in contacts_res.data 
                if c.get("users") and c["users"].get("phone")
            ]
            
            if phone_numbers:
                from app.services.call_service import make_calls
                await asyncio.to_thread(
                    make_calls,
                    phone_numbers,
                    event["event_id"],
                    event.get("room", "không xác định")
                )
                print(f"[scheduler] Retry call for CRITICAL event {event['event_id']}")

    except Exception as e:
        print(f"Error in retry_critical_calls: {e}")


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

async def escalate_pending_events() -> None:
    """
    Tự động đếm thời gian cho các sự kiện đang pending (cấp độ thấp)
    và nâng cấp mức độ cảnh báo nếu người dùng vẫn chưa đứng dậy.
    """
    try:
        from app.services.severity_engine import classify_severity
        from app.db.queries import get_thresholds
        from app.services.alert_engine import process_event
        
        now = datetime.now(timezone.utc)
        
        # Chỉ quét các sự kiện fall đang pending (LOW, MEDIUM, HIGH)
        response = supabase.table("events")\
            .select("*")\
            .eq("status", "pending")\
            .eq("event_type", "fall")\
            .execute()
            
        for event in (response.data or []):
            event_id = event.get("id")
            created_at_str = event.get("created_at")
            if not created_at_str:
                continue
                
            try:
                created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
            except Exception:
                continue
                
            duration_sec = int((now - created_at).total_seconds())
            
            # Cập nhật duration_sec mới nhất vào DB
            supabase.table("events").update({"duration_sec": duration_sec}).eq("id", event_id).execute()
            
            # Tính toán lại severity
            household_id = event.get("household_id")
            thresholds = await get_thresholds(household_id)
            new_severity = classify_severity(duration_sec, thresholds)
            
            current_severity = event.get("severity")
            
            # Bảng xếp hạng mức độ
            severity_levels = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}
            
            curr_level = severity_levels.get(current_severity, 1)
            new_level = severity_levels.get(new_severity, 1)
            
            # Nếu mức độ tăng lên, cập nhật và bắn AlertEngine
            if new_level > curr_level:
                print(f"[scheduler] Escalate event {event_id} from {current_severity} to {new_severity} (duration: {duration_sec}s)")
                supabase.table("events").update({"severity": new_severity}).eq("id", event_id).execute()
                
                # Sửa event data để truyền vào AlertEngine
                event["severity"] = new_severity
                event["duration_sec"] = duration_sec
                
                # Kích hoạt lại process_event để nó gọi send_push và các logic khác
                await process_event(event)

    except Exception as e:
        print(f"Error in escalate_pending_events: {e}")

