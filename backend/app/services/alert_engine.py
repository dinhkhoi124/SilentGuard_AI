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
    event_code = event_data.get("event_id")
    
    # If database UUID is missing or None, query the database using the unique event_code string
    if (not event_id or str(event_id).strip().lower() == "none") and event_code:
        try:
            res = supabase.table("events").select("id").eq("event_id", event_code).execute()
            if res.data and len(res.data) > 0:
                event_id = res.data[0].get("id")
                event_data["id"] = event_id
        except Exception as e:
            print(f"Error retrieving database UUID for event_code {event_code}: {e}")

    # Ensure event_id is converted to string for serialization/query checks
    if event_id:
        event_id = str(event_id)

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
        query = supabase.table("events")\
            .select("id")\
            .eq("household_id", household_id)\
            .eq("event_type", event_type)\
            .neq("status", "logged_only")\
            .gt("timestamp", dedup_time.isoformat())
        
        # Only exclude self if we have a valid database UUID
        if event_id and str(event_id).strip().lower() != "none":
            query = query.neq("id", event_id)
            
        dup_query = query.execute()
        
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
    # Bypass reclassify step if source is video_upload (keep severity = HIGH as sent by AI Engineer)
    if event_data.get("source") != "video_upload":
        severity = classify_severity(duration_sec, thresholds)
        event_data["severity"] = severity
    else:
        severity = event_data.get("severity") or "HIGH"
    


    # 4. Push TRƯỚC với default message đến liên hệ chính
    print(f"[Alert Engine] Fetching contacts for household_id: {household_id}")
    contacts = await get_contacts_sorted(household_id)
    if contacts:
        primary = contacts[0]
        print(f"[Alert Engine] Found {len(contacts)} contacts. Primary contact is: {primary.get('user_id')} ({primary.get('full_name')})")
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
    else:
        print(f"[Alert Engine] WARNING: No emergency contacts found for household_id: {household_id}")

    if severity == "CRITICAL":
        # Lấy số điện thoại của tất cả contacts trong household
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
            make_calls(
                phone_numbers=phone_numbers,
                event_id=event_data["event_id"],
                room=event_data.get("room", "không xác định")
            )


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
    if not event_id or str(event_id).strip().lower() == "none":
        print("Warning: _generate_and_update_llm_message aborted due to invalid event_id")
        return
    try:
        # Fetch latest event state
        response = supabase.table("events").select("*").eq("id", str(event_id)).execute()
        if not response.data:
            return
        event = response.data[0]
        
        # Call LLM Claude Service with timeout
        llm_msg = await asyncio.wait_for(
            generate_alert_message(event), timeout=10.0
        )
        if llm_msg:
            # Update DB with generated message
            supabase.table("events").update({"llm_message": llm_msg}).eq("id", str(event_id)).execute()
    except Exception as e:
        print(f"LLM async generation fallback / timeout: {e}")
