# 🗺️ Project Map — SilentGuard AI

> **Team 128** · Mentor: Công Nguyễn · AI20K Build Cohort 2

---

## Tổng quan dự án

| Thông tin | Chi tiết |
|---|---|
| **Tên dự án** | SilentGuard AI |
| **Mục tiêu** | Phát hiện té ngã thụ động cho người cao tuổi, alert gia đình < 60 giây |
| **Tech Stack** | Python · YOLOv8-Pose · FastAPI · Supabase · Firebase · Claude |
| **Thời gian** | 6 tuần · 4 Sprint |
| **Repo** | https://github.com/AI20K-Build-Cohort-2/C2-App-128 |
| **Stakeholder** | Gia đình người cao tuổi sống một mình |

---

## Cây thư mục

```
team-128/
│
├── 📄 README.md                    ← Giới thiệu dự án, quick start, roadmap
├── 📄 ARCHITECTURE.md              ← Kiến trúc 3 lớp, DB schema, API contract, sequence diagram
├── 📄 PROJECT_MAP.md               ← File này — bản đồ thư mục & phân công
│
├── 📁 src/                         ← ✅ BACKEND CHÍNH của SilentGuard AI (FastAPI)
│   │                                  (thay thế toàn bộ boilerplate cũ từ Sprint 2 trở đi)
│   │
│   ├── 📁 edge/                    ← AI Engineer: Edge pipeline chạy trên Raspberry Pi / NUC
│   │   ├── run_edge.py             ← Entry point — khởi động camera + inference loop
│   │   ├── capture.py              ← Kết nối RTSP, pull frame 15 FPS (OpenCV/GStreamer)
│   │   ├── pose_detector.py        ← YOLOv8-Pose: load model, inference, trả keypoints
│   │   ├── fall_classifier.py      ← Rule-based: phân tích keypoints → phát hiện té ngã
│   │   ├── severity_engine.py      ← Duration timer → phân loại LOW/MEDIUM/HIGH/CRITICAL
│   │   ├── anonymizer.py           ← Blur mặt (OpenCV) + encode clip H.264 10 giây
│   │   ├── event_sender.py         ← POST /api/events/detect lên Backend (httpx async)
│   │   ├── offline_queue.py        ← Queue local khi mất kết nối, gửi lại khi online
│   │   ├── requirements-edge.txt   ← ultralytics, opencv-python, httpx, ...
│   │   └── .env.edge.example       ← Biến môi trường edge (BACKEND_URL, DEVICE_API_KEY)
│   │
│   ├── 📁 api/                     ← Backend Engineer: FastAPI routes & business logic
│   │   ├── __init__.py
│   │   ├── routes/
│   │   │   ├── events.py           ← POST /detect · GET / · GET /{id} · PATCH /{id}/review
│   │   │   ├── devices.py          ← GET /devices · POST /devices · PUT /devices/{id}
│   │   │   ├── users.py            ← POST /users/fcm-token · GET /users/me
│   │   │   └── reports.py          ← GET /reports/daily (Claude LLM)
│   │   ├── models/
│   │   │   ├── event.py            ← Pydantic schema: EventCreate, EventResponse, ReviewRequest
│   │   │   ├── device.py           ← Pydantic schema: DeviceCreate, DeviceStatus
│   │   │   └── user.py             ← Pydantic schema: UserProfile, FCMTokenRequest
│   │   ├── dependencies.py         ← Firebase ID Token verification (FastAPI Depends)
│   │   └── middleware.py           ← CORS, logging, error handler
│   │
│   ├── 📁 alert/                   ← Backend Engineer: Alert Engine + Push + Auto-call
│   │   ├── engine.py               ← Orchestrator: nhận event → quyết định action theo severity
│   │   ├── fcm_sender.py           ← Firebase Admin SDK: gửi FCM push notification
│   │   ├── auto_call.py            ← Auto-call logic: gọi điện khi HIGH/CRITICAL
│   │   └── escalation.py           ← CRITICAL: gọi tất cả emergency contacts liên tục
│   │
│   ├── 📁 llm/                     ← Backend Engineer: Claude integration
│   │   ├── alert_message.py        ← Sinh alert message tự nhiên từ {severity, duration, location}
│   │   ├── daily_report.py         ← Tổng hợp sự kiện ngày → báo cáo cho gia đình
│   │   └── config_parser.py        ← Parse cấu hình ngôn ngữ tự nhiên → threshold JSON
│   │
│   ├── 📁 db/                      ← Backend Engineer: Supabase client & queries
│   │   ├── client.py               ← Khởi tạo Supabase Python client
│   │   ├── events_repo.py          ← CRUD cho bảng events
│   │   ├── reviews_repo.py         ← CRUD cho bảng alert_reviews
│   │   └── devices_repo.py         ← CRUD cho bảng devices
│   │
│   ├── config.py                   ← Pydantic Settings: đọc .env, validate
│   ├── main.py                     ← FastAPI app entry point, include routers
│   ├── requirements.txt            ← fastapi, uvicorn, supabase, firebase-admin, anthropic, ...
│   └── .env.example                ← Template biến môi trường backend
│
├── 📁 frontend/                    ← ⚠️ PROTOTYPE CŨ (VinBus SafeWatch) — KHÔNG DÙNG CHO SILENTGUARD
│   │                                  Next.js UI prototype từ giai đoạn VinBus.
│   │                                  Giữ lại để tham khảo component/style, không deploy.
│   │                                  SilentGuard production dùng Mobile App (iOS/Android) thay thế.
│   ├── app/
│   ├── components/
│   ├── package.json
│   └── ...
│
├── 📁 backend/                     ← ⚠️ PROTOTYPE CŨ (VinBus SafeWatch) — KHÔNG DÙNG CHO SILENTGUARD
│   │                                  Node.js/Fastify backend từ giai đoạn VinBus.
│   │                                  Không tích hợp YOLOv8, Supabase, Firebase theo design SilentGuard.
│   │                                  Backend thật của SilentGuard là src/ (FastAPI Python).
│   ├── src/
│   ├── package.json
│   └── ...
│
├── 📁 docs/                        ← Tài liệu kỹ thuật chi tiết
│   ├── api_contract.md             ← API spec đầy đủ (request/response schema)
│   ├── edge_setup.md               ← Hướng dẫn cài đặt Raspberry Pi + camera RTSP
│   ├── model_card.md               ← YOLOv8-Pose model card: dataset, metrics, limitations
│   ├── privacy_policy.md           ← Chính sách quyền riêng tư chi tiết cho user
│   └── sprint_notes/               ← Ghi chú từng sprint
│       ├── sprint1.md
│       ├── sprint2.md
│       └── ...
│
├── 📁 scripts/                     ← Scripts tiện ích cho team
│   ├── setup_dev.sh                ← Cài đặt môi trường dev local (venv, deps, .env)
│   ├── migrate_db.py               ← Chạy SQL migration lên Supabase
│   ├── gen_device_key.py           ← Tạo API key cho edge device mới
│   └── eval_model.py               ← Đánh giá model nhanh trên test video
│
├── 📁 tests/                       ← Test suite (AI Engineer + Backend Engineer)
│   ├── 📁 unit/
│   │   ├── test_fall_classifier.py ← Unit test Fall Classifier (keypoint scenarios)
│   │   ├── test_severity_engine.py ← Unit test Severity Engine (duration logic)
│   │   └── test_alert_engine.py    ← Unit test Alert Engine (mức severity → action)
│   ├── 📁 integration/
│   │   ├── test_events_api.py      ← Integration test POST /detect, GET /events
│   │   └── test_review_api.py      ← Integration test PATCH /review
│   └── conftest.py                 ← pytest fixtures (mock Supabase, mock Firebase)
│
├── 📁 eval/                        ← Đánh giá model AI (AI Engineer)
│   ├── 📁 videos/                  ← Video test (đã ẩn danh) — không commit lên git
│   ├── 📁 annotations/             ← Ground truth labels (JSON)
│   ├── run_eval.py                 ← Chạy evaluation: precision, recall, F1
│   ├── confusion_matrix.py         ← Sinh confusion matrix
│   └── results/                    ← Kết quả eval (CSV + plots)
│
└── Makefile                        ← Lệnh thường dùng (xem phần "Lệnh thường dùng")
```

