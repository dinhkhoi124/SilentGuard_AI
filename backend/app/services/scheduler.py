import uuid
import asyncio
from datetime import datetime, timezone, timedelta
from app.core.supabase_client import supabase
from app.db.queries import get_contacts_sorted
from app.services.notification_service import send_push, trigger_call

# Mức độ severity để so sánh khi leo thang
_SEVERITY_LEVELS = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}

# Status được coi là "đã xử lý" — bỏ qua khi leo thang
_CLOSED_STATUSES = ("resolved", "acknowledged", "escalated", "logged_only")

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
    [BUG-4 FIX] Skip events đã acknowledged/resolved/escalated.
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
            # Guard: skip nếu đã closed trong lúc chờ
            if event.get("status") in _CLOSED_STATUSES:
                continue
            await run_escalation(event)
    except Exception as e:
        print(f"Error querying pending escalations: {e}")

async def retry_critical_calls():
    """
    [TWILIO FIX] Chạy mỗi 2 phút.
    Trước đây: gọi điện lặp lại → spam Twilio.
    Hiện tại: chỉ gửi push reminder — gọi điện duy nhất 1 lần khi
    severity lần đầu leo lên CRITICAL trong escalate_pending_events().
    """
    try:
        two_min_ago = (datetime.now(timezone.utc) - timedelta(minutes=2)).isoformat()

        response = supabase.table("events")\
            .select("*")\
            .eq("severity", "CRITICAL")\
            .eq("status", "pending")\
            .lte("created_at", two_min_ago)\
            .execute()

        for event in (response.data or []):
            household_id = event["household_id"]
            contacts = await get_contacts_sorted(household_id)
            room = event.get("room", "nhà")
            duration_sec = event.get("duration_sec", 0)
            event["llm_message"] = (
                f"🚨 NHẮC LẠI: Ngã khẩn cấp tại {room}. "
                f"Đã nằm {duration_sec}s. Vui lòng xác nhận ngay!"
            )
            for contact in contacts:
                await send_push(contact.get("user_id"), event)
            print(f"[scheduler] CRITICAL push reminder for event {event.get('event_id')}")

    except Exception as e:
        print(f"Error in retry_critical_calls: {e}")


async def run_escalation(event: dict) -> None:
    """
    Gọi backup contacts khi event quá hạn escalate_after.
    [BUG-4 FIX] Skip nếu event đã acknowledged/resolved.
    Ref: Section 6 run_escalation
    """
    event_id = event.get("id")
    household_id = event.get("household_id")
    severity = event.get("severity")

    # Guard: re-fetch status để tránh race condition
    try:
        fresh = supabase.table("events").select("status").eq("id", event_id).execute()
        if fresh.data and fresh.data[0].get("status") in _CLOSED_STATUSES:
            print(f"[run_escalation] Event {event_id} đã closed ({fresh.data[0]['status']}), bỏ qua.")
            return
    except Exception:
        pass

    contacts = await get_contacts_sorted(household_id)

    if len(contacts) < 2:
        try:
            supabase.table("events").update({"escalate_after": None}).eq("id", event_id).execute()
        except Exception as e:
            print(f"Failed to clear escalate_after: {e}")
        return

    try:
        if severity == "CRITICAL":
            # CRITICAL: gọi TẤT CẢ backup contacts — 1 lần duy nhất tại đây
            for c in contacts[1:]:
                await trigger_call(c, event)
                await send_push(c.get("user_id"), event)
                supabase.table("escalations").insert({
                    "event_id": event_id,
                    "contact_id": c.get("id"),
                    "channel": "call",
                    "status": "sent"
                }).execute()
        else:  # HIGH
            # HIGH: gọi backup contact đầu tiên — 1 lần duy nhất
            next_contact = contacts[1]
            await trigger_call(next_contact, event)
            supabase.table("escalations").insert({
                "event_id": event_id,
                "contact_id": next_contact.get("id"),
                "channel": "call",
                "status": "sent"
            }).execute()

        supabase.table("events").update({
            "escalate_after": None,
            "status": "escalated"
        }).eq("id", event_id).execute()

    except Exception as e:
        print(f"Failed to execute escalation for event {event_id}: {e}")


