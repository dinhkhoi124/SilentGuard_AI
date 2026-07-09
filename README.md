# 🤖 AI20K Agent Template

Template chính thức cho học viên **VinUni AI20K Build Phase** — cung cấp sẵn cấu trúc dự án, code mẫu, và hướng dẫn kỹ thuật chi tiết để xây dựng AI Agent đạt điểm cao (35+/50).

> 📖 **Technical Guidebook:** [phoenix.note.transformerlabs.ai/technical-book](https://phoenix.note.transformerlabs.ai/technical-book)

## 🎯 Template này dùng để làm gì?

Khi tham gia AI20K Build Phase, mỗi đội cần xây dựng một AI Agent hoàn chỉnh — từ kiến trúc, code, test, đến deploy. Thay vì bắt đầu từ con số không, template này cung cấp:

- **Cấu trúc thư mục chuẩn** — đã được thiết kế theo best practices (separation of concerns)
- **Code mẫu** cho các phần cốt lõi: LangGraph agent, FastAPI API, config, schemas
- **Docker + CI/CD sẵn** — Dockerfile multi-stage, GitHub Actions workflow
- **Hướng dẫn kỹ thuật 10 chương** — từ clone template đến nộp bài Demo Day
- **Checklist 10 deliverables** — đảm bảo không bỏ sót yêu cầu BTC
- **AI Usage Logging tự động** — Pre-configured hooks cho Claude Code, Cursor, Codex, Gemini CLI, Antigravity, và GitHub Copilot

## ⚡ Quick Start

<<<<<<< Updated upstream
### Bước 1: Fork hoặc Clone
=======
## 🔴 Vấn đề

Người cao tuổi sống một mình đang đối mặt với rủi ro nghiêm trọng:

- **8–24 giờ** trung bình trôi qua trước khi gia đình phát hiện ra người thân bị ngã tại nhà.
- **Wearable (vòng tay, đồng hồ)** yêu cầu đeo thường xuyên và sạc pin — tỷ lệ tuân thủ rất thấp ở nhóm 70+.
- **Gia đình không có tín hiệu cảnh báo** cho đến khi gọi điện không ai bắt máy.
- **Hậu quả y tế:** Nằm dưới sàn > 1 giờ sau ngã dẫn đến tổn thương thứ phát (mất nước, hạ thân nhiệt, hoại tử cơ).

---

## ✅ Giải pháp

- 📷 **Passive monitoring** — camera IP/RTSP sẵn có, không cần thiết bị đeo thêm.
- 🤖 **AI edge inference** — YOLOv8-Pose chạy trực tiếp trên Raspberry Pi / NUC, phát hiện té ngã theo keypoint.
- ⚡ **Alert < 60 giây** — từ lúc ngã đến khi push notification đến điện thoại gia đình.
- 🔒 **Privacy-first** — raw video chỉ tồn tại trong RAM edge device; clip gửi cloud đã blur mặt + encode.
- 📊 **Severity 4 mức** — phân loại tự động để tránh cảnh báo ảo và ưu tiên đúng ca khẩn.

---

## 🏗️ Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────────┐
│                   EDGE DEVICE                       │
│                                                     │
│  [Camera IP/HLS] → Video 15 FPS                     │
│         ↓                                           │
│  YOLOv8-Pose → Skeleton Keypoints                   │
│         ↓                                           │
│  Fall Classifier (rule-based, < 50ms)               │
│         ↓                                           │
│  Severity Engine (duration timer)                   │
│         ↓                                           │
│  Anonymization: blur mặt + encode clip 10s          │
│         ↓                                           │
│  POST /api/events/detect (metadata + clip đã blur)  │
└───────────────────────┬─────────────────────────────┘
                        │ HTTPS (chỉ metadata + clip blur)
                        ↓
┌─────────────────────────────────────────────────────┐
│               BACKEND API                           │
│           (FastAPI + Supabase)                      │
│                                                     │
│  Event Processing → Severity double-check           │
│         ↓                                           │
│  Alert Engine                                       │
│         ↓                                           │
│  Firebase Admin SDK → FCM Push + Auto-call logic    │
│         ↓                                           │
│  Supabase Storage (lưu clip đã blur)                │
│  Supabase PostgreSQL (event log, review)            │
└───────────────────────┬─────────────────────────────┘
                        │ FCM Push / WebSocket
                        ↓
┌─────────────────────────────────────────────────────┐
│               MOBILE APP                            │
│           (iOS / Android — Firebase)                │
│                                                     │
│  Firebase Auth → đăng nhập gia đình                 │
│  FCM → nhận push notification                       │
│  Alert List → Alert Detail (clip + severity)        │
│  Confirm / Dismiss → learning signal                │
└─────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

| Lớp | Công nghệ | Mục đích |
|---|---|---|
| **Edge AI** | Python + YOLOv8-Pose + OpenCV + LightGBM model | Phát hiện tư thế, phân loại té ngã |
| **Edge Runtime** | Raspberry Pi 4B / Intel NUC | Chạy inference tại chỗ |
| **Backend API** | FastAPI (Python) | REST API xử lý event, alert engine |
| **Database** | Supabase (PostgreSQL) | Lưu event log, review, device info |
| **File Storage** | Supabase Storage | Clip đã blur (≤ 10 giây) |
| **Auth** | Firebase Authentication | Đăng nhập gia đình / caregiver |
| **Push** | Firebase Cloud Messaging (FCM) | Notification iOS + Android |
| **LLM** | OPENAI | Alert message, báo cáo ngày, config parser |
| **Mobile** | Firebase SDK (iOS/Android) | Ứng dụng di động gia đình |
| **Deploy** | Render / Railway | Host backend API |

---

## 🚨 Phân loại mức độ (Severity)

| Mức | Điều kiện | Hành động |
|---|---|---|
| **LOW** | Tự đứng dậy trong < 30 giây | Chỉ ghi log, không thông báo |
| **MEDIUM** | Bất động 30 giây – 2 phút | Push notification đến gia đình |
| **HIGH** | Bất động > 2 phút | Push notification + tự động gọi điện |
| **CRITICAL** | Bất động > 5 phút, không có phản hồi | Alert toàn bộ danh bạ khẩn + gọi liên tục |

---

## 🔒 Privacy Guardrail

> **Nguyên tắc bất biến:** Raw video không bao giờ rời khỏi edge device.

```
Camera → RAM (edge) → YOLOv8 keypoints extraction 
                   → LightGBM fall detection + severity estimation + FSM (Finite State Machine)                  
                   → Blur mặt (OpenCV face anonymization)
                   → Encode clip 10s (H.264, độ phân giải giảm)
                   → Chỉ clip đã blur + metadata được gửi lên cloud
```

- ❌ Không stream video lên server.
- ❌ Không lưu raw frame vào disk edge.
- ✅ Clip cloud chỉ chứa silhouette + tư thế, không nhận diện được danh tính.
- ✅ Clip tự động xóa sau 30 ngày (Supabase Storage lifecycle).

---

## 📊 Evaluation metrics

| Chỉ số | Mục tiêu |
|---|---|
| Alert Time (ngã → push) | < 60 giây |
| AI Precision | ≥ 72% |
| AI Recall | ≥ 94% |
| F1-Score | ≥ 82% |
| False Positive Rate | < 20% |
| Edge Device Uptime | ≥ 99% |
| Severity Accuracy | ≥ 90% |

---

## 👥 Thành viên & Phân công

| Vai trò | Phụ trách |
|---|---|
| **AI Engineer** | Fall Detection model (YOLOv8-Pose), Set Rule Base, Training LightGBM model, FSM, Severity Classifier edge, Privacy/blur pipeline, Clip capture |
| **Backend Engineer** | Firebase token verification, API `/events` + `/alerts` + `/review`, Alert Engine + Push + Auto-call, Dashboard API, LLM integration, Event Log, Learning Signal |
| **Frontend / Mobile** | Wireframe thiết kế, màn hình Home / Alert List / Alert Detail, Firebase Auth client, FCM token registration |

---

## 🚀 Hướng Dẫn Cấu Hình & Chạy Dự Án (Setup Instructions)

Dự án gồm hai phần chính chạy độc lập: **Backend API (FastAPI)** và **AI Server (Edge AI Pipeline Worker)**.

### 1. Backend API (FastAPI)
Nằm trong thư mục `backend/`.

#### Yêu cầu cài đặt:
- Python 3.11+
- Cơ sở dữ liệu Supabase đã tạo sẵn các bảng.
>>>>>>> Stashed changes

#### Biến môi trường (`backend/.env`):
Sao chép `.env.example` thành `.env` và cập nhật:
```ini
SUPABASE_URL=...
SUPABASE_SERVICE_KEY=...
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
AI_SERVER_URL=http://localhost:5000/process
ANTHROPIC_API_KEY=your_anthropic_api_key
APP_ENV=development
```

#### Cài đặt và Chạy:
```bash
<<<<<<< Updated upstream
# Clone template
git clone https://github.com/AI20K-Build-Cohort-2/starter-code-template.git team-YOUR_TEAM_NAME
cd team-YOUR_TEAM_NAME

# Xóa git history cũ và khởi tạo lại
rm -rf .git
git init
git add .
git commit -m "feat: khởi tạo dự án từ template"
=======
cd backend
# Cài đặt thư viện
pip install -r requirements.txt

# Khởi động server (Mặc định chạy ở cổng 8000)
uvicorn app.main:app --reload
```

---

### 2. AI Server (Edge AI Worker)
Nằm trong thư mục `src/edge_ai/`. Server này đóng vai trò như một Edge Worker giả lập nhận diện video.

#### Yêu cầu cài đặt:
- Cài đặt thư viện: `pip install ultralytics opencv-python numpy requests fastapi uvicorn`

#### Chạy AI Server (Mặc định chạy ở cổng 5000):
```bash
cd src/edge_ai
python ai_worker.py
```

---

## 🔍 Sample Queries (Các Lệnh Gọi Test)

Dưới đây là các lệnh gọi HTTP Request (`curl`) phục vụ việc kiểm thử luồng hoạt động tự động.

### 1. Tải Video Sự Kiện Lên (Demo Flow)
Gửi yêu cầu upload video ngắn lên hệ thống. Backend sẽ tự lưu trữ video và tự động trigger AI Server xử lý dưới nền.
```bash
curl -X POST "http://localhost:8000/api/events/upload-video" \
  -H "Authorization: Bearer <DÁN_FIREBASE_TOKEN_CỦA_USER>" \
  -F "household_id=9578af65-eea9-4769-9ba8-4b3818e2780a" \
  -F "file=@test_fall.mp4"
```

### 2. Phản Hồi Sự Kiện (Feedback API)
Gia đình gửi đánh giá độ chính xác của cảnh báo ngã (chỉ chấp nhận label: `correct`, `incorrect`, `uncertain`).
```bash
curl -X POST "http://localhost:8000/api/events/EVT-20260618-331/feedback" \
  -H "Authorization: Bearer <DÁN_FIREBASE_TOKEN_CỦA_USER>" \
  -H "Content-Type: application/json" \
  -d "{\"label\":\"correct\",\"note\":\"Cụ ngã thật, đã hỗ trợ kịp thời\"}"
```

### 3. Lấy Lịch Sự Kiện
Lấy toàn bộ danh sách sự cố đã xảy ra của hộ gia đình (phân trang và lọc theo phòng/mức độ nghiêm trọng).
```bash
curl "http://localhost:8000/api/events/history?household_id=9578af65-eea9-4769-9ba8-4b3818e2780a&page=1&page_size=10" \
  -H "Authorization: Bearer <DÁN_FIREBASE_TOKEN_CỦA_USER>"
>>>>>>> Stashed changes
```

### Bước 2: Setup môi trường

```bash
# Tạo virtual environment
python3.11 -m venv .venv
source .venv/bin/activate

<<<<<<< Updated upstream
# Cài dependencies
pip install -e ".[dev]"

# Cấu hình API keys
cp .env.example .env
# Mở .env và thêm OPENAI_API_KEY của bạn
# Đồng thời cập nhật AI_LOG_API_KEY bằng key riêng từ link mời của BTC
# (giá trị trong .env.example chỉ là placeholder)
=======
| Sprint | Tuần | Trạng thái | Mục tiêu chính |
|---|---|---|---|
| **Sprint 1** | W1–W2 | ✅ Hoàn thành | Thiết kế kiến trúc, wireframe, ERD, API contract |
| **Sprint 2** | W2–W3 | ✅ Hoàn thành | Core pipeline edge, API backend, Alert Engine, push notification |
| **Sprint 3** | W4 | 📋 Lên kế hoạch | Claude LLM integration, Dashboard, sửa lỗi từ Sprint 2 |
| **Sprint 4** | W5–W6 | 📋 Lên kế hoạch | Deploy production, threshold per-user, kiểm thử E2E |

---

## 📁 Cấu trúc thư mục

```
C2-App-128/
├── backend/              ← Mã nguồn FastAPI chính (routes, models, database)
├── src/
│   └── edge_ai/          ← Mô hình YOLOv8-Pose và AI worker backend trigger
├── docs/                 ← Tài liệu thiết kế API & hướng dẫn kết nối
├── mobile/               ← Ứng dụng di động Flutter
├── tests/                ← Bộ test của hệ thống
└── README.md             ← File này
>>>>>>> Stashed changes
```

### Bước 3: Cài AI Logging Hooks

<<<<<<< Updated upstream
```bash
# Linux / macOS / Git Bash
bash scripts/setup_hooks.sh

# Windows PowerShell
# powershell -ExecutionPolicy Bypass -File scripts\setup_hooks.ps1
```

Hooks tự động log mọi AI prompt khi dùng Claude Code, Cursor, Codex, Gemini CLI, Antigravity, hoặc GitHub Copilot. Không cần thao tác thủ công.

### Bước 4: Chạy server

```bash
# Chạy FastAPI backend
uvicorn src.main:app --reload --port 8000

# Mở Swagger UI
# http://localhost:8000/docs
```

### Bước 5: Đọc hướng dẫn

📖 Mở **[Technical Guidebook](https://phoenix.note.transformerlabs.ai/technical-book)** và làm theo từng chương.

## 📁 Cấu trúc dự án

```
├── src/
│   ├── agents/           # 🧠 LangGraph Agent
│   │   ├── graph.py      #    State graph (nodes + edges)
│   │   ├── state.py      #    State schema (TypedDict)
│   │   ├── nodes/        #    Node functions
│   │   └── tools/        #    Agent tools (@tool)
│   ├── api/              # 🌐 FastAPI Backend
│   │   └── routes.py     #    API endpoints
│   ├── models/           # 📋 Pydantic schemas
│   ├── services/         # 🔧 Business logic (LLM, etc.)
│   ├── config.py         # ⚙️ Pydantic Settings
│   └── main.py           # 🚀 App entry point
├── tests/                # 🧪 pytest suite
│   ├── test_agents/      #    Agent/graph tests
│   └── test_api/         #    API endpoint tests
├── scripts/              # 🔌 AI Logging Hooks
│   ├── log_hook.py       #    Auto-log cho Claude/Cursor/Codex/Gemini/Copilot
│   ├── log_antigravity.py#    Antigravity IDE prompt scanner
│   ├── log_manual.py     #    Manual log cho ChatGPT / web tools
│   ├── submit_log.py     #    Submit logs on git push
│   └── setup_hooks.sh    #    One-time hook installer
├── .claude/ .codex/ .cursor/ .gemini/  # Per-tool hook configs
├── .agents/              # Antigravity rules + workflows
├── .ai-log/              # 📊 AI usage logs (auto-generated)
├── docs/
│   ├── guide/            # 📖 Technical Guidebook (10 chapters)
│   └── architecture_diagram.md
├── eval/                 # 📊 Evaluation results
├── presentation/         # 🎤 Demo Day slides
├── .github/workflows/    # ⚡ CI/CD (GitHub Actions)
├── .github/hooks/        # 🪝 Copilot hook config
├── Dockerfile            # 🐳 Multi-stage build
├── docker-compose.yml    # 🐙 Full stack orchestration
└── README_boilerplate.md # 📝 README template cho đội của bạn
```

## 📚 Technical Guidebook — 10 Chương

| Chương | Nội dung | Thời gian |
|---------|----------|-----------|
| 1 | Lời mở đầu — Mục tiêu, cách sử dụng | 15 phút |
| 2 | Khởi tạo dự án — Clone, setup, git workflow | 4 giờ |
| 3 | Thiết kế kiến trúc — 3-tier, diagrams, ADR | 6 giờ |
| 4 | **LangGraph Agent** — State, nodes, edges, tools, RAG | 8 giờ |
| 5 | FastAPI — Routes, validation, error handling, streaming | 6 giờ |
| 6 | Giao diện — Next.js + Streamlit quickstart | 6 giờ |
| 7 | DevOps — Docker, CI/CD, deploy, logging | 6 giờ |
| 8 | Kiểm thử — Unit test, integration test, RAGAS | 4 giờ |
| 9 | Demo Day — 10 deliverables, checklist, tips | 2 giờ |
| 10 | Tài nguyên — Khóa học, docs, BMAD method | tham khảo |

📖 **Đọc online:** [phoenix.note.transformerlabs.ai/technical-book](https://phoenix.note.transformerlabs.ai/technical-book)

## 📋 10 Deliverables cho Demo Day

| # | Deliverable | File vị trí | Template có sẵn |
|---|-------------|-------------|:---:|
| 1 | Source Code | `src/` | ✅ |
| 2 | README.md | `README_boilerplate.md` → copy thành `README.md` | ✅ |
| 3 | Architecture Diagram | `docs/architecture_diagram.md` | ✅ |
| 4 | AI Logs | LangSmith (3 env vars) + Auto AI Usage Logging | ✅ |
| 5 | Live URL | Deploy lên Render/Vercel | ⚡ CI/CD sẵn |
| 6 | Video Demo | `presentation/` | 📝 |
| 7 | Pitch Deck | `presentation/` | 📝 |
| 8 | Development Journal | `JOURNAL.md` | ✅ |
| 9 | Worklog | `WORKLOG.md` | ✅ |
| 10 | Evaluation Evidence | `eval/` | 📝 |

## 🛠 Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| AI Agent | LangGraph + LangChain | Latest |
| Backend | FastAPI + Uvicorn | 0.100+ |
| LLM | OpenAI GPT-4o-mini | API |
| Frontend | Next.js / Streamlit | 14+ / 1.30+ |
| Database | SQLite (dev) / PostgreSQL (prod) | — |
| DevOps | Docker + GitHub Actions | — |
| Testing | pytest + pytest-asyncio | 8+ |

## 📊 AI Usage Logging

Template đã tích hợp sẵn auto-logging hooks cho 6 AI tools:

| Tool | Cơ chế | Config |
|------|--------|--------|
| Claude Code | `.claude/settings.json` hooks | Tự động |
| Cursor | `.cursor/hooks.json` | Tự động |
| OpenAI Codex CLI | `.codex/hooks.json` | Tự động |
| Gemini CLI | `.gemini/settings.json` | Tự động |
| GitHub Copilot | `.github/hooks/hooks.json` | Tự động |
| Antigravity IDE | Pre-push scan transcript | Tự động trên `git push` |

Tất cả prompts và tool calls được log vào `.ai-log/session.jsonl` và tự động submit lên grading server mỗi khi `git push`.

**ChatGPT / web tools khác** — log thủ công:
```bash
bash scripts/_pyrun.sh scripts/log_manual.py --tool chatgpt --prompt "What you asked"
```

> ⚠️ Chạy `bash scripts/setup_hooks.sh` một lần sau khi clone để cài pre-push hook.

## 📖 Đọc Technical Guidebook

**Online (khuyến nghị):** [phoenix.note.transformerlabs.ai/technical-book](https://phoenix.note.transformerlabs.ai/technical-book)

Đăng nhập bằng GitHub (cùng account đã được BTC mời vào org `AI20K-Build-Cohort-2`)
→ chọn tab **Technical Book** ở sidebar trái → đọc 10 chương + topic sections,
có table of contents bên phải, hỗ trợ light/dark/cyberpunk theme.

**Offline:** mọi chương đều ở thư mục `docs/guide/` trong template này — mở bằng
bất kỳ markdown viewer/editor nào (VS Code, Obsidian, GitHub UI, …).

## 🔗 Liên kết

- 📖 **Technical Guidebook:** [phoenix.note.transformerlabs.ai/technical-book](https://phoenix.note.transformerlabs.ai/technical-book)
- 🏫 **AI20K Program:** VinUni AI20K Build Phase
- 👨‍🏫 **Mentor:** Đặng Hải Lộc

## 📄 License

MIT — Sử dụng tự do cho mục đích giáo dục.
=======
> 📄 Xem thêm: [ARCHITECTURE.md](./ARCHITECTURE.md) · [PROJECT_MAP.md](./PROJECT_MAP.md)

>>>>>>> Stashed changes
