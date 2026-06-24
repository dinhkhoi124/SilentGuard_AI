import re
from pydantic import BaseModel, Field, field_validator
from typing import Dict, List, Optional, Any
from datetime import datetime
from uuid import UUID

# ----------------------------------------------------
# 4.0 presigned URL for clip upload
# ----------------------------------------------------
class UploadUrlRequest(BaseModel):
    filename: str
    content_type: str = "video/mp4"

class UploadUrlResponse(BaseModel):
    upload_url: str
    clip_path: str
    expires_in: int = 300

# ----------------------------------------------------
# 4.1 Event Detect Request
# ----------------------------------------------------
class EventDetectRequest(BaseModel):
    event_id: str
    event_type: str = "fall"
    severity: str = Field(..., description="LOW, MEDIUM, HIGH, CRITICAL, SYSTEM")
    confidence: float
    timestamp: datetime
    duration_sec: Optional[int] = None
    room: Optional[str] = None
    clip_path: Optional[str] = None
    clip_url: Optional[str] = None
    model_ver: Optional[str] = "v1.0.0"

# ----------------------------------------------------
# 4.2 Alerts List
# ----------------------------------------------------
class AlertItem(BaseModel):
    id: UUID
    event_id: str
    severity: str
    confidence: float
    timestamp: datetime
    duration_sec: Optional[int] = None
    room: Optional[str] = None
    clip_path: Optional[str] = None
    llm_message: Optional[str] = None
    status: str

class AlertListResponse(BaseModel):
    items: List[AlertItem]
    total: int

# ----------------------------------------------------
# 4.3 Review Request
# ----------------------------------------------------
class ReviewRequest(BaseModel):
    action: str = Field(..., description="acknowledged, dismissed")
    note: Optional[str] = None
    clip_timestamp: Optional[float] = None

# ----------------------------------------------------
# 4.4 Dashboard Summary
# ----------------------------------------------------
class CameraStatusSchema(BaseModel):
    name: str
    status: str
    fps: int = 15

class DashboardSummaryResponse(BaseModel):
    total_alerts_today: int
    avg_response_time_sec: int
    acknowledged: int
    total: int
    by_severity: Dict[str, int]
    cameras: List[CameraStatusSchema]

# ----------------------------------------------------
# 4.6 Device FCM Token Update
# ----------------------------------------------------
class FCMTokenUpdateRequest(BaseModel):
    fcm_token: str

# ----------------------------------------------------
# 4.7 Contacts Management
# ----------------------------------------------------
class ContactCreate(BaseModel):
    household_id: UUID
    user_id: UUID
    priority_order: int

# ----------------------------------------------------
# 4.8 Thresholds / Settings
# ----------------------------------------------------
class SuppressWindow(BaseModel):
    start: str
    end: str
    max_still_sec: int

    @field_validator("start", "end")
    @classmethod
    def validate_time_format(cls, v: str) -> str:
        if not re.match(r"^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$", v):
            raise ValueError("Time must be in HH:MM format (24-hour)")
        return v

class ThresholdUpdate(BaseModel):
    household_id: str
    low_max_sec: int = 30
    medium_max_sec: int = 120
    high_max_sec: int = 300
    dedup_window_sec: int = 60
    suppress_windows: List[SuppressWindow] = []

# ----------------------------------------------------
# 4.9 LLM Config
# ----------------------------------------------------
class LLMConfigRequest(BaseModel):
    message: str

# ----------------------------------------------------
# 4.12 Multi-Household
# ----------------------------------------------------
class HouseholdCreateRequest(BaseModel):
    name: str
    elderly_name: str
    address: Optional[str] = None

class SwitchHouseholdRequest(BaseModel):
    household_id: str


class FeedbackRequest(BaseModel):
    label: str
    note: Optional[str] = None
    camera_serial: Optional[str] = None

    @field_validator("label")
    @classmethod
    def validate_label(cls, v: str) -> str:
        if v not in ("correct", "incorrect", "uncertain"):
            raise ValueError("Label must be 'correct', 'incorrect', or 'uncertain'")
        return v


class HouseholdUpdateRequest(BaseModel):
    name: Optional[str] = None
    elderly_name: Optional[str] = None
    address: Optional[str] = None


