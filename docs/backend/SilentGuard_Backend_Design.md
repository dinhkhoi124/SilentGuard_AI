# SilentGuard AI — Backend Design Document (MVP V1)

> Stack: **FastAPI (Python) + Supabase (Postgres + Storage)**, xác thực qua **Firebase Auth** (verify token), push qua **Firebase Cloud Messaging (FCM)**, LLM qua **Claude API**.

---

## 1. Tổng quan kiến trúc

```
┌────────────────┐     POST /api/events/detect      ┌──────────────────────────┐
│  Edge Device     │ ───────(device API key)────────▶ │                          │
│  (RPi/NUC)       │                                  │   FastAPI Backend        │
│  - YOLOv8-Pose   │                                  │                          │
│  - Severity calc │ ◀──── 200 OK / error ─────────── │   - Severity Engine      │
│  - Blur clip     │                                  │   - Alert Engine         │
└────────────────┘                                  │   - Notification Service │
        │ upload clip (blurred)                       │   - LLM Service          │
        ▼                                              └──────┬─────────┬─────────┘
┌──────────────────────────┐                                  │         │
│  Supabase Storage          │ ◀────────────────────────────────┘         │
│  (clip MP4 đã blur)        │                                              │
└──────────────────────────┘                                              │
┌──────────────────────────┐                                              │
│  Supabase Postgres          │ ◀── CRUD (events, alert_reviews, users,    │
│  (events, users, contacts,  │      cameras, thresholds, daily_reports)   │
│   thresholds, reviews...)   │                                              │
└──────────────────────────┘                                              │
                                                                            ▼
                                                                  ┌───────────────────┐
                                                                  │ Firebase Cloud      │
                                                                  │ Messaging (FCM)     │
                                                                  └─────────┬───────────┘
                                                                            │ push
                                                                            ▼
┌──────────────────────────┐  GET/PATCH /api/...  (Authorization:        ┌────────────┐
│  Firebase Auth (mobile)     │ ───── Bearer <Firebase ID Token> ────────▶ │ Mobile App  │
│  (verify bằng firebase-admin)│ ◀──────────── JSON response ───────────── │             │
└──────────────────────────┘                                              └────────────┘
```

**Nguyên tắc**: Postgres/Supabase là nguồn dữ liệu duy nhất (single source of truth). Firebase chỉ là (1) auth provider được verify ở backend, (2) channel gửi push. Không dùng Firestore.

---

## 2. Database Schema (Postgres / Supabase)

