# Project Architecture Overview

Tài liệu này tổng hợp từ các branch nguồn:

```text
Backend       origin/feature/backend
AI            origin/feature/AI
Landing page  origin/landing_page
Mobile app    origin/feature/app-improvements
Flutter web   origin/feature/flutter-web
```

## Bản đồ thành phần

```text
SilentGuard
  backend/                 FastAPI backend chính
  src/edge/silentguard/    Edge AI worker V2
  src/ai_server.py         AI inference server cho upload/stream process
  mobile/                  Flutter app iOS/Android
  landing_page/            TanStack Start landing/demo/download site
  docs/                    Tài liệu kỹ thuật
```

## Luồng dữ liệu chính

```text
Camera/Imou stream
  -> Edge AI worker hoặc AI server
  -> detect fall/normal/error
  -> POST /api/events/detect lên backend
  -> backend lưu Supabase, tạo alert, push FCM, call/escalation
  -> Flutter app nhận notification và hiện dashboard/event detail
```

## Luồng livestream

Trên mobile native:

```text
Flutter app -> backend camera/stream endpoint -> Imou Cloud -> media_kit player
```

Trên Flutter web:

```text
Edge/AI publisher -> backend /api/streams/{camera_id}/publish
Flutter web -> WebSocket /api/streams/{camera_id}/subscribe
```

Backend branch có websocket router:

```text
WS /api/streams/{camera_id}/publish
WS /api/streams/{camera_id}/subscribe
```

## Luồng video upload

```text
Flutter app
  -> POST /api/events/upload-video
  -> backend tạo/liên kết upload token
  -> backend hoặc app trigger AI analysis
  -> AI server POST /analyze
  -> AI server queue FCFS
  -> src/edge/AI-Core/ver9.py
  -> POST kết quả về /api/events/detect với X-Upload-Token
```

## Thành phần và công nghệ

| Thành phần | Thư mục | Công nghệ | Branch nguồn |
|---|---|---|---|
| Backend API | `backend/app` | FastAPI, Supabase, Firebase Admin, APScheduler, Twilio, OpenAI package | `origin/feature/backend` |
| Legacy backend prototype | `backend/src` | Node/Fastify, Prisma, Socket.IO | `origin/feature/backend` |
| Edge AI worker | `src/edge/silentguard` | Python, Ultralytics YOLOv8 Pose, OpenCV, ByteTrack/lap, YAML | `origin/feature/AI` |
| AI inference server | `src/ai_server.py` | FastAPI, subprocess, FCFS queue | `origin/feature/AI` |
| Mobile app | `mobile` | Flutter, BLoC, go_router, get_it, Firebase, media_kit | `origin/feature/app-improvements` |
| Flutter web app | `mobile` | Flutter Web, nginx proxy, web push, websocket frames | `origin/feature/flutter-web` |
| Landing page | `landing_page` | TanStack Start, Vite, React, Three.js, Framer Motion, Tailwind | `origin/landing_page` |

## Backend API contract cần khớp với app/AI

AI cần:

```text
POST /api/events/detect
X-Device-Key hoặc X-Upload-Token tùy luồng
```

Mobile app cần:

```text
POST /api/users/login
POST /api/users/logout
POST /api/users/device-token
POST /api/users/switch-household
GET  /api/households/me
GET  /api/cameras
POST /api/cameras
DELETE /api/cameras/{camera_id}
GET  /api/events/history
GET  /api/reports/daily
POST /api/events/upload-video
PATCH /api/alerts/{event_id}/review
POST /api/events/{event_id}/feedback
```

Flutter web cần:

```text
WS /api/streams/{camera_id}/subscribe
```

Edge publisher cần:

```text
WS /api/streams/{camera_id}/publish
```

## Thứ tự merge khuyến nghị

Do các branch chồng lên nhau, nên merge theo nhóm và test sau mỗi nhóm:

1. `origin/feature/backend`
2. `origin/feature/AI`
3. `origin/feature/app-improvements`
4. `origin/feature/flutter-web`
5. `origin/landing_page`

Lý do:

- backend và AI tạo API/runtime core;
- app mobile cần contract backend;
- flutter-web sửa cùng `mobile/` với app chính nên nên merge sau app và resolve conflict có chủ đích;
- landing page tách thư mục `landing_page/`, ít ảnh hưởng core hơn.

## Các điểm cần xác minh sau merge

- `README.md` quick start phải trỏ đúng `backend/app/main.py`, không còn `cd src && uvicorn main:app`.
- `mobile/lib/core/config/app_config.dart` phải có config dùng cho cả native và web.
- `mobile/pubspec.yaml` phải giữ dependency của app chính và dependency web `web_socket_channel` nếu cần Flutter web.
- Backend `/api/streams` phải tồn tại nếu dùng Flutter web websocket player.
- AI edge worker cần `yolov8n-pose.pt` tồn tại tại path config hoặc override `MODEL_PATH`.
- Secrets như Imou app secret, Firebase service account, Supabase service key không nên commit thêm vào main.
