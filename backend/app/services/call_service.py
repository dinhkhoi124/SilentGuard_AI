from twilio.rest import Client
from app.core.config import settings

def make_calls(phone_numbers: list[str], event_id: str, room: str) -> dict:
    if not settings.TWILIO_ACCOUNT_SID or \
       not settings.TWILIO_AUTH_TOKEN or \
       not settings.TWILIO_PHONE_NUMBER or \
       not settings.TWILIO_FLOW_SID:
        print("[call_service] Twilio chưa được cấu hình đầy đủ, bỏ qua auto-call")
        return {}

    client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    results = {}

    for phone in phone_numbers:
        try:
            execution = client.studio.v2\
                .flows(settings.TWILIO_FLOW_SID)\
                .executions\
                .create(
                    to=phone,
                    from_=settings.TWILIO_PHONE_NUMBER,
                    parameters={
                        "phone": phone,
                        "event_id": event_id,
                        "room": room
                    }
                )
            results[phone] = execution.sid
            print(f"[call_service] Flow execution started for {phone}: {execution.sid}")
        except Exception as e:
            print(f"[call_service] Failed to call {phone}: {e}")

    return results