```sql
-- ============ USERS ============
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid    TEXT UNIQUE NOT NULL,
    full_name       TEXT,
    email           TEXT UNIQUE,
    phone           TEXT,
    fcm_token       TEXT,
    role            TEXT DEFAULT 'family' CHECK (role IN ('family', 'admin')),
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ============ ELDERLY PROFILE ============
CREATE TABLE households (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elderly_name    TEXT,
    owner_user_id   UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ============ CONTACTS (priority list để escalate) ============
-- FIX: user_id dùng ON DELETE SET NULL để giữ lại lịch sử khi user bị xóa
CREATE TABLE contacts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id    UUID REFERENCES households(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    priority_order  INT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now(),
    UNIQUE (household_id, priority_order)
);

-- ============ CAMERAS / EDGE DEVICES ============
CREATE TABLE cameras (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id         UUID REFERENCES households(id) ON DELETE CASCADE,
    name                 TEXT,
    room                 TEXT,
    device_api_key_hash  TEXT UNIQUE NOT NULL,
    status               TEXT DEFAULT 'unknown' CHECK (status IN ('online', 'offline', 'unknown')),
    fps                  INT DEFAULT 15,
    last_heartbeat       TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT now()
);
-- LƯU Ý: Khi tạo camera, sinh key plain bằng secrets.token_urlsafe(32),
-- trả về cho admin 1 lần duy nhất, lưu SHA-256 hash vào DB.
-- Verify: hashlib.sha256(incoming_key.encode()).hexdigest() == stored_hash

-- ============ EVENTS ============
CREATE TABLE events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id        TEXT UNIQUE NOT NULL,
    household_id    UUID REFERENCES households(id),
    camera_id       UUID REFERENCES cameras(id),
    event_type      TEXT NOT NULL,
    severity        TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'SYSTEM')),
    confidence      NUMERIC(4,3) NOT NULL,
    timestamp       TIMESTAMPTZ NOT NULL,
    duration_sec    INT,
    room            TEXT,
    clip_path       TEXT,
    llm_message     TEXT,
    status          TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'acknowledged', 'dismissed', 'escalated', 'logged_only')),
    escalate_after  TIMESTAMPTZ,
    model_ver       TEXT,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_events_household_status ON events(household_id, status);
CREATE INDEX idx_events_timestamp ON events(timestamp);
-- FIX: Partial index cho escalation check job — nhỏ và nhanh hơn full scan
CREATE INDEX idx_events_escalate_after ON events(escalate_after)
    WHERE status = 'pending' AND escalate_after IS NOT NULL;

-- ============ ALERT REVIEWS ============
CREATE TABLE alert_reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id        UUID REFERENCES events(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),
    action          TEXT NOT NULL CHECK (action IN ('acknowledged', 'dismissed')),
    note            TEXT,
    clip_timestamp  NUMERIC,
    reviewed_at     TIMESTAMPTZ DEFAULT now()
);

-- FIX: Thêm index — event_id được query thường xuyên khi load review
CREATE INDEX idx_alert_reviews_event_id ON alert_reviews(event_id);

-- ============ ESCALATION LOG ============
-- FIX: contact_id dùng ON DELETE SET NULL để giữ log audit khi contact bị xóa
CREATE TABLE escalations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id        UUID REFERENCES events(id) ON DELETE CASCADE,
    contact_id      UUID REFERENCES contacts(id) ON DELETE SET NULL,
    channel         TEXT NOT NULL CHECK (channel IN ('push', 'call')),
    status          TEXT DEFAULT 'sent' CHECK (status IN ('sent', 'acknowledged', 'failed')),
    sent_at         TIMESTAMPTZ DEFAULT now()
);

-- FIX: Thêm index cho escalation log
CREATE INDEX idx_escalations_event_id ON escalations(event_id);

-- ============ THRESHOLDS / CONFIG per household ============
CREATE TABLE thresholds (
    household_id        UUID PRIMARY KEY REFERENCES households(id) ON DELETE CASCADE,
    low_max_sec          INT DEFAULT 30,
    medium_max_sec       INT DEFAULT 120,
    high_max_sec         INT DEFAULT 300,
    dedup_window_sec     INT DEFAULT 60,       -- FIX: window dedup multi-camera, có thể config per household
    suppress_windows     JSONB DEFAULT '[]',
    updated_at           TIMESTAMPTZ DEFAULT now()
);

-- ============ DAILY REPORTS ============
CREATE TABLE daily_reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id    UUID REFERENCES households(id) ON DELETE CASCADE,
    report_date     DATE NOT NULL,
    summary         TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    UNIQUE (household_id, report_date)
);

-- ============ HOUSEHOLD MEMBERS & INVITES ============
CREATE TABLE household_members (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id    UUID REFERENCES households(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    role            TEXT NOT NULL CHECK (role IN ('owner', 'member')),
    joined_at       TIMESTAMPTZ DEFAULT now(),
    UNIQUE (household_id, user_id)
);
CREATE INDEX idx_household_members_user ON household_members(user_id);
CREATE INDEX idx_household_members_household ON household_members(household_id);

CREATE TABLE household_invites (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id    UUID REFERENCES households(id) ON DELETE CASCADE,
    code            TEXT UNIQUE NOT NULL,
    created_by      UUID REFERENCES users(id),
    expires_at      TIMESTAMPTZ NOT NULL,
    used_at         TIMESTAMPTZ,
    used_by         UUID REFERENCES users(id)
);
CREATE INDEX idx_household_invites_code ON household_invites(code);

```

---

## 3. Auth Flow & Phân quyền (Firebase Auth ↔ Backend)

1. Mobile app đăng nhập bằng Firebase Auth → nhận `idToken` (JWT).
2. Mọi request gọi API kèm header: `Authorization: Bearer <idToken>`.
3. Khi thực hiện đăng ký/đăng nhập lần đầu:
   - Nếu người dùng được mời vào hộ gia đình có sẵn, app cần truyền thêm header tùy chọn `X-Invite-Code: <mã_mời>`.
   - Backend dùng `firebase_admin.auth.verify_id_token(token)` → lấy `firebase_uid`.
   - Nếu người dùng mới và có `X-Invite-Code`: Backend sẽ xác thực mã mời, gán người dùng làm `member` của hộ gia đình đó, và đánh dấu mã mời đã dùng.
   - Nếu người dùng mới và không có `X-Invite-Code`: Backend tự động tạo một `households` mới và gán người dùng này làm `owner`.
