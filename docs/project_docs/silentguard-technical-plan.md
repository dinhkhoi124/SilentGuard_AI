# Kế Hoạch Kỹ Thuật Tổng Hợp — SilentGuard AI

> **Phiên bản:** 1.0  
> **Ngày:** 2025-06-15  
> **Dự án:** SilentGuard AI — Phát hiện té ngã thụ động cho người cao tuổi

---

## Mục lục

1. [Kiến trúc 3 lớp](#1-kiến-trúc-3-lớp)
2. [Tech Stack](#2-tech-stack)
3. [Database Schema](#3-database-schema)
4. [API Contract](#4-api-contract)
5. [Edge Device Pipeline](#5-edge-device-pipeline)
6. [Fall Detection Algorithm](#6-fall-detection-algorithm)
7. [Severity State Machine](#7-severity-state-machine)
8. [LLM Prompt Templates](#8-llm-prompt-templates)
9. [Dataset & Training Plan](#9-dataset--training-plan)
10. [Kế hoạch 1 tuần Demo đầu tiên](#10-kế-hoạch-1-tuần-demo-đầu-tiên)
11. [Thứ tự ưu tiên khi chậm tiến độ](#11-thứ-tự-ưu-tiên-khi-chậm-tiến-độ)
12. [Rủi ro & Biện pháp](#12-rủi-ro--biện-pháp)
13. [Definition of Done MVP](#13-definition-of-done-mvp)

---

## 1. Kiến trúc 3 lớp

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                           LAYER 1: EDGE DEVICE                              ║
║                      (Raspberry Pi 5 / Intel NUC)                           ║
║                                                                              ║
║  ┌─────────┐    ┌──────────────┐    ┌────────────────┐    ┌──────────────┐  ║
║  │  Camera │───▶│ OpenCV Capture│───▶│ YOLOv8-Pose    │───▶│ Fall         │  ║
║  │ USB/CSI │    │ 30fps, 720p  │    │ 17 Keypoints   │    │ Classifier   │  ║
║  └─────────┘    └──────────────┘    │ ~30ms/frame    │    │ Rule-based   │  ║
║                                     └────────────────┘    └──────┬───────┘  ║
║                                                                   │          ║
║  ┌─────────────────────────────────────────────────────────────────▼───────┐  ║
║  │                     CIRCULAR BUFFER (RAM, 300 frames = 10s)             │  ║
║  └─────────────────────────────────────────────────────────────────────────┘  ║
║           │ Khi FALL_DETECTED                                                ║
║           ▼                                                                  ║
║  ┌─────────────────┐    ┌──────────────────┐    ┌───────────────────────┐   ║
║  │ Severity Engine │    │  Blur + Encode   │    │  HTTP POST to Backend │   ║
║  │ State Machine   │───▶│  FFmpeg H.264    │───▶│  /api/events/detect   │   ║
║  │ Timer tracking  │    │  480p, 800kbps   │    │  multipart/form-data  │   ║
║  └─────────────────┘    └──────────────────┘    └───────────────────────┘   ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                         LAYER 2: BACKEND CLOUD                              ║
║                    (FastAPI + Supabase, Render/Railway)                     ║
║                                                                              ║
║  ┌─────────────────────────────────────────────────────────────────────┐    ║
║  │                        FastAPI Application                          │    ║
║  │                                                                     │    ║
║  │  /api/events/detect  ──▶  Alert Engine  ──▶  Claude API            │    ║
║  │  /api/events/        ──▶  CRUD Service  ──▶  Supabase DB           │    ║
║  │  /api/users/         ──▶  Auth Middleware (Firebase verify)         │    ║
║  │  /api/devices/       ──▶  Device Manager                           │    ║
║  │  /api/reports/daily  ──▶  Report Generator ──▶  Claude API         │    ║
║  └──────────────────────────┬──────────────────────────────────────────┘    ║
║                             │                                               ║
║           ┌─────────────────┴──────────────────┐                           ║
║           ▼                                    ▼                           ║
║  ┌─────────────────────┐            ┌──────────────────────┐               ║
║  │   Supabase          │            │  Firebase Services   │               ║
║  │   PostgreSQL        │            │  Auth: verify token  │               ║
║  │   - events          │            │  FCM: push notify    │               ║
║  │   - alert_reviews   │            └──────────────────────┘               ║
║  │   - devices         │                                                   ║
║  │   - users           │            ┌──────────────────────┐               ║
║  │   Storage           │            │  Claude API          │               ║
║  │   - video clips     │            │  Alert messages      │               ║
║  └─────────────────────┘            │  Daily reports       │               ║
║                                     │  Config parsing      │               ║
║                                     └──────────────────────┘               ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                         LAYER 3: CLIENT MOBILE                              ║
║                        (Flutter / React Native)                             ║
║                                                                              ║
║  ┌──────────────────────────────────────────────────────────────────────┐   ║
║  │  Mobile App                                                          │   ║
║  │                                                                      │   ║
║  │  Firebase Auth SDK ──▶ Login ──▶ ID Token ──▶ API requests          │   ║
║  │  FCM SDK           ──▶ Background push ──▶ Alert notification       │   ║
║  │  REST API Client   ──▶ Event list, video review, device config      │   ║
║  │                                                                      │   ║
║  │  Screens: Dashboard | Event Timeline | Video Review | Settings       │   ║
║  └──────────────────────────────────────────────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Luồng dữ liệu chính:**
```
Camera
  → [Edge] OpenCV capture (30fps)
  → [Edge] YOLOv8-Pose inference (17 keypoints/person)
  → [Edge] Fall Classifier (rule-based, góc + velocity)
  → [Edge] Severity State Machine (NORMAL / FALL_DETECTED / LOW / MEDIUM / HIGH / CRITICAL)
  → [Edge] Circular buffer extract (T-8s đến T+2s)
  → [Edge] Gaussian blur khuôn mặt + FFmpeg encode H.264 480p
  → [Cloud] POST /api/events/detect (multipart: metadata JSON + clip file)
  → [Cloud] Supabase: INSERT events, upload clip to Storage
  → [Cloud] Alert Engine: severity >= MEDIUM → trigger FCM
  → [Cloud] Claude API: generate alert message tiếng Việt
  → [Cloud] Firebase FCM: push to all user devices của owner
  → [Mobile] FCM background push → notification tray
  → [Mobile] User tap → open Event Detail → view blurred clip
```

---

## 2. Tech Stack

| Layer | Component | Technology | Ghi chú |
|-------|-----------|------------|---------|
| Edge | Runtime | Python 3.11 | Chạy trên Raspberry Pi 5 hoặc Intel NUC |
| Edge | Computer Vision | OpenCV 4.9 | Capture, frame processing, blur |
| Edge | Pose Detection | YOLOv8n-Pose (Ultralytics) | 17 keypoints COCO, ~30ms/frame trên Pi 5 |
| Edge | ML Backend | NCNN hoặc ONNX Runtime | Tối ưu inference trên ARM/x86 |
| Edge | Video Encode | FFmpeg 6.x | H.264, 480p, circular buffer |
| Edge | HTTP Client | `httpx` async | POST events lên backend |
| Backend | Framework | FastAPI 0.111 | Async ASGI, auto OpenAPI docs |
| Backend | Server | Uvicorn + Gunicorn | ASGI server, multi-worker khi cần |
| Backend | Validation | Pydantic v2 | Type-safe request/response models |
| Backend | Auth | Firebase Admin SDK 6.x | Verify ID token, send FCM |
| Backend | Push | Firebase Cloud Messaging | Background push iOS + Android |
| Backend | LLM | Anthropic Claude Sonnet | Alert message, daily report, config parse |
| Backend | HTTP | httpx | Async calls đến Firebase, Claude |
| Database | RDBMS | Supabase PostgreSQL 15 | Event-Device-User-Review schema |
| Database | File Storage | Supabase Storage (S3-compat) | Video clip đã blur, signed URL |
| Database | Client | supabase-py 2.x | Python client cho FastAPI |
| Auth | Identity | Firebase Authentication | Email/Google sign-in, ID token JWT |
| Deploy | Backend | Render / Railway | Free tier đủ cho MVP |
| Deploy | Edge | systemd service | Auto-restart khi crash hoặc reboot |
| Mobile | Framework | Flutter 3.x hoặc React Native | Cross-platform iOS + Android |
| Mobile | Auth | Firebase Auth SDK | Login, token management |
| Mobile | Push | Firebase Messaging SDK | Background notification handler |
| Mobile | API | Dio (Flutter) / Axios (RN) | REST client với auth interceptor |
| DevOps | Version Control | Git + GitHub | Branch: main/dev/feature/* |
| DevOps | CI | GitHub Actions | Lint + test on push to main |
| DevOps | Secrets | Render Env Vars / `.env` | ANTHROPIC_API_KEY, SUPABASE_*, FIREBASE_* |

---

## 3. Database Schema

### SQL DDL (PostgreSQL / Supabase)

```sql
-- ============================================================
-- EXTENSION
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUM TYPES
-- ============================================================
CREATE TYPE severity_level AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE event_status   AS ENUM ('pending', 'reviewing', 'confirmed', 'false_positive', 'resolved');
CREATE TYPE device_status  AS ENUM ('online', 'offline', 'error', 'maintenance');
CREATE TYPE user_role      AS ENUM ('owner', 'caregiver', 'admin');
CREATE TYPE review_action  AS ENUM ('confirm_fall', 'mark_false_positive', 'escalate', 'resolve');

-- ============================================================
-- TABLE: users
-- ============================================================
CREATE TABLE users (
    id                    TEXT PRIMARY KEY,  -- Firebase UID (string, bắt đầu bằng uid từ Firebase)
    email                 TEXT NOT NULL UNIQUE,
    name                  TEXT NOT NULL,
    role                  user_role NOT NULL DEFAULT 'owner',
    fcm_token             TEXT,              -- Device token cho FCM push, cập nhật mỗi lần login
    emergency_contacts    JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- Ví dụ: [{"name": "Nguyễn Văn A", "phone": "0901234567", "relation": "con trai"}]
    notification_settings JSONB NOT NULL DEFAULT '{
        "mute_start": null,
        "mute_end": null,
        "mute_days": [],
        "min_severity_push": "MEDIUM",
        "daily_report": true,
        "daily_report_time": "20:00"
    }'::jsonb,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN users.id IS 'Firebase UID — dùng trực tiếp làm primary key, không tạo UUID mới';
COMMENT ON COLUMN users.fcm_token IS 'FCM registration token. Mobile app gửi lên mỗi lần khởi động app';
COMMENT ON COLUMN users.emergency_contacts IS 'JSON array: [{name, phone, relation}]. Dùng khi CRITICAL severity';

-- ============================================================
-- TABLE: devices
-- ============================================================
CREATE TABLE devices (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,              -- Ví dụ: "Camera phòng khách"
    location    TEXT NOT NULL,             -- Ví dụ: "phòng khách", "phòng ngủ"
    ip_address  TEXT,                      -- IP local của edge device, dùng để debug
    status      device_status NOT NULL DEFAULT 'offline',
    last_seen   TIMESTAMPTZ,               -- Thời điểm edge device gửi heartbeat cuối
    config_json JSONB NOT NULL DEFAULT '{
        "fall_sensitivity": 0.75,
        "severity_thresholds": {
            "low_to_medium_seconds": 30,
            "medium_to_high_seconds": 120,
            "high_to_critical_seconds": 300
        },
        "blur_intensity": "high",
        "fps_target": 30,
        "resolution": "720p"
    }'::jsonb,
    api_key     TEXT NOT NULL,             -- Device authenticates with this key (không phải user token)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN devices.api_key IS 'Secret key dùng để edge device authenticate với backend. SHA256 hash lưu ở đây';
COMMENT ON COLUMN devices.config_json IS 'Per-device configuration. severity_thresholds override global defaults';

-- ============================================================
-- TABLE: events
-- ============================================================
CREATE TABLE events (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id        UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    event_type       TEXT NOT NULL DEFAULT 'fall_detected',
    severity         severity_level NOT NULL,
    confidence       FLOAT NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    -- confidence: xác suất từ fall classifier (0.0 – 1.0)
    timestamp        TIMESTAMPTZ NOT NULL,  -- Thời điểm phát hiện ngã (UTC)
    clip_url         TEXT,                  -- Supabase Storage URL của clip đã blur
    clip_start_ts    TIMESTAMPTZ,           -- Thời điểm bắt đầu clip (T-8s)
    clip_end_ts      TIMESTAMPTZ,           -- Thời điểm kết thúc clip (T+2s)
    duration_seconds INTEGER,              -- Thời gian bất động (giây) tính đến khi update severity
    status           event_status NOT NULL DEFAULT 'pending',
    ai_model_version TEXT NOT NULL DEFAULT 'yolov8n-pose-v1.0',
    -- Keypoint snapshot tại thời điểm phát hiện (17 keypoints)
    keypoints_json   JSONB,
    -- Ví dụ: {"nose": [320, 180, 0.95], "left_shoulder": [290, 220, 0.88], ...}
    alert_message    TEXT,                 -- Claude-generated alert message (async, có thể null ban đầu)
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN events.confidence IS 'Fall classifier confidence: product của keypoint confidence × rule score';
COMMENT ON COLUMN events.keypoints_json IS '17 COCO keypoints: {name: [x, y, confidence]}. Dùng để debug và fine-tune';
COMMENT ON COLUMN events.alert_message IS 'Claude-generated message. NULL nếu Claude chưa response hoặc unavailable';

-- ============================================================
-- TABLE: alert_reviews
-- ============================================================
CREATE TABLE alert_reviews (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id         UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    reviewer_id      TEXT NOT NULL REFERENCES users(id),
    action           review_action NOT NULL,
    note             TEXT,                 -- Ghi chú tự do của reviewer
    learning_signal  BOOLEAN NOT NULL DEFAULT true,
    -- learning_signal: true = dùng làm training data, false = reviewer không chắc
    video_timestamp  FLOAT,               -- Giây trong clip mà reviewer thấy điểm quan trọng nhất
    reviewed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN alert_reviews.learning_signal IS 'Nếu true, action này được dùng để fine-tune model sau';
COMMENT ON COLUMN alert_reviews.video_timestamp IS 'Giây trong clip 10s. Ví dụ: 7.5 = giây thứ 7.5 là lúc rõ nhất';

-- ============================================================
-- INDEXES
-- ============================================================

-- events: query by device + time range (most common query)
CREATE INDEX idx_events_device_timestamp
    ON events (device_id, timestamp DESC);

-- events: query by severity (dashboard filter)
CREATE INDEX idx_events_severity
    ON events (severity);

-- events: query by status (alert engine, review queue)
CREATE INDEX idx_events_status
    ON events (status);

-- events: composite index cho daily report query
CREATE INDEX idx_events_device_timestamp_severity
    ON events (device_id, timestamp DESC, severity);

-- alert_reviews: lookup by event
CREATE INDEX idx_alert_reviews_event_id
    ON alert_reviews (event_id);

-- devices: lookup by owner
CREATE INDEX idx_devices_owner_id
    ON devices (owner_id);

-- devices: find devices by status (heartbeat monitor)
CREATE INDEX idx_devices_status_last_seen
    ON devices (status, last_seen DESC);

-- ============================================================
-- TRIGGERS: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### SQLAlchemy Models (Python)

```python
# app/models.py
from sqlalchemy import (
    Column, String, Float, Integer, Boolean, Text,
    ForeignKey, Enum as SAEnum, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, TIMESTAMPTZ
from sqlalchemy.orm import DeclarativeBase, relationship
from sqlalchemy.sql import func
import enum
import uuid


class Base(DeclarativeBase):
    pass


class SeverityLevel(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class EventStatus(str, enum.Enum):
    PENDING = "pending"
    REVIEWING = "reviewing"
    CONFIRMED = "confirmed"
    FALSE_POSITIVE = "false_positive"
    RESOLVED = "resolved"


class DeviceStatus(str, enum.Enum):
    ONLINE = "online"
    OFFLINE = "offline"
    ERROR = "error"
    MAINTENANCE = "maintenance"


class ReviewAction(str, enum.Enum):
    CONFIRM_FALL = "confirm_fall"
    MARK_FALSE_POSITIVE = "mark_false_positive"
    ESCALATE = "escalate"
    RESOLVE = "resolve"


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True)  # Firebase UID
    email = Column(String, nullable=False, unique=True)
    name = Column(String, nullable=False)
    role = Column(SAEnum("owner", "caregiver", "admin", name="user_role"), default="owner")
    fcm_token = Column(String, nullable=True)
    emergency_contacts = Column(JSONB, default=list)
    notification_settings = Column(JSONB, default=dict)
    created_at = Column(TIMESTAMPTZ, server_default=func.now())
    updated_at = Column(TIMESTAMPTZ, server_default=func.now(), onupdate=func.now())

    devices = relationship("Device", back_populates="owner")
    reviews = relationship("AlertReview", back_populates="reviewer")


class Device(Base):
    __tablename__ = "devices"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    location = Column(String, nullable=False)
    ip_address = Column(String, nullable=True)
    status = Column(SAEnum(DeviceStatus, name="device_status"), default=DeviceStatus.OFFLINE)
    last_seen = Column(TIMESTAMPTZ, nullable=True)
    config_json = Column(JSONB, default=dict)
    api_key = Column(String, nullable=False)
    created_at = Column(TIMESTAMPTZ, server_default=func.now())
    updated_at = Column(TIMESTAMPTZ, server_default=func.now(), onupdate=func.now())

    owner = relationship("User", back_populates="devices")
    events = relationship("Event", back_populates="device")


class Event(Base):
    __tablename__ = "events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    device_id = Column(UUID(as_uuid=True), ForeignKey("devices.id", ondelete="CASCADE"), nullable=False)
    event_type = Column(String, nullable=False, default="fall_detected")
    severity = Column(SAEnum(SeverityLevel, name="severity_level"), nullable=False)
    confidence = Column(Float, CheckConstraint("confidence >= 0 AND confidence <= 1"), nullable=False)
    timestamp = Column(TIMESTAMPTZ, nullable=False)
    clip_url = Column(Text, nullable=True)
    clip_start_ts = Column(TIMESTAMPTZ, nullable=True)
    clip_end_ts = Column(TIMESTAMPTZ, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    status = Column(SAEnum(EventStatus, name="event_status"), default=EventStatus.PENDING)
    ai_model_version = Column(String, nullable=False, default="yolov8n-pose-v1.0")
    keypoints_json = Column(JSONB, nullable=True)
    alert_message = Column(Text, nullable=True)
    created_at = Column(TIMESTAMPTZ, server_default=func.now())
    updated_at = Column(TIMESTAMPTZ, server_default=func.now(), onupdate=func.now())

    device = relationship("Device", back_populates="events")
    reviews = relationship("AlertReview", back_populates="event")


class AlertReview(Base):
    __tablename__ = "alert_reviews"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_id = Column(UUID(as_uuid=True), ForeignKey("events.id", ondelete="CASCADE"), nullable=False)
    reviewer_id = Column(String, ForeignKey("users.id"), nullable=False)
    action = Column(SAEnum(ReviewAction, name="review_action"), nullable=False)
    note = Column(Text, nullable=True)
    learning_signal = Column(Boolean, nullable=False, default=True)
    video_timestamp = Column(Float, nullable=True)
    reviewed_at = Column(TIMESTAMPTZ, server_default=func.now())
    created_at = Column(TIMESTAMPTZ, server_default=func.now())

    event = relationship("Event", back_populates="reviews")
    reviewer = relationship("User", back_populates="reviews")
```

---

## 4. API Contract

### Base URL
```
Production: https://silentguard-api.onrender.com
Local:      http://localhost:8000
```

### Authentication
Tất cả endpoints (trừ `/health` và `/api/events/detect`) yêu cầu Firebase ID Token trong header:
```
Authorization: Bearer <firebase_id_token>
```

Edge device dùng Device API Key:
```
X-Device-Key: <device_api_key>
```

---

### POST /api/events/detect

**Dùng bởi:** Edge device  
**Auth:** `X-Device-Key` header

**Request:** `multipart/form-data`
```
metadata: (JSON string) {
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "severity": "HIGH",
    "confidence": 0.87,
    "timestamp": "2025-06-15T14:32:00Z",
    "duration_seconds": 145,
    "ai_model_version": "yolov8n-pose-v1.0",
    "clip_start_ts": "2025-06-15T14:31:52Z",
    "clip_end_ts": "2025-06-15T14:32:02Z",
    "keypoints_json": {
        "nose":          [320, 180, 0.95],
        "left_shoulder": [290, 220, 0.88],
        "right_shoulder":[350, 220, 0.91],
        "left_hip":      [295, 310, 0.82],
        "right_hip":     [345, 310, 0.85],
        "left_knee":     [280, 390, 0.79],
        "right_knee":    [360, 395, 0.76],
        "left_ankle":    [265, 460, 0.71],
        "right_ankle":   [375, 455, 0.68]
    }
}
clip: (file binary) .mp4 file, H.264, tối đa 20MB
```

**Response 201 Created:**
```json
{
    "event_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "status": "pending",
    "severity": "HIGH",
    "alert_triggered": true,
    "clip_url": "https://xxx.supabase.co/storage/v1/object/sign/clips/device-uuid/2025-06-15T14:32:00Z.mp4?token=xxx",
    "message": "Event recorded. Push notification sent to 2 devices."
}
```

**Response 401 Unauthorized:**
```json
{
    "detail": "Invalid or missing device API key"
}
```

**Response 400 Bad Request:**
```json
{
    "detail": "Clip file size exceeds 20MB limit",
    "field": "clip"
}
```

---

### GET /api/events/

**Dùng bởi:** Mobile app  
**Auth:** Firebase ID Token

**Query parameters:**
| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| `device_id` | UUID | null | Filter theo thiết bị |
| `severity` | string | null | Filter: LOW, MEDIUM, HIGH, CRITICAL |
| `status` | string | null | Filter: pending, confirmed, false_positive, resolved |
| `from_ts` | ISO8601 | -7 ngày | Từ thời điểm |
| `to_ts` | ISO8601 | now | Đến thời điểm |
| `limit` | int | 20 | Số records trả về (max 100) |
| `offset` | int | 0 | Pagination offset |

**Response 200 OK:**
```json
{
    "total": 47,
    "limit": 20,
    "offset": 0,
    "events": [
        {
            "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
            "device_id": "550e8400-e29b-41d4-a716-446655440000",
            "device_name": "Camera phòng khách",
            "device_location": "phòng khách",
            "event_type": "fall_detected",
            "severity": "HIGH",
            "confidence": 0.87,
            "timestamp": "2025-06-15T14:32:00Z",
            "duration_seconds": 145,
            "status": "pending",
            "clip_url": "https://xxx.supabase.co/storage/v1/object/sign/clips/xxx.mp4?token=yyy&expires_in=3600",
            "alert_message": "⚠️ Bố bạn có thể cần trợ giúp tại phòng khách. Bất động được 2 phút 25 giây. Vui lòng kiểm tra ngay.",
            "ai_model_version": "yolov8n-pose-v1.0",
            "created_at": "2025-06-15T14:32:01Z",
            "reviews": []
        }
    ]
}
```

---

### GET /api/events/{event_id}

**Dùng bởi:** Mobile app  
**Auth:** Firebase ID Token

**Response 200 OK:**
```json
{
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "device_name": "Camera phòng khách",
    "device_location": "phòng khách",
    "event_type": "fall_detected",
    "severity": "HIGH",
    "confidence": 0.87,
    "timestamp": "2025-06-15T14:32:00Z",
    "duration_seconds": 145,
    "clip_url": "https://xxx.supabase.co/storage/v1/object/sign/clips/xxx.mp4?token=yyy&expires_in=3600",
    "clip_start_ts": "2025-06-15T14:31:52Z",
    "clip_end_ts": "2025-06-15T14:32:02Z",
    "status": "pending",
    "alert_message": "⚠️ Bố bạn có thể cần trợ giúp tại phòng khách.",
    "ai_model_version": "yolov8n-pose-v1.0",
    "keypoints_json": null,
    "reviews": [],
    "created_at": "2025-06-15T14:32:01Z",
    "updated_at": "2025-06-15T14:32:05Z"
}
```

**Response 404 Not Found:**
```json
{
    "detail": "Event not found or you don't have permission to view it"
}
```

---

### POST /api/events/{event_id}/review

**Dùng bởi:** Mobile app  
**Auth:** Firebase ID Token

**Request Body:**
```json
{
    "action": "confirm_fall",
    "note": "Nhìn clip thấy bố ngã ra phía trước, đã gọi điện kiểm tra",
    "learning_signal": true,
    "video_timestamp": 7.5
}
```

**Response 201 Created:**
```json
{
    "review_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "event_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "action": "confirm_fall",
    "event_status_updated_to": "confirmed",
    "reviewed_at": "2025-06-15T14:45:00Z"
}
```

---

### GET /api/reports/daily

**Dùng bởi:** Mobile app, scheduled job  
**Auth:** Firebase ID Token

**Query parameters:**
| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| `date` | YYYY-MM-DD | hôm nay | Ngày cần báo cáo |
| `device_id` | UUID | null | Filter theo thiết bị (null = tất cả) |

**Response 200 OK:**
```json
{
    "date": "2025-06-15",
    "summary": {
        "total_events": 3,
        "by_severity": {
            "LOW": 2,
            "MEDIUM": 1,
            "HIGH": 0,
            "CRITICAL": 0
        },
        "false_positives": 0,
        "confirmed_falls": 1
    },
    "ai_report": "Hôm nay ông Nam có 3 sự kiện được ghi nhận. 2 sự kiện nhẹ (ông tự đứng dậy trong vòng 15 giây), 1 sự kiện mức trung bình lúc 14:32 tại phòng khách (bất động khoảng 1 phút, sau đó ổn). Không có sự kiện nghiêm trọng. Nhìn chung ngày hôm nay bình thường, không có dấu hiệu đáng lo ngại.",
    "events": [
        {
            "id": "...",
            "timestamp": "2025-06-15T09:15:00Z",
            "severity": "LOW",
            "duration_seconds": 12,
            "device_location": "phòng ngủ"
        }
    ],
    "generated_at": "2025-06-15T20:00:05Z"
}
```

---

### POST /api/devices/

**Dùng bởi:** Mobile app (owner setup camera mới)  
**Auth:** Firebase ID Token

**Request Body:**
```json
{
    "name": "Camera phòng khách",
    "location": "phòng khách"
}
```

**Response 201 Created:**
```json
{
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Camera phòng khách",
    "location": "phòng khách",
    "api_key": "sg_dev_k7x9m2p4q1r8s5t6u3v0w...",
    "status": "offline",
    "setup_instructions": "Copy API key này vào file .env của edge device: DEVICE_API_KEY=sg_dev_k7x9..."
}
```

---

### PATCH /api/devices/{device_id}/heartbeat

**Dùng bởi:** Edge device (mỗi 30 giây)  
**Auth:** `X-Device-Key` header

**Request Body:**
```json
{
    "status": "online",
    "ip_address": "192.168.1.45",
    "fps_actual": 28.5,
    "cpu_temp_celsius": 62.3,
    "ram_usage_percent": 45.2
}
```

**Response 200 OK:**
```json
{
    "acknowledged": true,
    "config_updated": false,
    "server_time": "2025-06-15T14:32:00Z"
}
```

---

### POST /api/users/fcm-token

**Dùng bởi:** Mobile app (khi FCM token rotate)  
**Auth:** Firebase ID Token

**Request Body:**
```json
{
    "fcm_token": "fMEIyxxxxxxxxxxxxxxxx..."
}
```

**Response 200 OK:**
```json
{
    "updated": true
}
```

---

### GET /health

**Dùng bởi:** Render health check, monitoring  
**Auth:** Không cần

**Response 200 OK:**
```json
{
    "status": "ok",
    "version": "1.0.0",
    "timestamp": "2025-06-15T14:32:00Z",
    "services": {
        "database": "ok",
        "storage": "ok",
        "firebase": "ok",
        "claude": "ok"
    }
}
```

---

## 5. Edge Device Pipeline

```python
# edge/main.py — SilentGuard Edge Pipeline
import asyncio
import collections
import time
import cv2
import numpy as np
import httpx
import subprocess
import tempfile
import os
from ultralytics import YOLO
from datetime import datetime, timezone

# ============================================================
# CONFIGURATION
# ============================================================
CAMERA_INDEX = 0
TARGET_FPS = 30
FRAME_BUFFER_SIZE = 300            # 10 giây tại 30fps
CLIP_PRE_EVENT_FRAMES = 240        # T-8s (8 giây trước sự kiện)
CLIP_POST_EVENT_FRAMES = 60        # T+2s (2 giây sau sự kiện)
BACKEND_URL = os.environ["BACKEND_URL"]       # https://silentguard-api.onrender.com
DEVICE_API_KEY = os.environ["DEVICE_API_KEY"] # sg_dev_k7x9...
DEVICE_ID = os.environ["DEVICE_ID"]           # UUID từ Supabase

# Severity thresholds (giây bất động)
LOW_TO_MEDIUM_S = 30
MEDIUM_TO_HIGH_S = 120
HIGH_TO_CRITICAL_S = 300

# Fall detection thresholds
BODY_ANGLE_FALL_THRESHOLD = 45.0   # Góc thân người < 45° → nằm
VELOCITY_FALL_THRESHOLD = 80.0     # px/frame velocity hướng xuống
FALL_CONFIRMATION_FRAMES = 5       # Phải detect liên tục 5 frame để confirm


# ============================================================
# CIRCULAR FRAME BUFFER
# ============================================================
class CircularFrameBuffer:
    """Giữ N frame gần nhất trong RAM. Không ghi disk."""

    def __init__(self, maxsize: int = 300):
        self.buffer = collections.deque(maxlen=maxsize)
        self.timestamps = collections.deque(maxlen=maxsize)

    def push(self, frame: np.ndarray, ts: float) -> None:
        self.buffer.append(frame.copy())
        self.timestamps.append(ts)

    def get_clip_frames(self, pre: int, post_buffer: list) -> list:
        """Lấy 'pre' frame từ buffer + post_buffer frames."""
        pre_frames = list(self.buffer)[-pre:]
        return pre_frames + post_buffer

    def size(self) -> int:
        return len(self.buffer)


# ============================================================
# FALL CLASSIFIER
# ============================================================
class FallClassifier:
    """Rule-based classifier dựa trên YOLOv8-Pose keypoints."""

    # COCO keypoint indices
    NOSE = 0
    LEFT_SHOULDER = 5
    RIGHT_SHOULDER = 6
    LEFT_HIP = 11
    RIGHT_HIP = 12
    LEFT_KNEE = 13
    RIGHT_KNEE = 14
    LEFT_ANKLE = 15
    RIGHT_ANKLE = 16

    def __init__(self):
        self.prev_hip_y = None
        self.prev_shoulder_y = None
        self.fall_frame_count = 0
        self.prev_timestamp = None

    def extract_keypoint(self, kps: np.ndarray, idx: int) -> tuple[float, float, float] | None:
        """Trả về (x, y, confidence) hoặc None nếu confidence < 0.5."""
        if idx >= len(kps):
            return None
        x, y, conf = kps[idx]
        if conf < 0.5:
            return None
        return float(x), float(y), float(conf)

    def compute_body_angle(self, kps: np.ndarray) -> float | None:
        """
        Tính góc nghiêng của đường thân người (shoulder → hip) so với trục ngang.
        Góc 90° = đứng thẳng, góc 0° = nằm ngang.
        """
        left_shoulder = self.extract_keypoint(kps, self.LEFT_SHOULDER)
        right_shoulder = self.extract_keypoint(kps, self.RIGHT_SHOULDER)
        left_hip = self.extract_keypoint(kps, self.LEFT_HIP)
        right_hip = self.extract_keypoint(kps, self.RIGHT_HIP)

        if not (left_shoulder and right_shoulder and left_hip and right_hip):
            return None

        # Điểm giữa vai và hông
        shoulder_mid = ((left_shoulder[0] + right_shoulder[0]) / 2,
                        (left_shoulder[1] + right_shoulder[1]) / 2)
        hip_mid = ((left_hip[0] + right_hip[0]) / 2,
                   (left_hip[1] + right_hip[1]) / 2)

        # Vector từ hông lên vai
        dx = shoulder_mid[0] - hip_mid[0]
        dy = hip_mid[1] - shoulder_mid[1]  # y đảo ngược trong image coords

        angle_rad = np.arctan2(dy, abs(dx) + 1e-6)
        angle_deg = np.degrees(angle_rad)
        return angle_deg

    def compute_hip_velocity(self, kps: np.ndarray, dt: float) -> float | None:
        """
        Tính vận tốc dịch chuyển của hông theo trục Y (px/giây).
        Dương = hướng xuống (ngã).
        """
        left_hip = self.extract_keypoint(kps, self.LEFT_HIP)
        right_hip = self.extract_keypoint(kps, self.RIGHT_HIP)

        if not (left_hip and right_hip):
            return None

        current_hip_y = (left_hip[1] + right_hip[1]) / 2

        if self.prev_hip_y is None or dt <= 0:
            self.prev_hip_y = current_hip_y
            return 0.0

        velocity = (current_hip_y - self.prev_hip_y) / dt
        self.prev_hip_y = current_hip_y
        return velocity

    def classify(self, kps: np.ndarray, dt: float) -> tuple[bool, float, dict]:
        """
        Phân loại có phải té ngã không.
        Trả về: (is_fall, confidence, debug_info)
        """
        debug = {}

        body_angle = self.compute_body_angle(kps)
        hip_velocity = self.compute_hip_velocity(kps, dt)

        debug["body_angle"] = body_angle
        debug["hip_velocity"] = hip_velocity

        if body_angle is None or hip_velocity is None:
            # Keypoints không đủ tin cậy
            self.fall_frame_count = 0
            return False, 0.0, debug

        # Điều kiện 1: Thân người gần nằm ngang
        is_horizontal = body_angle < BODY_ANGLE_FALL_THRESHOLD
        # Điều kiện 2: Hông đang di chuyển xuống nhanh
        is_falling_down = hip_velocity > VELOCITY_FALL_THRESHOLD

        debug["is_horizontal"] = is_horizontal
        debug["is_falling_down"] = is_falling_down

        # Cần ít nhất một trong hai điều kiện (OR logic)
        # Và cần N frame liên tiếp để tránh false positive do occlusion
        if is_horizontal or is_falling_down:
            self.fall_frame_count += 1
        else:
            self.fall_frame_count = max(0, self.fall_frame_count - 1)

        debug["fall_frame_count"] = self.fall_frame_count

        if self.fall_frame_count >= FALL_CONFIRMATION_FRAMES:
            # Confidence = kết hợp hai điều kiện
            angle_score = max(0, (BODY_ANGLE_FALL_THRESHOLD - body_angle) / BODY_ANGLE_FALL_THRESHOLD)
            velocity_score = min(1.0, hip_velocity / (VELOCITY_FALL_THRESHOLD * 3))
            confidence = 0.6 * angle_score + 0.4 * velocity_score
            return True, round(confidence, 3), debug

        return False, 0.0, debug


# ============================================================
# SEVERITY STATE MACHINE
# ============================================================
class SeverityStateMachine:
    """
    State machine theo dõi severity sau khi FALL_DETECTED.
    NORMAL → FALL_DETECTED → LOW → MEDIUM → HIGH → CRITICAL
    """

    STATE_NORMAL = "NORMAL"
    STATE_FALL_DETECTED = "FALL_DETECTED"
    STATE_LOW = "LOW"
    STATE_MEDIUM = "MEDIUM"
    STATE_HIGH = "HIGH"
    STATE_CRITICAL = "CRITICAL"

    def __init__(self):
        self.state = self.STATE_NORMAL
        self.fall_detected_at = None
        self.is_stationary = False
        self.stationary_since = None
        self.last_alert_sent = None  # Tránh gửi alert nhiều lần cho cùng event

    def on_fall_detected(self, ts: float) -> None:
        if self.state == self.STATE_NORMAL:
            self.state = self.STATE_FALL_DETECTED
            self.fall_detected_at = ts

    def on_person_stood_up(self) -> str:
        """Gọi khi detect thấy người đứng dậy (body_angle > 70°). Trả về trạng thái đạt được."""
        final_state = self.STATE_NORMAL
        if self.state == self.STATE_FALL_DETECTED:
            elapsed = time.time() - self.fall_detected_at
            if elapsed < LOW_TO_MEDIUM_S:
                final_state = self.STATE_LOW
            # LOW = log only, không push notification
        self._reset()
        return final_state

    def _reset(self) -> None:
        self.state = self.STATE_NORMAL
        self.fall_detected_at = None
        self.stationary_since = None
        self.last_alert_sent = None

    def update(self, is_fall: bool, body_angle: float | None) -> tuple[str, bool]:
        """
        Cập nhật state machine mỗi frame.
        Trả về: (current_severity, should_send_alert)
        """
        now = time.time()
        should_send_alert = False

        if self.state == self.STATE_NORMAL:
            return self.state, False

        if self.state == self.STATE_FALL_DETECTED:
            # Kiểm tra người có đứng dậy chưa
            if body_angle is not None and body_angle > 70.0:
                elapsed = now - self.fall_detected_at
                if elapsed < LOW_TO_MEDIUM_S:
                    # LOW: chỉ log, không push. Reset state machine về NORMAL ngay để tránh bị treo ở STATE_LOW.
                    self._reset()
                    return self.STATE_LOW, False
            # Kiểm tra thời gian bất động
            elapsed = now - self.fall_detected_at
            if elapsed >= LOW_TO_MEDIUM_S:
                self.state = self.STATE_MEDIUM
                should_send_alert = self.last_alert_sent != self.STATE_MEDIUM
                if should_send_alert:
                    self.last_alert_sent = self.STATE_MEDIUM

        if self.state == self.STATE_MEDIUM:
            elapsed = now - self.fall_detected_at
            if elapsed >= MEDIUM_TO_HIGH_S:
                self.state = self.STATE_HIGH
                should_send_alert = self.last_alert_sent != self.STATE_HIGH
                if should_send_alert:
                    self.last_alert_sent = self.STATE_HIGH

        if self.state == self.STATE_HIGH:
            elapsed = now - self.fall_detected_at
            if elapsed >= HIGH_TO_CRITICAL_S:
                self.state = self.STATE_CRITICAL
                should_send_alert = self.last_alert_sent != self.STATE_CRITICAL
                if should_send_alert:
                    self.last_alert_sent = self.STATE_CRITICAL

        return self.state, should_send_alert


# ============================================================
# VIDEO ENCODE
# ============================================================
def encode_clip(frames: list, fps: int = 30) -> bytes | None:
    """
    Encode các frame thành H.264 MP4.
    Trả về bytes của file MP4 hoặc None nếu lỗi.
    """
    if not frames:
        return None

    h, w = frames[0].shape[:2]
    tmp_dir = tempfile.mkdtemp()
    proc = None
    try:
        output_path = os.path.join(tmp_dir, "clip.mp4")

        # Encode với FFmpeg qua pipe
        ffmpeg_cmd = [
            "ffmpeg", "-y",
            "-f", "rawvideo",
            "-vcodec", "rawvideo",
            "-s", f"{w}x{h}",
            "-pix_fmt", "bgr24",
            "-r", str(fps),
            "-i", "pipe:0",
            "-vf", "scale=854:480",    # Downscale to 480p
            "-vcodec", "libx264",
            "-crf", "28",               # Quality (lower = better, 28 ≈ 800kbps)
            "-preset", "fast",
            "-pix_fmt", "yuv420p",
            output_path
        ]

        proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)

        for frame in frames:
            proc.stdin.write(frame.tobytes())

        proc.stdin.close()
        proc.wait()

        if not os.path.exists(output_path):
            return None

        with open(output_path, "rb") as f:
            clip_bytes = f.read()

        return clip_bytes
    except Exception as e:
        print(f"[ERROR] Error encoding clip: {e}")
        return None
    finally:
        # Dọn dẹp tài nguyên và thư mục tạm trong mọi trường hợp (tránh leak)
        if proc and proc.poll() is None:
            proc.kill()
        try:
            target_file = os.path.join(tmp_dir, "clip.mp4")
            if os.path.exists(target_file):
                os.unlink(target_file)
        except Exception:
            pass
        try:
            if os.path.exists(tmp_dir):
                os.rmdir(tmp_dir)
        except Exception:
            pass


# ============================================================
# SEND EVENT TO BACKEND
# ============================================================
async def send_event_to_backend(
    severity: str,
    confidence: float,
    duration_seconds: int,
    timestamp: datetime,
    clip_bytes: bytes | None,
    keypoints_json: dict,
) -> dict | None:
    """POST event + clip lên FastAPI backend."""
    import json

    metadata = {
        "device_id": DEVICE_ID,
        "severity": severity,
        "confidence": confidence,
        "timestamp": timestamp.isoformat(),
        "duration_seconds": duration_seconds,
        "ai_model_version": "yolov8n-pose-v1.0",
        "keypoints_json": keypoints_json,
    }

    files = {"metadata": (None, json.dumps(metadata), "application/json")}
    if clip_bytes:
        files["clip"] = ("clip.mp4", clip_bytes, "video/mp4")

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{BACKEND_URL}/api/events/detect",
                headers={"X-Device-Key": DEVICE_API_KEY},
                files=files,
            )
            response.raise_for_status()
            return response.json()
    except httpx.HTTPError as e:
        print(f"[ERROR] Failed to send event: {e}")
        return None


# ============================================================
# MAIN PIPELINE
# ============================================================
async def run_pipeline():
    model = YOLO("yolov8n-pose.pt")
    cap = cv2.VideoCapture(CAMERA_INDEX)
    cap.set(cv2.CAP_PROP_FPS, TARGET_FPS)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    frame_buffer = CircularFrameBuffer(maxsize=FRAME_BUFFER_SIZE)
    classifier = FallClassifier()
    state_machine = SeverityStateMachine()

    post_event_frames = []       # Buffer frames sau sự kiện
    collecting_post_frames = False
    post_frame_target = 0
    fall_detected_at: datetime | None = None
    fall_keypoints: dict = {}
    fall_confidence: float = 0.0

    prev_ts = time.time()

    print("[INFO] SilentGuard Edge pipeline started")

    while True:
        ret, frame = cap.read()
        if not ret:
            await asyncio.sleep(0.03)
            continue

        current_ts = time.time()
        dt = current_ts - prev_ts
        prev_ts = current_ts

        # YOLOv8-Pose inference
        results = model(frame, verbose=False, conf=0.5)

        # Lấy keypoints của người đầu tiên (closest/largest bounding box)
        kps = None
        body_angle = None
        if results[0].keypoints is not None and len(results[0].keypoints.data) > 0:
            kps = results[0].keypoints.data[0].cpu().numpy()  # shape (17, 3)

        # Push frame vào buffer
        frame_buffer.push(frame, current_ts)

        # Thu thập post-event frames
        if collecting_post_frames:
            post_event_frames.append(frame)
            if len(post_event_frames) >= post_frame_target:
                # Đủ frames → encode và gửi
                collecting_post_frames = False
                all_frames = frame_buffer.get_clip_frames(CLIP_PRE_EVENT_FRAMES, post_event_frames)
                post_event_frames = []
                clip_bytes = encode_clip(all_frames, fps=TARGET_FPS)
                await send_event_to_backend(
                    severity=state_machine.state,
                    confidence=fall_confidence,
                    duration_seconds=int(current_ts - fall_detected_at.timestamp()) if fall_detected_at else 0,
                    timestamp=fall_detected_at or datetime.now(timezone.utc),
                    clip_bytes=clip_bytes,
                    keypoints_json=fall_keypoints,
                )
            continue

        if kps is not None:
            is_fall, confidence, debug = classifier.classify(kps, dt)
            body_angle = debug.get("body_angle")

            if is_fall and state_machine.state == SeverityStateMachine.STATE_NORMAL:
                state_machine.on_fall_detected(current_ts)
                fall_detected_at = datetime.now(timezone.utc)
                fall_confidence = confidence
                fall_keypoints = {
                    "nose": kps[0].tolist(), "left_shoulder": kps[5].tolist(),
                    "right_shoulder": kps[6].tolist(), "left_hip": kps[11].tolist(),
                    "right_hip": kps[12].tolist(), "left_knee": kps[13].tolist(),
                    "right_knee": kps[14].tolist(), "left_ankle": kps[15].tolist(),
                    "right_ankle": kps[16].tolist(),
                }
                print(f"[FALL] Detected at {fall_detected_at.isoformat()}, confidence={confidence:.3f}")

        severity, should_alert = state_machine.update(kps is not None, body_angle)

        if should_alert:
            print(f"[ALERT] Severity escalated to {severity}. Collecting post-event frames...")
            collecting_post_frames = True
            post_event_frames = []
            post_frame_target = CLIP_POST_EVENT_FRAMES

        await asyncio.sleep(0)  # Yield event loop


if __name__ == "__main__":
    asyncio.run(run_pipeline())
```

---

## 6. Fall Detection Algorithm

### Keypoints sử dụng

Từ 17 keypoints COCO, SilentGuard AI sử dụng 8 keypoints chính:

| Keypoint | COCO Index | Vai trò |
|----------|------------|---------|
| Left Shoulder | 5 | Tính góc thân người |
| Right Shoulder | 6 | Tính góc thân người |
| Left Hip | 11 | Tính góc thân người, velocity |
| Right Hip | 12 | Tính góc thân người, velocity |
| Left Knee | 13 | Phát hiện khuỵu gối |
| Right Knee | 14 | Phát hiện khuỵu gối |
| Left Ankle | 15 | Kiểm tra feet position |
| Right Ankle | 16 | Kiểm tra feet position |

### Điều kiện phát hiện té ngã

```
FALL = (body_angle < 45°) OR (hip_velocity > 80 px/s xuống)
     AND (điều kiện này đúng trong 5 frame liên tiếp)
```

Trong đó:
- **body_angle:** Góc của đường nối điểm giữa 2 vai → điểm giữa 2 hông, so với trục ngang. 90° = đứng thẳng, 0° = nằm ngang.
- **hip_velocity:** Tốc độ dịch chuyển của hông theo trục Y trong image coordinates. Dương = đi xuống.
- **5 frame liên tiếp:** Sliding counter để loại false positive do keypoint flickering.

### Negative Cases — Phân biệt té ngã vs. hành động bình thường

| Hành động | body_angle | hip_velocity | Kết quả |
|-----------|-----------|--------------|---------|
| **Đứng thẳng** | ~85–90° | ~0 | NORMAL |
| **Ngồi xuống từ từ** | 60°→45° trong 2–3s | +20–40 px/s | NORMAL (velocity thấp) |
| **Ngồi xuống đột ngột** | 70°→30° trong 0.3s | +60–80 px/s | BORDERLINE (cần threshold) |
| **Cúi nhặt đồ** | ~30–40° nhưng rồi tăng lại | Biến thiên | NORMAL (nếu angle tăng lại < 3s) |
| **Nằm xuống cố ý** | 90°→10° trong 2–5s | +15–30 px/s | NORMAL (velocity thấp) |
| **Ngã ra trước (fall)** | 90°→5° trong 0.2–0.5s | +150–300 px/s | FALL ✓ |
| **Ngã sang ngang (fall)** | 90°→20° trong 0.3s | +120–200 px/s | FALL ✓ |
| **Khuỵu gối (fall)** | 60°→25° trong 0.3s + knee angle | +80–120 px/s | FALL ✓ |
| **Chơi với cháu dưới sàn** | ~10–20°, duy trì | ~0 | FALSE POSITIVE RISK |

**Xử lý False Positive "chơi dưới sàn":**
- Nếu `body_angle < 30°` nhưng `hip_velocity < 20 px/s` trong > 5 giây liên tiếp → đây là "nằm cố ý" → không trigger fall
- Nếu `body_angle < 30°` và trong 30 giây sau, người có xuyên qua `body_angle > 70°` → reset state machine (không escalate từ LOW)

**Xử lý ánh sáng yếu:**
- YOLOv8 confidence keypoint < 0.5 → không dùng keypoint đó
- Nếu ≥ 4 keypoints (trong 8) confidence < 0.5 → bỏ qua frame, không trigger fall detection
- Ghi log "low_confidence_frame" để monitor camera quality

---

## 7. Severity State Machine

```
                    ┌─────────────────────────────┐
                    │           NORMAL             │
                    │    body_angle > 70° liên tục │
                    └──────────────┬──────────────┘
                                   │
                    body_angle < 45° OR velocity > 80 px/s
                    (5 frame liên tiếp)
                                   │
                                   ▼
                    ┌─────────────────────────────┐
                    │       FALL_DETECTED          │
                    │    timer bắt đầu chạy        │
                    └──────┬──────────────┬────────┘
                           │              │
              người đứng dậy         bất động tiếp tục
              (body_angle > 70°)          │
                           │              │ t >= 30s
                           ▼              ▼
                    ┌──────────┐   ┌─────────────────────────────┐
                    │   LOW    │   │           MEDIUM             │
                    │ log only │   │  → Push notification (nhẹ)  │
                    │ no push  │   │  "Người thân có thể cần      │
                    └──────────┘   │   kiểm tra"                 │
                    (reset về      └──────────────┬──────────────┘
                    NORMAL)                        │
                                                   │ t >= 120s (2 phút)
                                                   ▼
                                   ┌─────────────────────────────┐
                                   │            HIGH              │
                                   │  → Push ưu tiên cao         │
                                   │  → Badge đỏ, âm thanh mạnh  │
                                   │  "Bất động hơn 2 phút!      │
                                   │   Vui lòng gọi điện ngay"   │
                                   └──────────────┬──────────────┘
                                                   │
                                                   │ t >= 300s (5 phút)
                                                   ▼
                                   ┌─────────────────────────────┐
                                   │          CRITICAL            │
                                   │  → Push tất cả contacts     │
                                   │  → SMS emergency contacts   │
                                   │  → Ghi log cho investigation │
                                   │  "KHẨN CẤP: Bất động 5 phút"│
                                   └─────────────────────────────┘
```

**Actions theo severity:**

| Severity | Điều kiện | Push Notification | Clip Upload | Log DB |
|----------|-----------|-------------------|-------------|--------|
| LOW | Tự đứng < 30s | Không | Không (optional) | Có |
| MEDIUM | Bất động 30s–2min | Có (normal priority) | Có | Có |
| HIGH | Bất động > 2min | Có (high priority) | Có | Có |
| CRITICAL | Bất động > 5min | Có (max priority) + tất cả contacts | Có | Có |

**Transition rules đặc biệt:**
- Nếu người đứng dậy trong giai đoạn MEDIUM/HIGH, severity không giảm — event đã được log với severity đó. State machine reset về NORMAL nhưng event record giữ severity cao nhất đạt được.
- Edge device restart → state machine reset về NORMAL. Nếu có sự kiện đang theo dõi lúc restart, event bị mất. Cần log "device_restart" để audit.

---

## 8. LLM Prompt Templates

### 8.1 Alert Message Prompt

```python
# app/services/llm_service.py

ALERT_SYSTEM_PROMPT = """Bạn là trợ lý thông báo an toàn của hệ thống SilentGuard AI.
Nhiệm vụ của bạn là tạo thông báo push notification cho gia đình khi phát hiện người thân có thể bị ngã.

Nguyên tắc viết thông báo:
1. Không gây hoảng loạn không cần thiết — dùng "có thể", "cần kiểm tra" thay vì khẳng định chắc chắn
2. Ngắn gọn: title < 60 ký tự, body < 150 ký tự
3. Tiếng Việt tự nhiên, thân thiện như người nhà nói chuyện
4. Bao gồm thông tin: vị trí, thời gian, thời gian bất động
5. Kêu gọi hành động rõ ràng ở cuối
6. Không dùng từ ngữ kỹ thuật như "severity", "confidence", "detection"

Chỉ trả về JSON theo format sau, không thêm bất kỳ text nào khác:
{"title": "...", "body": "..."}"""


def build_alert_prompt(
    severity: str,
    duration_seconds: int,
    timestamp_local: str,  # "14:32" (giờ địa phương)
    device_location: str,
    person_name: str = "Người thân",
) -> str:
    duration_str = _format_duration(duration_seconds)
    severity_context = {
        "MEDIUM": "phát hiện có thể bị ngã và đang nằm yên",
        "HIGH": "bất động trong thời gian dài, cần kiểm tra gấp",
        "CRITICAL": "bất động rất lâu và không có phản hồi, cần hỗ trợ khẩn cấp",
    }
    context = severity_context.get(severity, "phát hiện sự kiện bất thường")

    return f"""{person_name} {context}.
Thông tin:
- Vị trí: {device_location}
- Thời điểm phát hiện: {timestamp_local}
- Thời gian bất động: {duration_str}
- Mức độ: {severity}

Tạo thông báo push notification cho gia đình."""


def _format_duration(seconds: int) -> str:
    if seconds < 60:
        return f"{seconds} giây"
    minutes = seconds // 60
    remaining_seconds = seconds % 60
    if remaining_seconds == 0:
        return f"{minutes} phút"
    return f"{minutes} phút {remaining_seconds} giây"


# Ví dụ output Claude với severity=HIGH, duration=145s, timestamp_local="14:32", location="phòng khách":
# {
#   "title": "⚠️ Bố bạn cần kiểm tra tại phòng khách",
#   "body": "Phát hiện lúc 14:32, bất động được 2 phút 25 giây. Vui lòng gọi điện hoặc kiểm tra ngay."
# }
```

### 8.2 Daily Report Prompt

```python
DAILY_REPORT_SYSTEM_PROMPT = """Bạn là trợ lý sức khỏe của hệ thống SilentGuard AI.
Nhiệm vụ: Tóm tắt báo cáo ngày cho gia đình về tình trạng của người thân được giám sát.

Nguyên tắc:
1. Viết tiếng Việt tự nhiên, ấm áp như người quen nói chuyện
2. 3–5 câu, không dài hơn
3. Đề cập số lượng sự kiện và mức độ, không dùng từ kỹ thuật
4. Nếu ngày an toàn (chỉ có LOW hoặc không có sự kiện), hãy nói điều tích cực để gia đình yên tâm
5. Nếu có sự kiện HIGH/CRITICAL, nêu rõ và khuyến nghị theo dõi thêm
6. Kết thúc bằng một câu tóm tắt tổng quan

Chỉ trả về text thuần (không JSON, không markdown)."""


def build_daily_report_prompt(
    date_str: str,           # "15/06/2025"
    person_name: str,
    events: list[dict],      # List of event dicts từ DB
) -> str:
    event_lines = []
    for e in events:
        ts_local = e["timestamp_local"]  # "09:15"
        severity = e["severity"]
        duration = _format_duration(e.get("duration_seconds") or 0)
        location = e["device_location"]
        status = e.get("status", "pending")
        label = "(xác nhận là ngã)" if status == "confirmed" else "(chưa xác nhận)"
        event_lines.append(f"  - {ts_local} tại {location}: mức {severity}, bất động {duration} {label}")

    events_text = "\n".join(event_lines) if event_lines else "  - Không có sự kiện nào được ghi nhận."

    return f"""Hôm nay là {date_str}. Người được giám sát: {person_name}.
Tổng số sự kiện: {len(events)}

Danh sách sự kiện:
{events_text}

Viết báo cáo tóm tắt ngày cho gia đình."""


# Ví dụ output với 2 sự kiện LOW + 1 MEDIUM:
# "Hôm nay ông Nam có 3 sự kiện nhỏ được ghi nhận. Hai lần ông vấp
# nhẹ nhưng tự đứng dậy rất nhanh (dưới 15 giây), không đáng lo.
# Có một sự kiện lúc 14:32 tại phòng khách — ông nằm khoảng 1 phút
# rồi tự đứng dậy ổn. Nhìn chung ngày hôm nay bình thường,
# gia đình có thể yên tâm."
```

### 8.3 Config Parser Prompt

```python
CONFIG_PARSER_SYSTEM_PROMPT = """Bạn là trợ lý cấu hình của hệ thống SilentGuard AI.
Nhiệm vụ: Parse câu lệnh tự nhiên của người dùng thành JSON config.

Các config có thể set:
- mute_start: giờ bắt đầu tắt notification (HH:MM, 24h format)
- mute_end: giờ kết thúc tắt notification (HH:MM)
- mute_days: danh sách ngày áp dụng (mon/tue/wed/thu/fri/sat/sun hoặc all)
- min_severity_push: mức severity tối thiểu để push (LOW/MEDIUM/HIGH/CRITICAL)
- daily_report: có gửi báo cáo ngày không (true/false)
- daily_report_time: giờ gửi báo cáo ngày (HH:MM)

Chỉ trả về JSON hợp lệ, không thêm text khác.
Chỉ include các field mà người dùng đề cập, không thêm field khác.
Nếu câu lệnh không liên quan đến config, trả về: {"error": "Không hiểu yêu cầu"}"""


CONFIG_EXAMPLES = [
    {
        "input": "tắt thông báo ban đêm từ 22 giờ đến 6 giờ sáng",
        "output": '{"mute_start": "22:00", "mute_end": "06:00", "mute_days": ["mon","tue","wed","thu","fri","sat","sun"]}'
    },
    {
        "input": "chỉ thông báo khi nguy hiểm cao, bỏ qua mức nhỏ",
        "output": '{"min_severity_push": "HIGH"}'
    },
    {
        "input": "gửi báo cáo ngày lúc 9 giờ tối",
        "output": '{"daily_report": true, "daily_report_time": "21:00"}'
    },
    {
        "input": "tắt báo cáo hàng ngày",
        "output": '{"daily_report": false}'
    },
]


def build_config_parser_prompt(user_input: str) -> str:
    examples_text = "\n".join(
        f'Input: "{ex["input"]}"\nOutput: {ex["output"]}'
        for ex in CONFIG_EXAMPLES
    )
    return f"""Dưới đây là một số ví dụ:
{examples_text}

Bây giờ parse câu lệnh sau:
Input: "{user_input}"
Output:"""
```

---

## 9. Dataset & Training Plan

### 9.1 Public Datasets

| Dataset | Số video/sequence | Loại | Link | Ghi chú |
|---------|------------------|------|------|--------|
| **URFD** (UR Fall Detection) | 70 fall sequences, 40 non-fall | Depth + RGB | urfall.kcl.ac.uk | Camera ceiling-mounted, góc nhìn tốt cho bài toán |
| **Le2i Fall Detection** | 191 videos | RGB | Liên hệ tác giả | 4 môi trường khác nhau, bao gồm kitchen, living room |
| **RWF-2000** | 2000 clips | RGB | GitHub: mchengny/RWF-2000 | Chủ yếu bạo lực nhưng có nhiều negative fall cases |
| **NTU RGB+D** (subset) | Chọn action classes: fall, sit, lie | Skeleton + RGB | rose1.ntu.edu.sg | 60 action classes, lấy 5 class liên quan |
| **MHAD** (Berkeley) | Multimodal sequences | Skeleton | tele.ucsd.edu | Có IMU + skeleton, dùng để validate skeleton features |

### 9.2 Dữ liệu tự quay — Staged Data

**Setup camera cho staging:**
- Góc camera: nhìn xuống 45–60° (góc điển hình camera đặt trong phòng khách/phòng ngủ nhà người cao tuổi)
- Chiều cao: 1.8m–2.5m (gắn trên tường hoặc góc trần)
- FOV: ≥ 120° (wide-angle USB camera hoặc Raspberry Pi Camera Module 3)
- Lighting: 3 điều kiện: ánh sáng ban ngày tốt (>500 lux), ánh sáng yếu buổi tối (~50 lux), ban đêm với đèn ngủ (~10 lux)

**Fall scenarios cần quay (mỗi loại ≥ 20 lần):**

| Scenario | Mô tả | Người thực hiện |
|----------|-------|----------------|
| Forward fall | Ngã ra trước, tay không kịp đỡ | Nam/nữ, 2 người |
| Lateral fall (left) | Ngã sang trái | Nam/nữ, 2 người |
| Lateral fall (right) | Ngã sang phải | Nam/nữ, 2 người |
| Knee buckle | Khuỵu gối, từ từ ngã | Nam/nữ, 2 người |
| Backward fall | Ngã ra sau (nguy hiểm nhất) | Dùng mat, 1 người |
| Fall near obstacle | Ngã gần bàn/ghế, bị che một phần | 1 người |

**Negative cases (quan trọng — phải có ≥ 40 clip/loại):**

| Scenario | Lý do cần đặc biệt chú ý |
|----------|-------------------------|
| Ngồi xuống ghế thấp đột ngột | body_angle giảm nhanh, dễ false positive |
| Cúi nhặt đồ dưới sàn | body_angle < 45° nhưng ngắn hạn |
| Nằm xuống giường/sofa cố ý | body_angle giảm nhưng velocity thấp |
| Chơi với cháu dưới sàn | Nằm sàn lâu, không nguy hiểm |
| Tập yoga/exercise | Nhiều tư thế bất thường |
| Ngồi xếp bằng trên sàn | body_angle thấp, bình thường |
| Cúi lấy đồ trong tủ thấp | Cúi lâu, có thể confuse classifier |

### 9.3 Training Pipeline

```
Bước 1: EDA (Exploratory Data Analysis)
├── Load URFD + Le2i → extract skeleton với YOLOv8-Pose
├── Visualize keypoint confidence distribution
├── Plot body_angle vs. time cho fall vs. non-fall sequences
├── Identify optimal thresholds cho body_angle và velocity
└── Output: threshold_analysis.ipynb, optimal_angle=45°, optimal_velocity=80px/s

Bước 2: YOLOv8-Pose Fine-tune (nếu cần)
├── Nếu pretrained model miss nhiều keypoints trên staged data:
│   ├── Annotate 500 frames từ staged video (LabelMe → COCO format)
│   ├── Fine-tune yolov8n-pose trên custom data (pose estimation task)
│   └── Validate: keypoint confidence > 0.7 trên 90% frames
└── Nếu pretrained đủ tốt: skip bước này, tiết kiệm 1 tuần

Bước 3: Rule-based Classifier Calibration
├── Chạy classifier trên toàn bộ URFD + Le2i
├── Grid search threshold: angle=[30,35,40,45,50]°, velocity=[60,70,80,90,100]px/s
├── Optimize F1-score với trọng số recall cao hơn (miss fall > false alarm)
├── Target: Recall ≥ 0.95 (với HIGH/CRITICAL), Precision ≥ 0.80
└── Output: optimal_thresholds.json

Bước 4: Evaluate trên Staged Data
├── Split: 80% train / 20% test (không overlap người)
├── Metrics: Precision, Recall, F1, Latency (ms từ fall đến detection)
├── Phân tích false positives theo loại (ngồi/cúi/nằm)
├── Phân tích false negatives theo loại ngã
└── Output: evaluation_report.md

Bước 5: Deploy
├── Export model sang NCNN (ARM) hoặc ONNX (x86)
├── Benchmark inference time trên Raspberry Pi 5
├── Package với edge pipeline code
└── Tag version: yolov8n-pose-silentguard-v1.0
```

---

## 10. Kế hoạch 1 tuần Demo đầu tiên

| Ngày | Việc cần làm | Output / Done khi |
|------|-------------|------------------|
| **Ngày 1** (Thứ 2) | Setup FastAPI project structure + Supabase + Firebase Admin SDK | `GET /health` trả về 200, connect Supabase thành công, verify Firebase token không lỗi |
| **Ngày 2** (Thứ 3) | Migrate DB schema (SQL DDL chạy trên Supabase), implement `POST /api/events/detect` endpoint với device API key auth | API nhận được request từ curl, lưu event vào DB, trả về 201 |
| **Ngày 3** (Thứ 4) | Viết Mock Edge Script (Python) gửi fake events với severity ngẫu nhiên, simulate duration-based escalation | Script chạy được, backend nhận events, thấy records trong Supabase Studio |
| **Ngày 4** (Thứ 5) | Implement Alert Engine: severity >= MEDIUM → gửi FCM push notification | Mobile nhận được push notification khi mock script gửi MEDIUM/HIGH event |
| **Ngày 5** (Thứ 6) | Mobile app kết nối API: login Firebase, GET events, hiển thị list | App show được danh sách events từ backend, có auth |
| **Ngày 6** (Thứ 7) | Tích hợp Claude: alert message generation + daily report | Push notification có message tiếng Việt từ Claude, `/api/reports/daily` trả về AI report |
| **Ngày 7** (Chủ nhật) | Bug fix, polish demo flow, chuẩn bị kịch bản demo | Chạy được demo hoàn chỉnh: mock fall → push → mobile alert → review |

### Mock Edge Script

```python
# edge/mock_edge.py — Simulate edge device gửi events với severity escalation
import asyncio
import httpx
import json
import random
import time
from datetime import datetime, timezone

BACKEND_URL = "http://localhost:8000"
DEVICE_API_KEY = "sg_dev_test_key_replace_me"
DEVICE_ID = "550e8400-e29b-41d4-a716-446655440000"  # Từ Supabase sau khi tạo device

# Các kịch bản demo
SCENARIOS = [
    {
        "name": "LOW — tự đứng dậy nhanh",
        "severity": "LOW",
        "confidence": 0.65,
        "duration_seconds": 12,
    },
    {
        "name": "MEDIUM — bất động 45 giây",
        "severity": "MEDIUM",
        "confidence": 0.78,
        "duration_seconds": 45,
    },
    {
        "name": "HIGH — bất động 3 phút",
        "severity": "HIGH",
        "confidence": 0.91,
        "duration_seconds": 185,
    },
    {
        "name": "CRITICAL — bất động 6 phút",
        "severity": "CRITICAL",
        "confidence": 0.96,
        "duration_seconds": 362,
    },
]

LOCATIONS = ["phòng khách", "phòng ngủ", "nhà bếp", "hành lang"]


async def send_mock_event(scenario: dict, location: str) -> None:
    """Gửi một event giả lập lên backend."""
    now = datetime.now(timezone.utc)
    duration = scenario["duration_seconds"]

    metadata = {
        "device_id": DEVICE_ID,
        "severity": scenario["severity"],
        "confidence": scenario["confidence"] + random.uniform(-0.05, 0.05),
        "timestamp": now.isoformat(),
        "duration_seconds": duration,
        "ai_model_version": "mock-v1.0",
        "clip_start_ts": now.isoformat(),  # Mock: dùng cùng timestamp
        "clip_end_ts": now.isoformat(),
        "keypoints_json": {
            "nose":           [320 + random.randint(-20, 20), 180, 0.90],
            "left_shoulder":  [290, 220, 0.85],
            "right_shoulder": [350, 220, 0.87],
            "left_hip":       [295, 310, 0.80],
            "right_hip":      [345, 310, 0.82],
            "left_knee":      [280, 390, 0.75],
            "right_knee":     [360, 395, 0.73],
            "left_ankle":     [265, 460, 0.68],
            "right_ankle":    [375, 455, 0.65],
        },
    }

    files = {"metadata": (None, json.dumps(metadata), "application/json")}
    # Không gửi clip thật — backend xử lý được clip=None

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            f"{BACKEND_URL}/api/events/detect",
            headers={"X-Device-Key": DEVICE_API_KEY},
            files=files,
        )
        if response.status_code == 201:
            data = response.json()
            print(f"[OK] {scenario['name']} at {location}")
            print(f"     event_id={data['event_id']}, alert={data['alert_triggered']}")
        else:
            print(f"[FAIL] {response.status_code}: {response.text}")


async def run_demo_sequence() -> None:
    """Chạy sequence: LOW → MEDIUM → HIGH → CRITICAL với delay giữa các bước."""
    print("=" * 60)
    print("SilentGuard Mock Edge — Demo Sequence")
    print("=" * 60)

    for scenario in SCENARIOS:
        location = random.choice(LOCATIONS)
        print(f"\n[DEMO] Sending: {scenario['name']}")
        await send_mock_event(scenario, location)
        await asyncio.sleep(5)  # Chờ 5 giây giữa các event

    print("\n[DONE] Demo sequence completed.")


async def run_random_continuous(interval_seconds: int = 30) -> None:
    """Gửi events ngẫu nhiên liên tục (dùng để stress test)."""
    print(f"[INFO] Sending random events every {interval_seconds}s. Ctrl+C to stop.")
    while True:
        # Xác suất theo phân phối thực tế
        weights = [0.60, 0.25, 0.12, 0.03]  # LOW, MEDIUM, HIGH, CRITICAL
        scenario = random.choices(SCENARIOS, weights=weights, k=1)[0]
        location = random.choice(LOCATIONS)
        await send_mock_event(scenario, location)
        await asyncio.sleep(interval_seconds)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "continuous":
        asyncio.run(run_random_continuous())
    else:
        asyncio.run(run_demo_sequence())
```

---

## 11. Thứ tự ưu tiên khi chậm tiến độ

Nếu timeline bị trễ, **giữ từ trên xuống, cắt từ dưới lên**:

```
MUST HAVE (không cắt, đây là core MVP)
──────────────────────────────────────────────────────────
 1. POST /api/events/detect nhận event từ edge (hoặc mock)
 2. Supabase: INSERT event vào database
 3. FCM push notification khi severity >= MEDIUM
 4. Mobile app nhận push notification (background)
 5. Mobile app: đăng nhập Firebase Auth
 6. Mobile app: xem danh sách events (GET /api/events/)
──────────────────────────────────────────────────────────

SHOULD HAVE (cố gắng có, cắt nếu không kịp)
──────────────────────────────────────────────────────────
 7. Claude: alert message tiếng Việt trong push notification
 8. Video clip upload + xem clip trên mobile
 9. Mobile app: Review event (confirm/false positive)
10. GET /api/reports/daily (basic summary, không cần Claude)
──────────────────────────────────────────────────────────

NICE TO HAVE (để sau demo nếu có thời gian)
──────────────────────────────────────────────────────────
11. Claude daily report (AI-generated text)
12. Config parser (tắt notification ban đêm)
13. Device heartbeat monitoring
14. Multiple devices per user
15. Emergency contacts notification khi CRITICAL
16. Dashboard charts (events per day, severity distribution)
──────────────────────────────────────────────────────────

PHASE 2 (không trong scope demo)
──────────────────────────────────────────────────────────
17. Twilio auto-call khi CRITICAL
18. YOLOv8 fine-tuning trên custom dataset
19. Per-user threshold calibration
20. Multi-camera support
21. GDPR data export / deletion
```

**Quy tắc khi cắt feature:**
- Thông báo cho team ngay khi biết feature sẽ không kịp — đừng để đến ngày demo mới biết.
- Mock data là acceptable trong demo nếu flow end-to-end hoạt động được. Ví dụ: clip URL là dummy URL nhưng push notification vẫn gửi được.
- Không cắt bất kỳ feature nào từ nhóm MUST HAVE.

---

## 12. Rủi ro & Biện pháp

| # | Rủi ro | Xác suất | Mức độ ảnh hưởng | Biện pháp |
|---|--------|----------|-----------------|----------|
| R1 | **YOLOv8-Pose false positive cao** — ngồi xuống bị nhận là ngã, alert fatigue từ ngày đầu demo | Cao | Cao | Calibrate threshold trên Le2i trước demo. Tăng FALL_CONFIRMATION_FRAMES từ 5 lên 8. Có nút "Mark as false positive" trong mobile app để user report. |
| R2 | **Edge device Raspberry Pi 5 không đủ mạnh** — FPS drop < 15fps, latency tăng | Trung bình | Cao | Dùng yolov8n-pose (nano) thay vì small. Export sang NCNN backend. Fallback: chạy pipeline trên Intel NUC. Giảm resolution từ 720p xuống 480p cho inference. |
| R3 | **FCM push không đến được iOS khi app bị kill** — demo fail tại điểm quan trọng nhất | Thấp | Rất cao | Test FCM background push trên iOS thật (không phải simulator) ít nhất 3 ngày trước demo. Chuẩn bị Android backup device. Verify APNs certificate được upload lên Firebase. |
| R4 | **Supabase free tier hết quota** — 500MB DB hoặc 1GB Storage đầy trong demo | Thấp | Trung bình | Monitor usage mỗi ngày qua Supabase Dashboard. Xóa events cũ và clips cũ trước demo. Nếu cần, upgrade tạm lên Pro ($25/tháng). |
| R5 | **Claude API rate limit** — nhiều events cùng lúc trong demo, LLM calls bị throttle | Trung bình | Thấp | Implement fallback template message khi Claude timeout. Queue Claude calls với asyncio.Queue, max 2 concurrent requests. Cache daily report (không gọi lại nếu đã generate trong ngày). |
| R6 | **Privacy concern từ người dùng thực hoặc ban giám khảo** — câu hỏi khó về "camera có ghi không?" | Cao | Cao | Chuẩn bị câu trả lời rõ ràng: "Raw video chỉ trong RAM, không bao giờ ghi disk hay gửi lên cloud. Chỉ clip đã blur khuôn mặt được upload." Chuẩn bị slide về privacy architecture. Demo live: show Supabase Storage chỉ có clip blur, không có raw video. |

---

## 13. Definition of Done MVP

### Core System
- [ ] Edge pipeline chạy ổn định ≥ 1 giờ không crash trên Raspberry Pi 5 hoặc NUC
- [ ] YOLOv8-Pose inference < 50ms/frame trong điều kiện ánh sáng bình thường
- [ ] Fall detection hoạt động trên ít nhất 5 trong 7 fall scenarios từ staged data
- [ ] False positive rate < 20% với các negative cases (ngồi, cúi, nằm cố ý)
- [ ] Raw video không bao giờ ghi disk hay gửi lên cloud (verify bằng network monitor)

### Backend
- [ ] `POST /api/events/detect` nhận event + clip trong < 5 giây
- [ ] Event được lưu vào Supabase với đầy đủ fields
- [ ] Clip đã blur được upload lên Supabase Storage và có signed URL
- [ ] `GET /api/events/` trả về danh sách đúng theo user's devices
- [ ] `GET /api/reports/daily` trả về summary và AI report
- [ ] Firebase token verification hoạt động đúng (reject invalid token)
- [ ] Device API key authentication hoạt động đúng
- [ ] `/health` endpoint trả về status của tất cả services

### Alert System
- [ ] FCM push notification gửi thành công khi severity = MEDIUM
- [ ] Push notification đến được device khi app đang tắt (background push)
- [ ] Alert message là tiếng Việt tự nhiên do Claude generate
- [ ] Fallback template message hoạt động khi Claude unavailable
- [ ] CRITICAL severity gửi notification đến tất cả emergency contacts

### Mobile App
- [ ] Đăng nhập bằng Firebase Auth (Email hoặc Google)
- [ ] Nhận FCM push notification (foreground + background)
- [ ] Xem danh sách events với severity badge và timestamp
- [ ] Xem video clip đã blur trong app
- [ ] Review event: confirm fall hoặc mark as false positive
- [ ] Xem daily report

### Privacy & Security
- [ ] Kiểm tra không có raw video frame nào được lưu vào disk trên edge device
- [ ] Clip trong Supabase Storage: khuôn mặt bị blur (verify thủ công)
- [ ] Signed URL hết hạn sau 1 giờ (không accessible sau đó)
- [ ] API không leak data của user khác (authorization check)

### Demo Readiness
- [ ] Kịch bản demo chạy được đầu đến cuối không lỗi: mock fall → push → review
- [ ] Mock edge script hoạt động ổn định
- [ ] Database có sẵn ≥ 10 events sample cho demo
- [ ] Slide giải thích privacy architecture sẵn sàng
- [ ] Câu trả lời cho câu hỏi thường gặp được chuẩn bị