---

## Lưu ý quan trọng về cấu trúc

> ⚠️ **`frontend/` và `backend/`** là code từ dự án VinBus SafeWatch (trước SilentGuard). Hai thư mục này **không được dùng** cho SilentGuard production. Giữ lại chỉ để tham khảo và không xóa để tránh conflict git history của cả cohort.

> ✅ **`src/`** là nơi duy nhất chứa code production của SilentGuard AI (FastAPI backend + edge pipeline).

---

## Bảng phân công theo thư mục

| Thư mục / File | AI Engineer | Backend Engineer | Frontend/Mobile |
|---|:---:|:---:|:---:|
| `src/edge/` | ✅ Chủ lực | — | — |
| `src/api/` | — | ✅ Chủ lực | — |
| `src/alert/` | — | ✅ Chủ lực | — |
| `src/llm/` | — | ✅ Chủ lực | — |
| `src/db/` | — | ✅ Chủ lực | — |
| `tests/unit/test_fall_classifier.py` | ✅ | — | — |
| `tests/unit/test_severity_engine.py` | ✅ | — | — |
| `tests/unit/test_alert_engine.py` | — | ✅ | — |
| `tests/integration/` | hỗ trợ | ✅ Chủ lực | — |
| `eval/` | ✅ Chủ lực | — | — |
| `docs/model_card.md` | ✅ | — | — |
| `docs/api_contract.md` | — | ✅ | — |
| `docs/edge_setup.md` | ✅ | — | — |
| Mobile App (repo riêng) | — | hỗ trợ API | ✅ Chủ lực |
| `scripts/` | hỗ trợ | ✅ Chủ lực | — |