4. Gắn `current_user` (UUID nội bộ) vào request context.
5. **Kiểm tra quyền truy cập (Authorization)**:
   - Các API liên quan đến hộ gia đình (alerts, dashboard, settings, reports) áp dụng bộ lọc quyền truy cập thông qua dependency `require_household_role(owner_only=True/False)`.
   - Router tự động trích xuất `household_id` từ Path, Query parameters hoặc JSON Body, xác thực xem `current_user` có quyền truy cập (vai trò `owner` hoặc `member`) hay không. Nếu không có quyền, trả về lỗi `403 FORBIDDEN` đúng chuẩn.
   - Chỉ tài khoản có quyền `owner` mới được thực hiện các tác vụ quản trị: cập nhật ngưỡng thời gian (thresholds), tạo mã mời thành viên mới.

```python
# app/core/security.py
# (Xem mã nguồn thực tế tại backend/app/core/security.py để biết thêm chi tiết)
```

**Edge device auth**: mỗi camera có `device_api_key` riêng, gửi qua header `X-Device-Key`. Backend so khớp hash với DB, không dùng Firebase cho edge.


---

## 4. API Endpoints — Contract đầy đủ

### 4.0 `POST /api/cameras/upload-url` — Lấy presigned URL để upload clip

Header: `X-Device-Key: <device_api_key>`

Request:
```json
{ "filename": "EVT-20260613-001_blur.mp4", "content_type": "video/mp4" }
```

Response:
```json
{
  "upload_url": "https://xxxx.supabase.co/storage/v1/object/sign/clips/...?token=...",
  "clip_path": "clips/household-uuid/EVT-20260613-001_blur.mp4",
  "expires_in": 300
}
```

Luồng đúng:
1. Edge device gọi `POST /api/cameras/upload-url` → nhận `upload_url` + `clip_path`.
2. Edge device PUT clip lên `upload_url` (presigned, 5 phút hết hạn).
3. Edge device gọi `POST /api/events/detect` kèm `clip_path`.

---

### 4.1 `POST /api/events/detect`

Header: `X-Device-Key: <device_api_key>`

Request:
```json
{
  "event_id": "EVT-20260613-001",
  "event_type": "fall",
  "severity": "HIGH",
  "confidence": 0.89,
  "timestamp": "2026-06-13T02:15:10Z",
  "duration_sec": 145,
  "room": "bedroom",
  "clip_path": "clips/household-uuid/EVT-20260613-001_blur.mp4",
  "model_ver": "v1.0.0"
}
```

Xử lý:
1. Xác thực `device_api_key` → lấy `camera_id`, `household_id`.
2. Validate severity theo `thresholds` của household.
3. Insert vào `events`.
4. Nếu `severity != LOW` → gọi `AlertEngine.process(event)`.

Response:
```json
{ "status": "received", "event_id": "EVT-20260613-001" }
```

### 4.2 `GET /api/alerts?status=pending&limit=20&offset=0&household_id=<uuid>`

Header: `Authorization: Bearer <token>`

Response:
```json
{
  "items": [
    {
      "id": "uuid",
      "event_id": "EVT-20260613-001",
      "severity": "HIGH",
      "confidence": 0.89,
      "timestamp": "2026-06-13T02:15:10Z",
      "duration_sec": 145,
      "room": "bedroom",
      "clip_path": "clips/household-uuid/EVT-20260613-001_blur.mp4",
      "llm_message": "Ba bạn vừa ngã trong phòng ngủ lúc 2 giờ sáng...",
      "status": "pending"
    }
  ],
  "total": 1
}
```

> `clip_path` thay cho `clip_url`. Signed URL chỉ được tạo khi gọi `GET /api/events/{id}`.

### 4.3 `PATCH /api/alerts/{event_id}/review`

Request:
```json
{ "action": "acknowledged", "note": "Đã gọi cho bố, ổn rồi", "clip_timestamp": 8.2 }
```

Xử lý:
- Insert vào `alert_reviews`.
- Update `events.status`.
- Nếu `acknowledged` → cancel escalation (set `escalate_after = NULL`).

Response: `{ "status": "ok" }`

### 4.4 `GET /api/dashboard/summary`

