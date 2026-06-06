# Team C2-128 — VinBus SafeWatch AI

## Mô tả

Hệ thống AI hỗ trợ giám sát an toàn hành khách trên xe buýt thông qua camera ẩn danh.
Hệ thống thực hiện 3 chức năng cốt lõi:

1. **Phát hiện tự động** các sự cố an toàn (té ngã, xô xát) từ camera trên xe.
2. **Ẩn danh dữ liệu** hình ảnh để bảo vệ quyền riêng tư hành khách (không nhận diện danh tính).
3. **Cảnh báo thời gian thực** và cho phép con người xác minh trước khi xử lý.

> **Target user:** Nhân viên giám sát an toàn tại Trung tâm Điều hành VinBus — quản lý hàng chục đến hàng trăm xe cùng lúc, không thể theo dõi tất cả camera liên tục.

## Thành viên

- `Đoàn Công Phú` — `PM`
- `Vũ Quang Vinh` — `PO`
- `Đinh Văn Anh Khôi` — `Tech Lead`

## Quick Start

```bash
# [Điền lệnh khởi động thực tế của dự án]
python3.11 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env  # Điền API key
make run
```


## Kiến trúc

```
Camera (trên xe)
      │  RTSP / 4G
      ▼
Cloud Ingestion  →  Frame Extraction  →  AI Inference
                                               │
                                        Anonymization
                                        (Blur / Skeleton)
                                               │
                                         Alert Engine
                                               │
                                      Operator Dashboard
                                               │
                                    Confirm / Reject / Escalate
                                               │
                                        Driver Alert
```

> Chi tiết từng stage xem file `docs/AI_Pipeline_Spec.docx`

## Tech Stack

| Layer | Technology |
|---|---|
| AI / ML | `PyTorch, MediaPipe, YOLO` |
| Backend | `FastAPI, PostgreSQL, Redis` |
| Frontend | `React, TailwindCSS` |
| Infra / Deploy | `Docker, GCP, Nginx` |
| Message Queue | `Kafka, Redis Streams` |
| Storage | `GCS, S3` |

## Privacy Guardrail

Hệ thống **không được** phép:
- Nhận diện khuôn mặt
- Lưu danh tính hành khách
- Suy luận danh tính từ bất kỳ dữ liệu nào

Hệ thống **chỉ được** phép:
- Blur mặt và body trước khi lưu trữ
- Skeleton visualization
- Lưu clip sự kiện đã ẩn danh

> Raw frame (chưa blur) **không được ghi xuống disk**, chỉ tồn tại trong RAM trong quá trình inference.

## Success Metrics

| Metric | Target |
|---|---|
| Mean Time To Detect (MTTD) | < 30 giây |
| AI Precision | ≥ 85% |
| AI Recall | ≥ 80% |
| False Positive Rate | < 10% |
| Human Review Coverage | 100% alert phải được operator review |

## Cấu trúc thư mục

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
 
---
### 📄 License
MIT — Sử dụng tự do cho mục đích giáo dục.