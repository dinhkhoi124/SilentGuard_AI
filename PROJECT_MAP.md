# 🗺️ PROJECT MAP — Team C2-128 · VinBus SafeWatch AI

> Tài liệu này mô tả **từng thư mục / file làm việc gì** trong dự án.
> Đọc file này trước khi chỉnh sửa bất kỳ phần nào của codebase.

---

## 🏗️ Tổng quan dự án

| Thông tin | Chi tiết |
|---|---|
| **Tên dự án** | VinBus SafeWatch AI |
| **Mục tiêu** | Hệ thống AI giám sát an toàn hành khách trên xe buýt qua camera ẩn danh |
| **3 chức năng cốt lõi** | Phát hiện sự cố (té ngã / xô xát) · Ẩn danh hình ảnh · Cảnh báo thời gian thực |
| **Người dùng mục tiêu** | Nhân viên giám sát an toàn tại Trung tâm Điều hành VinBus |
| **Tech Stack chính** | FastAPI · LangGraph · OpenAI · Python 3.11 · Docker |
| **Thành viên** | Đoàn Công Phú (PM) · Vũ Quang Vinh (PO) · Đinh Văn Anh Khôi (Tech Lead) |

---

## 📁 Cấu trúc thư mục đầy đủ

```
team-128/
├── src/                        ← 🧠 Toàn bộ source code chính
│   ├── main.py                 ← Entry point khởi động app
│   ├── config.py               ← Cấu hình môi trường (env vars)
│   ├── agents/                 ← LangGraph AI Agent
│   │   ├── graph.py            ← Định nghĩa state graph (nodes + edges)
│   │   ├── state.py            ← Schema trạng thái agent (TypedDict)
│   │   ├── nodes/              ← Các node xử lý trong graph
│   │   │   └── example_node.py ← Node phân tích và tạo response
│   │   └── tools/              ← Công cụ agent có thể gọi
│   │       └── example_tool.py ← Tool tìm kiếm & tính toán
│   ├── api/                    ← FastAPI backend
│   │   └── routes.py           ← Định nghĩa API endpoints
│   ├── models/                 ← Pydantic data schemas
│   │   └── schemas.py          ← ChatRequest / ChatResponse models
│   └── services/               ← Business logic & integrations
│       └── llm.py              ← Khởi tạo LLM (OpenAI ChatGPT)
│
├── tests/                      ← 🧪 Toàn bộ test suite (pytest)
│   ├── conftest.py             ← Fixtures dùng chung cho toàn bộ tests
│   ├── test_agents/            ← Test cho LangGraph agent & graph
│   │   └── test_graph.py       ← Test luồng graph, node, conditional edges
│   └── test_api/               ← Test cho API endpoints
│       └── test_routes.py      ← Test /chat, /status, /health
│
├── docs/                       ← 📚 Tài liệu kỹ thuật
│   ├── architecture_diagram.md ← Sơ đồ kiến trúc hệ thống (Mermaid)
│   ├── project_summary_report.md ← PRD đầy đủ: user stories, API, RBAC, wireframe
│   └── guide/                  ← 📖 Guidebook kỹ thuật 10 chương
│       ├── chapter-01.md → chapter-10.md  ← Hướng dẫn chi tiết từng phần
│       ├── architecture/       ← Tài liệu về kiến trúc hệ thống
│       ├── langgraph/          ← Hướng dẫn dùng LangGraph
│       ├── patterns/           ← Design patterns được dùng
│       ├── anti-patterns/      ← Những thứ cần tránh
│       ├── testing/            ← Hướng dẫn viết test
│       ├── devops/             ← CI/CD, Docker, deploy
│       ├── setup/              ← Cài đặt môi trường
│       ├── code-style/         ← Coding conventions
│       ├── bmad/               ← BMAD methodology docs
│       ├── deliverables/       ← Yêu cầu bàn giao
│       ├── resources/          ← Tài nguyên tham khảo
│       ├── book-media/         ← Media cho tài liệu
│       ├── cost-management.md  ← Quản lý chi phí API / cloud
│       ├── free-accounts.md    ← Danh sách tài khoản miễn phí
│       └── troubleshooting.md  ← Xử lý lỗi thường gặp
│
├── scripts/                    ← 🔌 Script tiện ích & AI logging
│   ├── log_hook.py             ← Auto-log AI usage (Claude/Cursor/Codex/Gemini)
│   ├── log_antigravity.py      ← Scan prompt từ Antigravity IDE
│   ├── log_manual.py           ← Manual log cho ChatGPT / web tools
│   ├── submit_log.py           ← Submit logs khi git push
│   ├── setup.sh                ← Script cài đặt môi trường lần đầu
│   ├── setup_hooks.sh          ← Cài git hooks (Linux/macOS)
│   ├── setup_hooks.ps1         ← Cài git hooks (Windows PowerShell)
│   ├── _pyrun.sh               ← Wrapper chạy Python (Unix)
│   └── _pyrun.cmd              ← Wrapper chạy Python (Windows)
│
├── eval/                       ← 📊 Đánh giá & benchmark AI
│   └── results/
│       └── report.md           ← Kết quả đánh giá model (precision, recall, FPR)
│
├── presentation/               ← 🎤 Demo Day
│   └── README.md               ← Hướng dẫn chuẩn bị slides / demo
│
├── .github/                    ← ⚡ CI/CD GitHub
│   ├── workflows/
│   │   └── ci.yml              ← Pipeline CI tự động: lint → test → build
│   └── hooks/                  ← Cấu hình hook cho GitHub Copilot
│
├── .agents/                    ← 🤖 Cấu hình Antigravity agent
│   ├── rules/
│   │   └── ai-log-hook.md      ← Quy tắc tự động log AI usage
│   └── workflows/
│       └── log.md              ← Workflow ghi log khi dùng AI tool
│
├── .ai-log/                    ← 📊 Log sử dụng AI (auto-generated, không commit)
│
├── .claude/                    ← ⚙️ Hook config cho Claude (Anthropic)
├── .codex/                     ← ⚙️ Hook config cho GitHub Copilot Codex
├── .cursor/                    ← ⚙️ Hook config cho Cursor IDE
├── .gemini/                    ← ⚙️ Hook config cho Google Gemini
│
├── .venv/                      ← 🐍 Python virtual environment (không commit)
├── .pytest_cache/              ← Cache pytest (không commit)
│
├── main.py                     ← 🚀 Entry point (alias cho src/main.py)
├── config.py                   ← Cấu hình (alias cấp root nếu cần)
│
├── Dockerfile                  ← 🐳 Multi-stage Docker build
├── docker-compose.yml          ← 🐙 Orchestration: app + db + redis
├── requirements.txt            ← 📦 Python dependencies
├── ruff.toml                   ← 🧹 Cấu hình linter / formatter (Ruff)
├── Makefile                    ← 🛠️ Lệnh tắt: make run / test / lint / format
│
├── README.md                   ← 📄 Giới thiệu dự án & quick start
├── README_boilerplate.md       ← 📝 Template README cho đội
├── ARCHITECTURE.md             ← 🏛️ Tài liệu kiến trúc chi tiết (Mermaid diagrams)
├── JOURNAL.md                  ← 📓 Nhật ký học tập theo tuần
├── WORKLOG.md                  ← 🕐 Log công việc hàng ngày
├── PROJECT_MAP.md              ← 🗺️ File này — bản đồ toàn bộ dự án
└── .gitignore / .dockerignore  ← Loại trừ file nhạy cảm khỏi git / docker
```