Response:
```json
{
  "total_alerts_today": 3,
  "avg_response_time_sec": 42,
  "acknowledged": 2,
  "total": 3,
  "by_severity": { "LOW": 1, "MEDIUM": 1, "HIGH": 1, "CRITICAL": 0 },
  "cameras": [
    { "name": "Camera phòng ngủ", "status": "online", "fps": 15 },
    { "name": "Camera phòng khách", "status": "online", "fps": 15 }
  ]
}
```

### 4.5 `GET /api/events/{event_id}` — Alert detail

Trả về đầy đủ 1 event + `clip_url` (signed URL từ Supabase Storage, hết hạn sau X phút).

### 4.6 `POST /api/users/device-token`

Request: `{ "fcm_token": "..." }` → lưu vào `users.fcm_token` của `current_user`.

### 4.7 Contacts management

- `GET /api/contacts`
- `POST /api/contacts` — `{ "user_id": "...", "priority_order": 2 }`
- `PATCH /api/contacts/{id}` — đổi `priority_order`
- `DELETE /api/contacts/{id}`

> Lưu ý: `priority_order` là số nguyên tuyệt đối. Khi xóa contact ở giữa danh sách, app layer cần reorder lại các contact còn lại để tránh gap (`1, 3` → `1, 2`).

### 4.8 Thresholds / Settings

- `GET /api/settings/thresholds`
- `PUT /api/settings/thresholds`

```json
{
  "low_max_sec": 30,
  "medium_max_sec": 120,
  "high_max_sec": 300,
  "dedup_window_sec": 60,
  "suppress_windows": [
    { "start": "13:00", "end": "15:00", "max_still_sec": 3600 }
  ]
}
```

### 4.9 LLM Config via chat

`POST /api/llm/config`
```json
{ "message": "Ba tôi hay ngủ trưa dưới sàn, đừng báo lúc 1-3 giờ chiều" }
```
→ Backend gọi `LLMService.parse_config(message)` → preview cho user xác nhận → nếu confirm thì `PUT /api/settings/thresholds`.

### 4.10 Daily report

- `GET /api/reports/daily?date=2026-06-13`

### 4.11 `POST /api/households/invite` — Tạo mã mời thành viên mới

Quyền: `owner` (Chủ hộ).

Header: `Authorization: Bearer <token>`

Response:
```json
{
  "code": "random_invite_code_string",
  "expires_at": "2026-06-17T02:15:10Z"
}
```

### 4.12 `GET /api/households/me` — Truy vấn thông tin hộ gia đình của user hiện tại

Quyền: `owner` hoặc `member` (Thành viên hộ gia đình).

Header: `Authorization: Bearer <token>`

Response:
```json
{
  "household_id": "household-uuid",
  "role": "owner",
  "elderly_name": "Nguyen Van A"
}
```

### 4.13 `POST /api/cameras` — Đăng ký camera mới

Quyền: `owner` (Chủ hộ).

Header: `Authorization: Bearer <token>`

Request:
```json
{
  "household_id": "household-uuid",
  "name": "Camera Hành Lang",
  "room": "hallway",
  "fps": 15
}
```

Response:
```json
{
  "camera_id": "camera-uuid",
  "name": "Camera Hành Lang",
  "room": "hallway",
  "device_api_key": "sg_live_randomstring...",
  "warning": "Lưu lại key này ngay — sẽ không hiển thị lại được"
}
```

### 4.14 `GET /api/cameras?household_id=...` — Lấy danh sách camera trong hộ gia đình

Quyền: `owner` hoặc `member` (Thành viên hộ gia đình).

Header: `Authorization: Bearer <token>`

Response:
```json
[
  {
    "id": "camera-uuid",
    "name": "Camera Hành Lang",
    "room": "hallway",
    "status": "unknown",
    "fps": 15,
    "last_heartbeat": null,
    "created_at": "2026-06-16T09:00:00Z"
  }
]
```
*(Lưu ý: Không bao giờ trả về device_api_key hay hash của nó ở endpoint này)*

### 4.15 `PATCH /api/cameras/{camera_id}/rotate-key` — Đổi mã kết nối camera mới

Quyền: `owner` (Chủ hộ).

Header: `Authorization: Bearer <token>`

