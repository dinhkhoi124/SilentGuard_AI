# Backend Core Guide

Nguồn doc này được tổng hợp từ branch `origin/feature/backend`.

## Kết luận nhanh

Backend chuẩn của project là FastAPI app trong `backend/app`. Trong branch này vẫn có một backend Node/Fastify trong `backend/src`, nhưng README của branch gốc ghi rõ phần đó là prototype cũ. Khi merge và vận hành SilentGuard, ưu tiên FastAPI.

## Thư mục chính

```text
backend/
  app/
    main.py                 # FastAPI entrypoint
    api/                    # REST routers va WebSocket streams
    core/                   # config, security, Supabase client
    db/                     # query helper
    models/schemas.py       # Pydantic schemas
    services/               # alert, severity, notification, scheduler, LLM
  requirements.txt          # Python dependencies
  tests/                    # pytest suite
  src/                      # Node/Fastify prototype legacy
  prisma/schema.prisma      # schema cho prototype legacy
```

## Cách chạy local

Từ repository root:

```powershell
cd backend
copy .env.example .env
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health check:

```powershell
curl http://localhost:8000/health
```

FastAPI docs:

```text
http://localhost:8000/docs
```

## Cách chạy bằng Docker Compose

Branch có `docker-compose.yml` build từ `Dockerfile`, expose port `8000`, đọc env từ `.env`, mount `./data:/app/data`, và healthcheck `http://localhost:8000/health`.

```powershell
copy backend\.env.example .env
docker compose up --build
```

## Biến môi trường

`backend/.env.example` có:

```text
SUPABASE_URL
SUPABASE_SERVICE_KEY
FIREBASE_SERVICE_ACCOUNT_PATH
OPENAI_API_KEY
APP_ENV
```

`backend/app/core/config.py` còn đọc thêm:

```text
FIREBASE_SERVICE_ACCOUNT_JSON
CORS_ORIGINS
TWILIO_ACCOUNT_SID
TWILIO_AUTH_TOKEN
TWILIO_PHONE_NUMBER
TWILIO_FLOW_SID
```

## API routers thực tế

Entry point `backend/app/main.py` mount các router sau:

```text
GET  /health
GET  /

/api/events
  POST /api/events/upload-video
  GET  /api/events/upload-status/{upload_token}
  POST /api/events/request-upload-url
  POST /api/events/trigger-ai
  POST /api/events/detect
  PUT  /api/events/heartbeat/{event_id}

/api/cameras
  POST   /api/cameras
  GET    /api/cameras
  GET    /api/cameras/{camera_id}
  PATCH  /api/cameras/{camera_id}/rotate-key
  DELETE /api/cameras/{camera_id}
  PATCH  /api/cameras/{camera_id}
  POST   /api/cameras/upload-url
  POST   /api/cameras/{camera_id}/heartbeat

/api
  GET   /api/alerts
  PATCH /api/alerts/{event_id}/review
  GET   /api/events/history
  POST  /api/events/{event_id}/feedback
  GET   /api/events/{event_id}
  GET   /api/settings/thresholds
  PUT   /api/settings/thresholds
  GET   /api/contacts
  POST  /api/contacts
  PATCH /api/contacts/{contact_id}
  DELETE /api/contacts/{contact_id}
  POST  /api/llm/config

/api/dashboard
  GET /api/dashboard/summary

/api/users
  POST   /api/users/login
  POST   /api/users/logout
  POST   /api/users/device-token
  POST   /api/users/switch-household
  PATCH  /api/users/me/phone
  DELETE /api/users/me

/api/households
  POST  /api/households/invite-by-email
  POST  /api/households/invite
  GET   /api/households/invite-requests/pending
  POST  /api/households/invite-requests/{invite_id}/respond
  GET   /api/households/me
  POST  /api/households
  GET   /api/households
  GET   /api/households/{household_id}/members
  PATCH /api/households/{household_id}

/api/reports
  GET /api/reports/daily

/api/streams
  WS /api/streams/{camera_id}/publish
  WS /api/streams/{camera_id}/subscribe
```

## Core services

`backend/app/services/` gồm:

```text
alert_engine.py
call_service.py
llm_service.py
notification_service.py
scheduler.py
severity_engine.py
```

`backend/app/main.py` khởi tạo `AsyncIOScheduler` trong lifespan và chạy:

```text
periodic_check_job      # mỗi 1 phút
retry_critical_calls    # mỗi 2 phút
escalate_pending_events # mỗi 30 giây
```

## Model/schema quan trọng

`backend/app/models/schemas.py` định nghĩa các payload chính:

```text
EventDetectRequest
AlertItem
AlertListResponse
ReviewRequest
DashboardSummaryResponse
FCMTokenUpdateRequest
ThresholdUpdate
LLMConfigRequest
HouseholdCreateRequest
SwitchHouseholdRequest
FeedbackRequest
InviteByEmailRequest
RespondInviteRequest
```

Payload test cho `/api/events/detect` có dạng:

```json
{
  "event_id": "EVT-20260616-001",
  "event_type": "fall",
  "severity": "HIGH",
  "confidence": 0.89,
  "timestamp": "2026-06-16T02:15:10Z",
  "duration_sec": 145,
  "room": "bedroom",
  "clip_path": "clips/household-uuid/EVT-20260616-001_blur.mp4",
  "model_ver": "v1.0.0"
}
```

Endpoint này được test với header:

```text
X-Device-Key: sg_dev_bedroom_001
```

## Test

Branch có pytest trong `backend/tests/`.

```powershell
cd backend
pytest
```

Nếu import `app` lỗi, chạy với `PYTHONPATH` trỏ vào thư mục `backend`:

```powershell
$env:PYTHONPATH=(Get-Location).Path
pytest
```

## Lưu ý khi merge

- FastAPI trong `backend/app` là backend chính.
- Node/Fastify trong `backend/src` và Prisma schema có thể còn phục vụ prototype cũ; không nên đưa vào đó làm backend chính nếu không có yêu cầu riêng.
- `README.md` cũ của branch có phần quick start không khớp với cấu trúc FastAPI hiện tại (`cd src`, `uvicorn main:app`). Hướng dẫn đúng nên là `cd backend`, `uvicorn app.main:app`.