---

## 🧠 Chi tiết từng phần quan trọng

### `src/` — Source Code Chính

| File / Thư mục | Vai trò | Khi nào chỉnh sửa |
|---|---|---|
| `main.py` | Khởi tạo FastAPI app, CORS, router, lifespan | Thêm middleware, thay đổi cấu hình app |
| `config.py` | Đọc `.env`, validate settings qua Pydantic | Thêm biến môi trường mới |
| `agents/graph.py` | Xây dựng LangGraph state graph | Thêm node mới, thay đổi luồng xử lý |
| `agents/state.py` | Định nghĩa `AgentState` (TypedDict) | Thêm field vào state của agent |
| `agents/nodes/` | Hàm xử lý từng bước trong graph | Implement logic phân tích / phát hiện sự cố |
| `agents/tools/` | Công cụ agent gọi được (`@tool`) | Thêm tìm kiếm, tính toán, gọi external API |
| `api/routes.py` | Định nghĩa endpoint `/chat`, `/status` | Thêm API endpoint mới |
| `models/schemas.py` | Request/Response Pydantic models | Thêm/sửa kiểu dữ liệu API |
| `services/llm.py` | Khởi tạo ChatOpenAI client | Đổi model, cấu hình LLM |

---

### `tests/` — Test Suite

| File / Thư mục | Vai trò |
|---|---|
| `conftest.py` | Fixtures dùng chung (mock LLM, test client, v.v.) |
| `test_agents/test_graph.py` | Test LangGraph graph: node logic, conditional routing, state flow |
| `test_api/test_routes.py` | Test API endpoints: status codes, response schema, error handling |