Response:
```json
{
  "camera_id": "camera-uuid",
  "device_api_key": "sg_live_newrandomstring...",
  "warning": "Lưu lại key này ngay — sẽ không hiển thị lại được"
}
```
*(Lưu ý: Sau khi rotate, khóa cũ sẽ bị vô hiệu hóa lập tức, trả về 401 Unauthorized khi gửi sự kiện)*

### 4.16 `DELETE /api/cameras/{camera_id}` — Xóa camera (Soft delete)

Quyền: `owner` (Chủ hộ).

Header: `Authorization: Bearer <token>`

Response:
```json
{ "status": "ok" }
```
*(Lưu ý: Đánh dấu deleted_at = now() để giữ lịch sử sự kiện cũ không bị lỗi khóa ngoại)*

### 4.17 `PATCH /api/cameras/{camera_id}` — Sửa thông tin camera

Quyền: `owner` (Chủ hộ).

Header: `Authorization: Bearer <token>`

Request:
```json
{
  "name": "Camera Phòng Ngủ Mới",
  "room": "bedroom",
  "fps": 10
}
```

Response:
```json
{ "status": "ok" }
```

### 4.18 Camera offline alert (internal)

Heartbeat job kiểm tra `cameras.last_heartbeat`. Nếu quá 5 phút → tạo "system event" (severity = `SYSTEM`) và gửi push "Camera X mất kết nối".

---

## 5. Severity Engine

```python
# app/services/severity_engine.py
def classify_severity(duration_sec: int, thresholds: dict) -> str:
    if duration_sec < thresholds["low_max_sec"]:
        return "LOW"
    elif duration_sec < thresholds["medium_max_sec"]:
        return "MEDIUM"
    elif duration_sec < thresholds["high_max_sec"]:
        return "HIGH"
    else:
        return "CRITICAL"

def is_suppressed(timestamp, duration_sec, suppress_windows) -> bool:
    for w in suppress_windows:
        if _within_window(timestamp, w["start"], w["end"]) and duration_sec < w["max_still_sec"]:
            return True
    return False
```

---

## 6. Alert Engine & Notification Flow

```python
# app/services/alert_engine.py
async def process(event: Event):
    thresholds = await get_thresholds(event.household_id)

    # 1. Dedup check — nhiều camera trong cùng household có thể detect cùng 1 vụ ngã
    #    Window được config per-household qua thresholds.dedup_window_sec (default 60s)
    #    Race condition (2 request đúng cùng lúc) cực hiếm, hậu quả chỉ là duplicate push
    #    → chấp nhận được ở MVP, có thể thêm Redis lock sau nếu cần
    dedup_window = thresholds.get("dedup_window_sec", 60)
    duplicate = await db.fetchrow(f"""
        SELECT id FROM events
        WHERE household_id = $1
          AND event_type   = $2
          AND status      != 'logged_only'
          AND timestamp    > now() - interval '{dedup_window} seconds'
          AND id           != $3
    """, event.household_id, event.event_type, event.id)

    if duplicate:
        # Vẫn giữ event để audit (biết camera nào cũng detect), nhưng không push
        event.status = "logged_only"
        await save_event(event)
        return

    # 2. Suppress check
    if is_suppressed(event.timestamp, event.duration_sec, thresholds.suppress_windows):
        event.status = "logged_only"
        await save_event(event)
        return

    # 3. Reclassify severity theo thresholds của household
    event.severity = classify_severity(event.duration_sec, thresholds)
    if event.severity == "LOW":
        event.status = "logged_only"
        await save_event(event)
        return

    # 4. Push TRƯỚC với default message, KHÔNG block chờ LLM
    contacts = await get_contacts_sorted(event.household_id)
    primary = contacts[0]
    await notification_service.send_push(primary.user_id, event)
    await log_escalation(event.id, primary.id, channel="push")

    # 5. Set escalate_after vào DB — bền vững qua restart, được nhặt bởi job mỗi phút
    if event.severity in ("HIGH", "CRITICAL"):
        event.escalate_after = event.created_at + timedelta(seconds=180)
    await save_event(event)

    # 6. Generate LLM message async sau khi push đã gửi
    asyncio.create_task(_generate_and_update_llm_message(event.id))

async def _generate_and_update_llm_message(event_id: str):
    """Timeout 10s, fallback im lặng — default_message đã được dùng trong push rồi."""
    try:
        event = await get_event(event_id)
        llm_msg = await asyncio.wait_for(
            llm_service.generate_alert_message(event), timeout=10.0
        )
        await update_event_llm_message(event_id, llm_msg)
    except (asyncio.TimeoutError, Exception):
        pass
```