async def _notify_escalation(event: dict) -> None:
    """
    Push notification khi severity leo thang.
    [BUG-1 FIX] KHÔNG gọi process_event() — không có dedup, không có suppress.
    Chỉ push thuần đến tất cả contacts với message phù hợp mức độ mới.
    """
    household_id = event.get("household_id")
    event_id = event.get("id")
    severity = event.get("severity", "MEDIUM")
    room = event.get("room") or "nhà"
    duration_sec = event.get("duration_sec") or 0

    _severity_messages = {
        "MEDIUM": f"Cảnh báo: Phát hiện ngã tại {room}. Đã nằm {duration_sec}s.",
        "HIGH":   f"⚠️ CẢNH BÁO CAO: Ngã tại {room}. Đã nằm {duration_sec}s. Kiểm tra ngay!",
        "CRITICAL": f"🚨 KHẨN CẤP: Ngã tại {room}. Đã nằm {duration_sec}s. Gọi cấp cứu ngay!",
    }
    event["llm_message"] = _severity_messages.get(severity, f"Cảnh báo ngã tại {room}.")

    contacts = await get_contacts_sorted(household_id)
    for contact in contacts:
        await send_push(contact.get("user_id"), event)
        try:
            supabase.table("escalations").insert({
                "event_id": event_id,
                "contact_id": contact.get("id"),
                "channel": "push",
                "status": "sent"
            }).execute()
        except Exception as e:
            print(f"[_notify_escalation] Log error: {e}")


async def escalate_pending_events() -> None:
    """
    Leo thang severity tự động mỗi 30s.

    [BUG-1 FIX] Thay thế gọi process_event() bằng _notify_escalation()
                → tránh dedup loop kill alert escalation.
    [BUG-2 FIX] duration_sec = max(db_duration_sec, elapsed_since_created)
                → đồng bộ với heartbeat từ Edge AI.
    [BUG-4 FIX] Skip events đã acknowledged/resolved/escalated.
    [TWILIO FIX] Gọi điện 1 lần duy nhất khi severity lần đầu đạt CRITICAL.
    """
    try:
        from app.services.severity_engine import classify_severity
        from app.db.queries import get_thresholds

        now = datetime.now(timezone.utc)

        # Chỉ scan fall events đang pending — bỏ qua mọi status đã đóng
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

            # [BUG-2 FIX] Lấy duration từ cả 2 nguồn, dùng giá trị lớn hơn
            elapsed_sec = int((now - created_at).total_seconds())
            db_duration_sec = event.get("duration_sec") or 0
            duration_sec = max(db_duration_sec, elapsed_sec)

            # Cập nhật duration_sec mới nhất vào DB
            supabase.table("events").update(
                {"duration_sec": duration_sec}
            ).eq("id", event_id).execute()

            household_id = event.get("household_id")
            thresholds = await get_thresholds(household_id)
            new_severity = classify_severity(duration_sec, thresholds)
            current_severity = event.get("severity")

            curr_level = _SEVERITY_LEVELS.get(current_severity, 1)
            new_level = _SEVERITY_LEVELS.get(new_severity, 1)

            if new_level > curr_level:
                print(
                    f"[scheduler] Leo thang event {event_id}: "
                    f"{current_severity} → {new_severity} (duration={duration_sec}s)"
                )

                update_payload = {"severity": new_severity}

                # Đặt escalate_after khi lần đầu đạt HIGH
                # → run_escalation() sẽ gọi backup contact sau 3p
                if new_severity == "HIGH":
                    update_payload["escalate_after"] = (
                        now + timedelta(seconds=180)
                    ).isoformat()

                supabase.table("events").update(update_payload).eq("id", event_id).execute()

                event["severity"] = new_severity
                event["duration_sec"] = duration_sec

                # [BUG-1 FIX] Push thuần — không qua process_event() để tránh dedup
                await _notify_escalation(event)

                # [TWILIO FIX] Gọi điện 1 lần duy nhất khi lần đầu đạt CRITICAL
                if new_severity == "CRITICAL":
                    try:
                        contacts_res = supabase.table("contacts")\
                            .select("user_id, priority_order, users(phone)")\
                            .eq("household_id", household_id)\
                            .order("priority_order")\
                            .execute()
                        phone_numbers = [
                            c["users"]["phone"]
                            for c in (contacts_res.data or [])
                            if c.get("users") and c["users"].get("phone")
                        ]
                        if phone_numbers:
                            from app.services.call_service import make_calls
                            await asyncio.to_thread(
                                make_calls,
                                phone_numbers,
                                event.get("event_id"),
                                event.get("room", "không xác định")
                            )
                            print(
                                f"[scheduler] CRITICAL: gọi 1 lần duy nhất "
                                f"cho event {event.get('event_id')}"
                            )
                    except Exception as e:
                        print(f"[scheduler] Lỗi gọi Twilio CRITICAL: {e}")

    except Exception as e:
        print(f"Error in escalate_pending_events: {e}")

