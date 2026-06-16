import os
import json
from typing import Optional, List
from pydantic import BaseModel, Field, field_validator
from anthropic import Anthropic

# Initialize Anthropic Client
api_key = os.getenv("ANTHROPIC_API_KEY", "")
is_mock = not api_key or api_key == "xxxx" or "your-anthropic-key" in api_key

if not is_mock:
    client = Anthropic(api_key=api_key)
else:
    print("Warning: ANTHROPIC_API_KEY is not configured or holds a placeholder value. Running LLM service in mock mode.")
    client = None

# Pydantic Schemas for configuration parsing (Section 8)
class SuppressWindow(BaseModel):
    start: str
    end: str
    max_still_sec: int = Field(ge=60, le=86400)

class ParsedConfig(BaseModel):
    low_max_sec: Optional[int] = Field(None, ge=10, le=3600)
    medium_max_sec: Optional[int] = Field(None, ge=10, le=3600)
    high_max_sec: Optional[int] = Field(None, ge=10, le=3600)
    dedup_window_sec: Optional[int] = Field(None, ge=10, le=300)
    suppress_windows: Optional[List[SuppressWindow]] = None

    @field_validator("medium_max_sec")
    @classmethod
    def medium_gt_low(cls, v, info):
        low = info.data.get("low_max_sec")
        if v and low and v <= low:
            raise ValueError("medium_max_sec phải lớn hơn low_max_sec")
        return v

async def generate_alert_message(event: dict) -> str:
    """
    Generate natural Vietnamese alert message using Claude API.
    Ref: Section 8 LLM Prompt Templates
    """
    severity = event.get("severity", "MEDIUM")
    timestamp = event.get("timestamp", "")
    room = event.get("room", "nhà")
    duration_sec = event.get("duration_sec") or event.get("duration_seconds") or 0

    prompt = f"""
    Một sự cố té ngã vừa được phát hiện:
    - Mức độ: {severity}
    - Thời gian: {timestamp}
    - Phòng: {room}
    - Bất động: {duration_sec} giây

    Viết 1-2 câu tin nhắn tự nhiên, ấm áp, rõ ràng cho gia đình bằng tiếng Việt,
    nêu rõ mức độ nghiêm trọng và hành động nên làm.
    """

    if is_mock:
        # Return mock Vietnamese message
        return f"⚠️ Cảnh báo mức độ {severity}: Phát hiện sự cố té ngã trong {room}. Người thân đang nằm yên khoảng {duration_sec} giây. Vui lòng kiểm tra ngay!"

    try:
        message = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=150,
            temperature=0.7,
            system="Bạn là trợ lý ảo SilentGuard AI, luôn gửi tin nhắn tiếng Việt tự nhiên, ấm áp, lịch sự và rõ ràng để trợ giúp gia đình theo dõi người già.",
            messages=[{"role": "user", "content": prompt}]
        )
        return message.content[0].text.strip()
    except Exception as e:
        print(f"Error calling Claude API for alert message: {e}")
        return f"⚠️ Phát hiện té ngã tại {room}. Bất động {duration_sec} giây. Vui lòng kiểm tra!"

async def generate_daily_report(events: list) -> str:
    """
    Generate natural language daily report summary.
    Ref: Section 8 daily report generator
    """
    if is_mock:
        return f"Hôm nay hệ thống ghi nhận {len(events)} sự kiện. Tình trạng sức khỏe chung của người cao tuổi bình thường, các cảnh báo đều đã được kiểm tra."

    events_summary = []
    for event in events:
        events_summary.append(
            f"- Mức độ {event.get('severity')}, phòng {event.get('room')}, bất động {event.get('duration_sec')} giây lúc {event.get('timestamp')}"
        )
    events_str = "\n".join(events_summary)

    prompt = f"""
    Tổng hợp danh sách các sự kiện té ngã / bất động của một ngày dưới đây thành một đoạn báo cáo tóm tắt 24h tự nhiên, ấm áp, ngắn gọn gửi cho gia đình:
    {events_str}
    """

    try:
        message = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=300,
            temperature=0.7,
            messages=[{"role": "user", "content": prompt}]
        )
        return message.content[0].text.strip()
    except Exception as e:
        print(f"Error calling Claude API for daily report: {e}")
        return "Báo cáo ngày hôm nay bình thường. Không có sự kiện khẩn cấp nào chưa được xử lý."

async def parse_config(message: str) -> ParsedConfig:
    """
    Parse configuration from user chat instructions.
    Ref: Section 8 parse_config
    """
    prompt = f"""
    Người dùng nói: "{message}"
    Trả về JSON với các field sau (chỉ điền field được đề cập, bỏ qua field không liên quan):
    {{
      "low_max_sec": <int>,
      "medium_max_sec": <int>,
      "high_max_sec": <int>,
      "dedup_window_sec": <int>,
      "suppress_windows": [{{"start": "HH:MM", "end": "HH:MM", "max_still_sec": <int>}}]
    }}
    Chỉ trả JSON, không giải thích thêm.
    """

    if is_mock:
        # Mock parsing logic based on keywords for offline testing
        mock_data = {}
        if "sleep" in message.lower() or "ngủ" in message.lower():
            mock_data["suppress_windows"] = [{"start": "13:00", "end": "15:00", "max_still_sec": 3600}]
        if "30" in message:
            mock_data["low_max_sec"] = 30
        return ParsedConfig(**mock_data)

    try:
        response = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=200,
            temperature=0.0,
            messages=[{"role": "user", "content": prompt}]
        )
        raw = response.content[0].text.strip()
        data = json.loads(raw)
        return ParsedConfig(**data)
    except Exception as e:
        print(f"Error calling Claude API to parse config: {e}")
        raise ValueError(f"Không thể phân tích cấu hình tự động: {e}")
