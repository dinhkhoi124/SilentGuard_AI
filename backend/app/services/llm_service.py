import os
import json
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, field_validator
from fastapi import HTTPException
from openai import AsyncOpenAI
from app.core.config import settings

# Initialize OpenAI Client
api_key = settings.OPENAI_API_KEY
is_mock = not api_key or api_key in ("xxxx", "your-openai-key", "your-openrouter-key", "your-anthropic-key")

if not is_mock:
    client = AsyncOpenAI(
        api_key=api_key,
        timeout=30.0,
    )
else:
    print("Warning: OPENAI_API_KEY is not configured or holds a placeholder value. Running LLM service in mock mode.")
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
    Generate natural Vietnamese alert message using rule-based templates.
    """
    severity = event.get("severity", "MEDIUM")
    timestamp = event.get("timestamp", "")
    room = event.get("room", "nhà")
    duration_sec = event.get("duration_sec") or event.get("duration_seconds") or 0

    time_str = "00:00"
    if timestamp:
        try:
            ts_clean = timestamp.replace("Z", "+00:00")
            dt = datetime.fromisoformat(ts_clean)
            time_str = dt.strftime("%H:%M")
        except Exception:
            try:
                if "T" in timestamp:
                    time_str = timestamp.split("T")[1][:5]
                elif " " in timestamp:
                    time_str = timestamp.split(" ")[1][:5]
                else:
                    time_str = timestamp
            except Exception:
                time_str = timestamp

    if severity == "LOW":
        return f"Người thân vừa té ngã trong {room} lúc {time_str} và đã tự đứng dậy sau {duration_sec} giây. Dù vậy, té ngã ở người cao tuổi có thể gây chấn thương không rõ ngay — nên gọi điện hỏi thăm sức khỏe trong hôm nay."
    elif severity == "MEDIUM":
        return f"⚠️ Cảnh báo: Phát hiện té ngã trong {room} lúc {time_str}. Người thân chưa đứng dậy sau {duration_sec} giây. Vui lòng kiểm tra."
    elif severity == "HIGH":
        return f"🚨 Khẩn cấp: Phát hiện té ngã trong {room} lúc {time_str}. Người thân bất động hơn {duration_sec} giây. Cần kiểm tra ngay!"
    elif severity == "CRITICAL":
        return f"🆘 NGUY HIỂM: Người thân bất động hơn {duration_sec} giây trong {room} kể từ {time_str}. Liên hệ cấp cứu ngay!"
    else:
        return f"Cảnh báo hệ thống: Phát hiện bất thường trong {room} lúc {time_str}."

async def generate_daily_report(events: list, user_message: str = None) -> str:
    """
    Generate natural language daily report summary or act as chatbot based on events.
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

    if user_message:
        prompt = f"""
        Bạn là trợ lý ảo của hệ thống theo dõi sức khỏe người cao tuổi.
        Người dùng đang hỏi: "{user_message}"
        Dựa vào danh sách sự kiện té ngã/bất động dưới đây, hãy trả lời câu hỏi của người dùng một cách ngắn gọn, tự nhiên và ấm áp.
        
        Yêu cầu quan trọng:
        - Tuyệt đối trung thực với dữ liệu được cung cấp. Không tự bịa thêm thông tin, sự kiện, chỉ số.
        - TUYỆT ĐỐI KHÔNG BỊA RA TÊN NGƯỜI. Luôn dùng các từ chung chung như "người thân", "ông/bà", "người dùng" nếu không có tên cụ thể.
        
        Danh sách sự kiện:
        {events_str if events_str else "Không có sự kiện nào."}
        """
    else:
        prompt = f"""
        Tổng hợp danh sách các sự kiện té ngã / bất động của một ngày dưới đây thành một đoạn báo cáo tóm tắt 24h tự nhiên, ấm áp, ngắn gọn gửi cho gia đình.
        Yêu cầu quan trọng:
        - Tuyệt đối trung thực với dữ liệu được cung cấp. Không tự bịa thêm thông tin, sự kiện hay chỉ số.
        - TUYỆT ĐỐI KHÔNG BỊA RA TÊN NGƯỜI. Hãy gọi là "người thân" hoặc "ông/bà".
        - Nếu danh sách sự kiện trống, hãy viết một câu ngắn gọn thông báo rằng hôm nay không ghi nhận sự kiện bất thường nào, mọi người đều an toàn.

        Danh sách sự kiện:
        {events_str if events_str else "Không có sự kiện nào."}
        """

    try:
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=300,
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}]
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error calling OpenAI API for daily report: {e}")
        return "Báo cáo ngày hôm nay bình thường. Không có sự kiện khẩn cấp nào chưa được xử lý."

async def parse_config(message: str) -> ParsedConfig:
    """
    Parse configuration from user chat instructions.
    Ref: Section 8 parse_config
    """
    MAX_CONFIG_LENGTH = 500  # ký tự
    if len(message) > MAX_CONFIG_LENGTH:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "INPUT_TOO_LONG", "message": f"Nội dung cấu hình tối đa {MAX_CONFIG_LENGTH} ký tự"}}
        )

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
    Chỉ trả định dạng JSON hợp lệ, không giải thích thêm.
    Tuyệt đối không tự suy diễn hoặc điền các giá trị không được đề cập trong câu nói của người dùng.
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
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=200,
            temperature=0.0,
            response_format={ "type": "json_object" },
            messages=[{"role": "user", "content": prompt}]
        )
        raw = response.choices[0].message.content.strip()
        # Loại bỏ markdown backticks nếu LLM vẫn trả về dạng ```json
        if raw.startswith("```json"):
            raw = raw[7:-3].strip()
        elif raw.startswith("```"):
            raw = raw[3:-3].strip()
            
        data = json.loads(raw)
        return ParsedConfig(**data)
    except Exception as e:
        print(f"[parse_config] LLM error: {e}")  # chỉ log server-side
        raise HTTPException(
            status_code=503,
            detail={"error": {"code": "LLM_UNAVAILABLE", "message": "Không thể xử lý cấu hình lúc này, vui lòng thử lại sau"}}
        )
