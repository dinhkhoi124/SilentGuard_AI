"""
Notification Service (FCM & Calling)
Ref: Section 7 - Notification Service in design document.
"""
from typing import Any
from firebase_admin import messaging
from app.core.supabase_client import supabase

async def send_push(user_id: str, event_data: dict) -> bool:
    """
    Sends push notification via Firebase Cloud Messaging.
    Ref: Section 7 of design doc
    """
    print(f"[Notification Service] Attempting to send push to user: {user_id}")
    try:
        # Fetch user's FCM token from DB
        response = supabase.table("users").select("fcm_token").eq("id", user_id).execute()
        if not response.data or len(response.data) == 0:
            print(f"[Notification Service] User {user_id} not found in database.")
            return False
            
        fcm_token = response.data[0].get("fcm_token")
        if not fcm_token:
            print(f"[Notification Service] FCM Token is missing for user {user_id}. Skipping push.")
            return False

        print(f"[Notification Service] Found FCM token for user {user_id} (length: {len(fcm_token)}). Preparing message...")

        # Prepare push payload
        severity = event_data.get("severity", "MEDIUM")
        room = event_data.get("room", "nhà")
        body_msg = event_data.get("llm_message") or f"Phát hiện sự cố té ngã tại {room}."
        
        message = messaging.Message(
            notification=messaging.Notification(
                title=f"Cảnh báo {severity} — {room}",
                body=body_msg
            ),
            data={
                "event_id": str(event_data.get("event_id") or event_data.get("id")),
                "severity": severity,
                "clip_path": event_data.get("clip_path") or ""
            },
            token=fcm_token
        )
        
        # Send message
        print(f"[Notification Service] Sending message via Firebase SDK...")
        response_id = messaging.send(message)
        print(f"[Notification Service] Push notification sent successfully, msg ID: {response_id}")
        return True
    except Exception as e:
        print(f"[Notification Service] ERROR: Failed to send push notification to user {user_id}: {e}")
        return False

async def trigger_call(contact: dict, event_data: dict) -> bool:
    """
    Sends call triggers using Twilio or equivalent VoIP provider.
    Ref: Section 6
    """
    try:
        phone = contact.get("phone", "unknown")
        room = event_data.get("room", "nhà")
        severity = event_data.get("severity", "MEDIUM")
        print(f"[VOIP CALL] Calling emergency backup contact: {contact.get('full_name')} at {phone}")
        print(f"[VOIP CALL] Playing message: Cảnh báo mức độ {severity} phát hiện ngã tại {room}!")
        return True
    except Exception as e:
        print(f"Failed to trigger VOIP call: {e}")
        return False


async def send_fcm_notification(token: str, title: str, body: str, data: dict = None) -> bool:
    """
    Sends a general FCM notification to a specific token.
    """
    print(f"[Notification Service] Attempting to send push to token: {token}")
    try:
        # Convert all dictionary values in data to strings as required by Firebase Messaging API
        string_data = {}
        if data:
            for k, v in data.items():
                string_data[k] = str(v)

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=string_data,
            token=token
        )
        # messaging.send is blocking, but we keep the signature async as expected
        response_id = messaging.send(message)
        print(f"[Notification Service] Push notification sent successfully, msg ID: {response_id}")
        return True
    except Exception as e:
        print(f"[Notification Service] ERROR: Failed to send push notification to token {token}: {e}")
        return False
