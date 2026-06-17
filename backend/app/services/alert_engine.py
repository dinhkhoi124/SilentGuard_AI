import asyncio
from datetime import datetime, timedelta
from app.core.supabase_client import supabase
from app.db.queries import get_thresholds, get_contacts_sorted, save_event
from app.services.severity_engine import classify_severity, is_suppressed
from app.services.notification_service import send_push
from app.services.llm_service import generate_alert_message

async def process_event(event_data: dict) -> None:
    """
    Process alert engine logic: dedup, suppress, severity check, push, and escalation scheduling.
    Ref: Section 6 Alert Engine & Notification Flow
    """
    event_id = event_data.get("id")
    household_id = event_data.get("household_id")
    event_type = event_data.get("event_type", "fall")
    timestamp_str = event_data.get("timestamp")
    duration_sec = event_data.get("duration_sec") or 0
    
    # Parse timestamp
    try:
        event_time = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
    except Exception:
        event_time = datetime.now()

    # Fetch thresholds config
    thresholds = await get_thresholds(household_id)

    # 1. Dedup check
    dedup_window = thresholds.get("dedup_window_sec", 60)
    dedup_time = event_time - timedelta(seconds=dedup_window)
    try:
        dup_query = supabase.table("events")\
            .select("id")\
            .eq("household_id", household_id)\
            .eq("event_type", event_type)\
            .neq("status", "logged_only")\
            .gt("timestamp", dedup_time.isoformat())\
            .neq("id", event_id)\
            .execute()
        
        if dup_query.data and len(dup_query.data) > 0:
            # Duplicate found, set status to logged_only and return
            event_data["status"] = "logged_only"
            await save_event(event_data)
            return
    except Exception as e:
        print(f"Error checking duplicate events: {e}")

    # 2. Suppress check
    if is_suppressed(event_time, duration_sec, thresholds.get("suppress_windows")):
        event_data["status"] = "logged_only"
        await save_event(event_data)
        return

    # 3. Reclassify severity according to thresholds
    severity = classify_severity(duration_sec, thresholds)
    event_data["severity"] = severity
    
    if severity == "LOW":
        event_data["status"] = "logged_only"
        await save_event(event_data)
        return

    # 4. Push TRƯỚC với default message đến liên hệ chính
    contacts = await get_contacts_sorted(household_id)
    if contacts:
        primary = contacts[0]
        # Set default message
        event_data["llm_message"] = f"Cảnh báo ngã phát hiện tại {event_data.get('room', 'nhà')}."
        await send_push(primary.get("user_id"), event_data)
        
        # Log escalation
        try:
            escalation_entry = {
                "event_id": event_id,
                "contact_id": primary.get("id"),
                "channel": "push",
                "status": "sent"
            }
            supabase.table("escalations").insert(escalation_entry).execute()
        except Exception as e:
            print(f"Error logging primary escalation trace: {e}")

    # 5. Set escalate_after cho các sự kiện khẩn cấp
    created_at_str = event_data.get("created_at") or datetime.now().isoformat()
    try:
        created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
    except Exception:
        created_at = datetime.now()
        
    if severity in ("HIGH", "CRITICAL"):
        event_data["escalate_after"] = (created_at + timedelta(seconds=180)).isoformat()
        
    await save_event(event_data)

    # 6. Sinh tin nhắn Claude async
    asyncio.create_task(_generate_and_update_llm_message(event_id))

async def _generate_and_update_llm_message(event_id: str) -> None:
    """
    Generate message async with 10s timeout fallback.
    Ref: Section 6
    """
    try:
        # Fetch latest event state
        response = supabase.table("events").select("*").eq("id", event_id).execute()
        if not response.data:
            return
        event = response.data[0]
        
        # Call LLM Claude Service with timeout
        llm_msg = await asyncio.wait_for(
            generate_alert_message(event), timeout=10.0
        )
        if llm_msg:
            # Update DB with generated message
            supabase.table("events").update({"llm_message": llm_msg}).eq("id", event_id).execute()
    except Exception as e:
        print(f"LLM async generation fallback / timeout: {e}")