**Escalation check** — tích hợp vào `periodic_check_job` (chạy mỗi phút):

```python
# app/services/scheduler.py
async def periodic_check_job():
    await check_camera_heartbeats()
    await check_pending_escalations()

async def check_pending_escalations():
    overdue = await db.fetch_all("""
        SELECT * FROM events
        WHERE status = 'pending'
          AND escalate_after IS NOT NULL
          AND escalate_after <= now()
    """)
    for event in overdue:
        await run_escalation(event)

async def run_escalation(event):
    contacts = await get_contacts_sorted(event.household_id)

    # FIX: Guard — nếu không có contact backup thì không escalate được
    if len(contacts) < 2:
        await update_event_escalate_after(event.id, None)
        return

    if event.severity == "CRITICAL":
        for c in contacts[1:]:
            await notification_service.trigger_call(c, event)
            await notification_service.send_push(c.user_id, event)
            await log_escalation(event.id, c.id, channel="call")
    else:  # HIGH
        next_contact = contacts[1]
        await notification_service.trigger_call(next_contact, event)
        await log_escalation(event.id, next_contact.id, channel="call")

    # Xóa escalate_after để job không chạy lại lần sau
    await update_event_escalate_after(event.id, None)
    await update_event_status(event.id, "escalated")
```

> "Auto-call" thật cần tích hợp Twilio hoặc tương đương — để như interface `trigger_call()` implement sau (out of scope Sprint 1).

---

## 7. Notification Service (FCM)

```python
# app/services/notification_service.py
from firebase_admin import messaging

async def send_push(user_id: str, event: Event):
    user = await get_user(user_id)
    if not user.fcm_token:
        return
    message = messaging.Message(
        notification=messaging.Notification(
            title=f"Cảnh báo {event.severity} — {event.room}",
            body=event.llm_message or default_message(event),
        ),
        data={
            "event_id": event.event_id,
            "severity": event.severity,
            "clip_url": event.clip_url or "",
        },
        token=user.fcm_token,
    )
    messaging.send(message)
```

---

## 8. LLM Service (Claude API)

```python
# app/services/llm_service.py
async def generate_alert_message(event: Event) -> str:
    prompt = f"""
    Một sự cố té ngã vừa được phát hiện:
    - Mức độ: {event.severity}
    - Thời gian: {event.timestamp}
    - Phòng: {event.room}
    - Bất động: {event.duration_sec} giây

    Viết 1-2 câu tin nhắn tự nhiên, ấm áp, rõ ràng cho gia đình,
    nêu rõ mức độ nghiêm trọng và hành động nên làm.
    """
    return await call_claude(prompt)

async def generate_daily_report(events: list[Event]) -> str:
    # Tổng hợp event log của 1 ngày thành đoạn văn tự nhiên
    ...

from pydantic import BaseModel, Field, validator
from typing import Optional

class SuppressWindow(BaseModel):
    start: str
    end: str
    max_still_sec: int = Field(ge=60, le=86400)

class ParsedConfig(BaseModel):
    low_max_sec: Optional[int] = Field(None, ge=10, le=3600)
    medium_max_sec: Optional[int] = Field(None, ge=10, le=3600)
    high_max_sec: Optional[int] = Field(None, ge=10, le=3600)
    dedup_window_sec: Optional[int] = Field(None, ge=10, le=300)
    suppress_windows: Optional[list[SuppressWindow]] = None

    @validator("medium_max_sec")
    def medium_gt_low(cls, v, values):
        if v and values.get("low_max_sec") and v <= values["low_max_sec"]:
            raise ValueError("medium_max_sec phải lớn hơn low_max_sec")
        return v

async def parse_config(message: str) -> ParsedConfig:
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
    raw = await call_claude(prompt)
    try:
        data = json.loads(raw.strip())
        return ParsedConfig(**data)
    except (json.JSONDecodeError, ValidationError) as e:
        raise ValueError(f"LLM trả output không hợp lệ: {e}")
```

---

## 9. Background Jobs / Scheduler

| Job | Tần suất | Nhiệm vụ |
|---|---|---|
| `periodic_check_job` | mỗi 1 phút | ① Kiểm tra `cameras.last_heartbeat` offline > 5 phút; ② Check `events.escalate_after <= now()` và escalate nếu cần |
| `daily_report_job` | 1 lần/ngày (23:00) | Tổng hợp `events` trong ngày → gọi LLM → lưu `daily_reports` |

