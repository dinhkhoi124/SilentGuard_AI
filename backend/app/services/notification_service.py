"""
Notification Service (FCM)
Ref: Section 7 - Notification Service in design document.
"""
from firebase_admin import messaging

async def send_push(user_id: str, event: Any):
    """
    Sends push notification via Firebase Cloud Messaging.
    Ref: Section 7 of design doc
    """
    # TODO: Fetch user FCM token and send message using firebase_admin.messaging
    pass

async def trigger_call(contact: Any, event: Any):
    """
    Sends call triggers using Twilio or equivalent.
    Ref: Section 6
    """
    pass
