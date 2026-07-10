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

class EventDurationUpdate(BaseModel):
    duration_sec: int
    status: str

# ----------------------------------------------------
# 4.1 Event Detect Request
# ----------------------------------------------------
class EventDetectRequest(BaseModel):
    event_id: str = Field(..., max_length=100)
    event_type: str = Field("fall", max_length=50)
    severity: str = Field(..., description="LOW, MEDIUM, HIGH, CRITICAL, SYSTEM", max_length=20)
    confidence: float = Field(..., ge=0.0, le=1.0)
    timestamp: datetime
    duration_sec: Optional[int] = Field(None, ge=0)
    room: Optional[str] = Field(None, max_length=100)
    clip_path: Optional[str] = Field(None, max_length=1000)
    clip_url: Optional[str] = Field(None, max_length=1000)
    model_ver: Optional[str] = Field("v1.0.0", max_length=50)

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
    priority_order: int = Field(..., ge=1)

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
    household_id: str = Field(..., max_length=100)
    low_max_sec: int = Field(30, ge=0)
    medium_max_sec: int = Field(120, ge=0)
    high_max_sec: int = Field(300, ge=0)
    dedup_window_sec: int = Field(60, ge=0)
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
    name: str = Field(..., min_length=1, max_length=255)
    elderly_name: str = Field(..., min_length=1, max_length=255)
    address: Optional[str] = Field(None, max_length=1000)

class SwitchHouseholdRequest(BaseModel):
    household_id: str


from enum import Enum

class FeedbackLabel(str, Enum):
    correct = "correct"
    false_positive = "false_positive"
    false_negative = "false_negative"

class FeedbackRequest(BaseModel):
    label: FeedbackLabel
    note: Optional[str] = None
    camera_serial: Optional[str] = None


class HouseholdUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, max_length=255)
    elderly_name: Optional[str] = Field(None, max_length=255)
    address: Optional[str] = Field(None, max_length=1000)


class InviteByEmailRequest(BaseModel):
    household_id: str = Field(..., max_length=100)
    email: str = Field(..., pattern=r"^[\w\.-]+@[\w\.-]+\.\w+$", max_length=255)


class RespondInviteRequest(BaseModel):
    action: str

    @field_validator("action")
    @classmethod
    def validate_action(cls, v: str) -> str:
        if v not in ("accepted", "declined"):
            raise ValueError("action must be 'accepted' or 'declined'")
        return v