Dùng **APScheduler** (chạy trong cùng FastAPI process cho MVP) với 2 interval jobs.

---

## 10. Folder Structure

```
backend/
├── app/
│   ├── main.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   └── supabase_client.py
│   ├── api/
│   │   ├── events.py
│   │   ├── alerts.py
│   │   ├── dashboard.py
│   │   ├── users.py
│   │   ├── settings.py
│   │   └── reports.py
│   ├── services/
│   │   ├── severity_engine.py
│   │   ├── alert_engine.py
│   │   ├── notification_service.py
│   │   ├── llm_service.py
│   │   └── scheduler.py
│   ├── models/
│   │   └── schemas.py
│   └── db/
│       └── queries.py
├── tests/
│   ├── test_severity_engine.py
│   ├── test_alert_engine.py
│   └── test_api_events.py
├── requirements.txt
├── .env.example
└── firebase-service-account.json  (gitignored)
```

---

## 11. Environment Variables (`.env.example`)

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_KEY=xxxx
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
ANTHROPIC_API_KEY=xxxx
APP_ENV=development
```

---

## 12. Error Handling — Format chuẩn

```json
{
  "error": {
    "code": "INVALID_DEVICE_KEY",
    "message": "Device key không hợp lệ hoặc camera chưa đăng ký"
  }
}
```

Mã lỗi thường dùng: `UNAUTHORIZED`, `INVALID_DEVICE_KEY`, `EVENT_NOT_FOUND`, `VALIDATION_ERROR`, `LLM_TIMEOUT`.

---

## 13. Testing Plan

| Loại | Nội dung |
|---|---|
| Unit test | `severity_engine.classify_severity` và `is_suppressed` với các ca biên (29s/30s/120s...) |
| Unit test | `llm_service.parse_config` — kiểm tra output JSON đúng schema với nhiều ca input tiếng Việt |
| Unit test | `alert_engine.process` — 2 camera gửi event cùng household trong vòng `dedup_window_sec` → chỉ 1 push được gửi |
| Integration test | Edge device gọi `POST /api/events/detect` severity HIGH → event được tạo, push được gọi (mock FCM), `escalate_after` được set |
| Integration test | `PATCH /api/alerts/{id}/review` action=acknowledged → `escalate_after` bị set NULL |
| Integration test | `periodic_check_job` nhặt event quá hạn escalate → gọi đúng contact theo priority, không gọi lại contact[0] |
| Auth test | Token Firebase hợp lệ / hết hạn / sai → 200/401 đúng |

---

## 14. Deployment

1. Tạo project Supabase → chạy schema ở mục 2 (SQL editor).
2. Tạo Firebase project → tải `firebase-service-account.json`.
3. Deploy FastAPI lên **Render** hoặc **Railway**, set env var ở mục 11.
4. Mobile app trỏ `API_BASE_URL` về domain backend đã deploy.
5. Feature flag: bật AI detection từng camera một (chạy staging 48h trước production).

---

## 15. Tóm tắt các thay đổi so với V0

| # | Vấn đề | Fix |
|---|---|---|
| 1 | Nhiều camera detect cùng 1 vụ ngã → duplicate push | Dedup check ở app layer trong `alert_engine.process()`, window config per-household qua `thresholds.dedup_window_sec` |
| 2 | `contacts.user_id` không có ON DELETE rule | `ON DELETE SET NULL` — giữ lại contact slot khi user bị xóa |
| 3 | `escalations.contact_id` không có ON DELETE rule | `ON DELETE SET NULL` — giữ log audit khi contact bị xóa |
| 4 | Thiếu CHECK constraint cho các enum TEXT | Thêm CHECK vào `users.role`, `cameras.status`, `events.severity`, `events.status`, `alert_reviews.action`, `escalations.channel`, `escalations.status` |
| 5 | Thiếu index cho `alert_reviews` và `escalations` | `idx_alert_reviews_event_id`, `idx_escalations_event_id` |
| 6 | Full scan cho escalation check job mỗi phút | Partial index `idx_events_escalate_after WHERE status='pending' AND escalate_after IS NOT NULL` |
| 7 | `run_escalation` không guard khi chỉ có 1 contact | Thêm `if len(contacts) < 2: return` trước khi escalate |
