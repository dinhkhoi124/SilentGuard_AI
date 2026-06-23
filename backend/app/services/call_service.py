from twilio.rest import Client
from app.core.config import settings

def make_calls(phone_numbers: list[str], event_id: str, room: str) -> dict:
    """
    Gọi đồng thời tất cả số điện thoại trong danh sách.
    Trả về dict {phone_number: call_sid} để track.
    """
    if not settings.TWILIO_ACCOUNT_SID or \
       not settings.TWILIO_AUTH_TOKEN or \
       not settings.TWILIO_PHONE_NUMBER:
        print("[call_service] Twilio chưa được cấu hình, bỏ qua auto-call")
        return {}

    client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    results = {}

    message = (
        f"Canh bao khan cap. Nguoi than bi phat hien nga trong {room} "
        f"va bat dong hon 5 phut. Vui long kiem tra ngay lap tuc."
    )

    for phone in phone_numbers:
        try:
            if not settings.TWILIO_FLOW_SID:
                print("[call_service] TWILIO_FLOW_SID chưa được cấu hình, bỏ qua gọi")
                continue

            execution = client.studio.v2.flows(settings.TWILIO_FLOW_SID)\
                .executions\
                .create(
                    to=phone,
                    from_=settings.TWILIO_PHONE_NUMBER,
                )
            results[phone] = execution.sid
            print(f"[call_service] Calling {phone}: {execution.sid}")
        except Exception as e:
            print(f"[call_service] Failed to call {phone}: {e}")

    return results