---

## Workflow phát triển

### Thứ tự ưu tiên (Sprint 2)

```
1. [AI Engineer]   src/edge/pose_detector.py     ← YOLOv8-Pose load + inference
2. [AI Engineer]   src/edge/fall_classifier.py   ← Rule-based fall detection
3. [Backend]       src/main.py + src/api/         ← FastAPI boilerplate + route skeleton
4. [Backend]       src/db/                        ← Supabase client + events_repo
5. [AI Engineer]   src/edge/anonymizer.py         ← Face blur + encode clip
6. [AI Engineer]   src/edge/event_sender.py       ← POST event lên backend
7. [Backend]       src/alert/engine.py            ← Alert Engine logic
8. [Backend]       src/alert/fcm_sender.py        ← Firebase FCM push
9. [Frontend]      Mobile wireframe → Firebase Auth → FCM token registration
10. [All]          tests/ — viết test song song với code
```

### Git workflow

```bash
# Mỗi tính năng → 1 branch
git checkout -b feat/edge-fall-classifier

# Commit thường xuyên
git commit -m "feat(edge): add rule-based fall classifier using hip-knee angle"

# PR vào main khi done + có test pass
# Mentor review trước khi merge
```

---

## Biến môi trường

### Backend (`src/.env`)

```env
# Supabase
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Firebase Admin
FIREBASE_PROJECT_ID=silentguard-ai
FIREBASE_PRIVATE_KEY_ID=xxxx
FIREBASE_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n..."
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@silentguard-ai.iam.gserviceaccount.com

# Claude (Anthropic)
ANTHROPIC_API_KEY=sk-ant-...

# App config
ENVIRONMENT=development          # development | production
ALERT_CLIP_RETENTION_DAYS=30    # Số ngày giữ clip trên Supabase Storage
```

### Edge Device (`src/edge/.env.edge`)

```env
# Backend
BACKEND_URL=https://silentguard-api.render.com
DEVICE_API_KEY=sg_dev_xxxx       # Lấy từ script gen_device_key.py

# Camera
RTSP_URL=rtsp://192.168.1.100:554/stream
CAMERA_FPS=15
CAMERA_RESOLUTION=1280x720

# Model
YOLO_MODEL_PATH=./models/yolov8n-pose.pt
CONFIDENCE_THRESHOLD=0.6

# Severity thresholds (giây)
SEVERITY_LOW_MAX=30
SEVERITY_MEDIUM_MAX=120
SEVERITY_HIGH_MAX=300
```

---

## Lệnh thường dùng (Makefile)

```makefile
# Cài đặt môi trường
make setup          # Tạo venv, cài deps, copy .env.example → .env

# Development
make run            # Chạy FastAPI backend (uvicorn --reload, port 8000)
make run-edge       # Chạy edge pipeline (cần camera RTSP)
make docs           # Mở Swagger UI (http://localhost:8000/docs)

# Testing
make test           # Chạy toàn bộ test suite (pytest)
make test-unit      # Chỉ unit tests
make test-int       # Chỉ integration tests
make coverage       # pytest + coverage report

# Model evaluation
make eval           # Chạy eval trên video test set
make eval-report    # Sinh confusion matrix + metrics CSV

# Database
make migrate        # Chạy SQL migration lên Supabase
make gen-device-key # Tạo API key cho edge device mới

# Code quality
make lint           # ruff check src/ tests/
make format         # ruff format src/ tests/
make typecheck      # mypy src/
```

---

> 📄 Xem thêm: [README.md](./README.md) · [ARCHITECTURE.md](./ARCHITECTURE.md)
