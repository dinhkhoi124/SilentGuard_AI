from pydantic import BaseModel, Field
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
    user_id: UUID
    priority_order: int

# ----------------------------------------------------
# 4.8 Thresholds / Settings
# ----------------------------------------------------
class SuppressWindow(BaseModel):
    start: str
    end: str
    max_still_sec: int

class ThresholdUpdate(BaseModel):
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