**Chạy test:**
```bash
make test          # chạy tất cả
pytest tests/test_api/ -v    # chỉ API tests
pytest tests/test_agents/ -v # chỉ agent tests
```

---

### `docs/` — Tài liệu

| File / Thư mục | Nội dung |
|---|---|
| `project_summary_report.md` | **PRD đầy đủ**: User stories, AC, API contract, RBAC, wireframes, success metrics |
| `architecture_diagram.md` | Sơ đồ kiến trúc Mermaid (Frontend → Backend → Agent → DB) |
| `guide/chapter-01 → 10` | Guidebook 10 chương về toàn bộ kỹ thuật dự án |
| `guide/troubleshooting.md` | Lỗi thường gặp & cách fix |
| `guide/cost-management.md` | Tối ưu chi phí OpenAI API & cloud |

---

### `scripts/` — Công cụ & AI Logging

| Script | Công dụng |
|---|---|
| `setup.sh` | Cài môi trường lần đầu (venv, dependencies, hooks) |
| `setup_hooks.sh` / `setup_hooks.ps1` | Cài pre-commit git hooks để tự động log AI |
| `log_hook.py` | Hook tự động ghi log khi dùng Claude/Cursor/Codex/Gemini |
| `log_manual.py` | Ghi log thủ công khi dùng ChatGPT, Copilot chat |
| `submit_log.py` | Gửi AI log khi `git push` |
| `log_antigravity.py` | Quét prompt từ Antigravity IDE |

---

### `.github/workflows/ci.yml` — CI/CD Pipeline

Tự động chạy khi push / PR:
1. `ruff check` — lint code
2. `ruff format --check` — kiểm tra format
3. `pytest` — chạy toàn bộ test
4. Docker build (nếu cần)

---

### `Makefile` — Lệnh tắt thường dùng

| Lệnh | Tác dụng |
|---|---|
| `make run` | Khởi động server dev (`uvicorn --reload` port 8000) |
| `make test` | Chạy toàn bộ pytest |
| `make lint` | Kiểm tra lỗi code (ruff check) |
| `make format` | Tự động format code (ruff format) |
| `make check` | Chạy lint + format + test cùng lúc |
| `make clean` | Xóa `__pycache__`, `.pytest_cache`, `.ruff_cache` |

---

### `docker-compose.yml` — Full Stack

Khởi động toàn bộ:
```bash
docker-compose up --build
```
Bao gồm: **app** (FastAPI) + **database** (PostgreSQL) + **cache** (Redis)

---

## 🔄 Luồng dữ liệu AI Agent

```
User Request (HTTP POST /api/v1/chat)
        │
        ▼
   routes.py         ← validate ChatRequest
        │
        ▼
   graph.py          ← ainvoke({ query })
        │
        ▼
 [analyze_node]      ← xử lý query, gọi LLM hoặc tools
        │
   should_continue() ← routing: có lỗi → END, không lỗi → respond
        │
        ▼
 [respond_node]      ← tổng hợp response từ analysis
        │
        ▼
   ChatResponse      ← { response, analysis }
```

---

## ⚙️ Biến môi trường cần thiết (`.env`)

| Biến | Mô tả | Mặc định |
|---|---|---|
| `OPENAI_API_KEY` | **Bắt buộc** — API key OpenAI | `""` |
| `MODEL_NAME` | Model OpenAI sử dụng | `gpt-4o-mini` |
| `APP_ENV` | Môi trường: development/production/test | `development` |
| `APP_PORT` | Port server | `8000` |
| `LLM_TEMPERATURE` | Độ sáng tạo LLM (0.0 – 2.0) | `0.7` |
| `DATABASE_URL` | Chuỗi kết nối DB | `sqlite:///./data/app.db` |
| `CORS_ORIGINS` | Domain frontend cho phép | `http://localhost:3000` |

---

## 📋 Checklist trước khi bắt đầu phát triển

- [ ] Đọc `README.md` — hiểu tổng quan dự án
- [ ] Đọc `docs/project_summary_report.md` — hiểu PRD và yêu cầu
- [ ] Chạy `scripts/setup.sh` — cài môi trường
- [ ] Copy `.env.example` → `.env` và điền `OPENAI_API_KEY`
- [ ] Chạy `make run` — kiểm tra server hoạt động
- [ ] Chạy `make test` — đảm bảo toàn bộ test pass
- [ ] Đọc `docs/guide/chapter-01.md` → `chapter-10.md` khi cần hiểu sâu hơn

---

> _Cập nhật file này mỗi khi thêm thư mục / module mới vào dự án._
