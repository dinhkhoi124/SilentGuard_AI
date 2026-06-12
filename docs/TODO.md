# ✅ TODO — VinBus SafeWatch AI

> Cập nhật file này sau mỗi lần hoàn thành một việc.
> Format: `- [x]` = xong · `- [ ]` = chưa làm · `- [~]` = đang làm

---

## Giai đoạn 0 — Frontend (Next.js) ✅

- [x] Cấu trúc thư mục Next.js 14 App Router
- [x] Auth context + localStorage session
- [x] Login page (3 tài khoản demo)
- [x] Sidebar với RBAC (admin / operator / driver)
- [x] Dashboard — metric cards + bar chart + top buses
- [x] Alert List — filter tabs + confidence bar + status badge
- [x] Alert Detail — timeline + skeleton SVG animation + Confirm/Reject/Escalate
- [x] Fleet page — grid xe + trạng thái online/offline
- [x] Event Log — bảng + filter + sort
- [x] Users page — bảng phân quyền (Admin only)
- [x] Settings page — ngưỡng confidence + toggle notification
- [x] 4 Paths page — flow xử lý alert
- [x] Driver view — giao diện riêng nhận cảnh báo
- [x] Build production thành công (13/13 trang)

---

## Giai đoạn 1 — Backend Node.js (Fastify + Prisma + Socket.io) 🔵 Đang làm

### 1.1 Cấu trúc & Config
- [x] `backend/package.json` (Fastify, Prisma, Socket.io, tsx)
- [x] `backend/tsconfig.json`
- [x] `backend/.env.example`
- [x] `backend/.gitignore`

### 1.2 Database
- [x] `backend/prisma/schema.prisma` — 3 model: Event, Review, User
- [x] Index đúng theo ADR-008 (timestamp, eventType, busId, routeId)
- [x] Chạy `prisma db push` → migrate schema vào SQLite
- [x] Chạy `npm run db:seed` → seed 80 events + 3 users

### 1.3 Server
- [x] `backend/src/server.ts` — Fastify + CORS + routes
- [x] `backend/src/db.ts` — Prisma client singleton
- [x] `backend/src/socket.ts` — Socket.io setup + emit helper

### 1.4 API Endpoints
- [x] `POST /api/events/detect` — AI service gửi alert vào
- [x] `GET /api/alerts` — operator lấy danh sách (filter by status)
- [x] `GET /api/alerts/:id` — chi tiết 1 alert
- [x] `PATCH /api/alerts/:id/review` — operator confirm / reject / escalate
- [x] `GET /api/dashboard/summary` — metrics tổng quan
- [x] `GET /api/analytics/timeseries` — chart ngày/tuần/tháng
- [x] `GET /api/analytics/buses` — top xe sự cố
- [ ] `GET /api/analytics/export?format=xlsx` — xuất Excel

### 1.5 Mock AI Script
- [x] `scripts/mock_ai.py` — gửi fake alert mỗi 15–30s
- [ ] Chạy thử: `python scripts/mock_ai.py` → xem alert xuất hiện trên terminal

### 1.6 Seed Data
- [x] `backend/src/seed.ts` — 80 events + 3 users, trải đều 7 ngày
- [x] Verify: chart dashboard có data đủ đa dạng sau seed

---

## Giai đoạn 2 — Kết nối Frontend → Backend thật

- [ ] Cài `socket.io-client` vào `frontend/`
- [ ] Tạo `frontend/src/lib/api.ts` — fetch wrapper trỏ đến `localhost:3001`
- [ ] Dashboard page: thay `mockDashboardStats` bằng `GET /api/dashboard/summary`
- [ ] Alerts page: thay `mockAlerts` bằng `GET /api/alerts`
- [ ] Alert Detail: thay mock bằng `GET /api/alerts/:id` + `PATCH /api/alerts/:id/review`
- [ ] Socket.io client: nhận `new-alert` event → hiển thị realtime trên Alerts page
- [ ] Analytics timeseries: kết nối `GET /api/analytics/timeseries` → chart
- [ ] Fleet page: kết nối dữ liệu thật (hoặc giữ mock nếu chưa có bus management API)

---

## Giai đoạn 3 — Auth thật (JWT)

- [ ] Cài `@fastify/jwt` vào backend
- [ ] `POST /api/auth/login` — trả JWT token
- [ ] Middleware guard các route cần auth
- [ ] Frontend: lưu JWT trong localStorage, gửi kèm mọi request
- [ ] Refresh token khi hết hạn 8 giờ (theo PRD)
- [ ] RBAC thật: middleware kiểm tra role trước khi cho phép action

---

## Giai đoạn 4 — AI Service thật (Python FastAPI + YOLOv8)

- [ ] Setup Python env cho AI service (tách khỏi `src/` boilerplate hiện tại)
- [ ] Download dataset: RWF-2000 (fight), Le2i (fall)
- [ ] Quay staged data: 100–200 clip góc overhead 45–60°
- [ ] Chạy data validation script (có trong `technical-plan.md`)
- [ ] Train YOLOv8-Pose (skeleton extraction)
- [ ] Train LSTM action classifier
- [ ] Privacy layer: blur face + skeleton render với OpenCV
- [ ] Wrap vào FastAPI: `POST /ai/infer` nhận RTSP stream
- [ ] Test: precision ≥ 85%, recall ≥ 80%, FPR < 10%
- [ ] Kết nối: AI service gọi `POST /api/events/detect` trên backend

---

## Giai đoạn 5 — Analytics nâng cao

- [ ] `GET /api/analytics/export?format=xlsx` — xuất Excel với ExcelJS
- [ ] Filter theo tuyến (`route_id`) trên analytics/buses
- [ ] Alert fatigue rate — track Reject / total alert
- [ ] Learning signal dashboard — tỷ lệ Confirm/Reject theo model version
- [ ] Cân nhắc TimescaleDB nếu query > 2s (hiện tại dùng PostgreSQL thuần)

---

## Giai đoạn 6 — Deploy

- [ ] Tạo `backend/.dockerignore` + `Dockerfile` cho backend
- [ ] Cập nhật `docker-compose.yml` — thêm backend service + database volume
- [ ] Tạo Supabase project → lấy `DATABASE_URL` PostgreSQL
- [ ] Chạy `prisma migrate deploy` trên PostgreSQL
- [ ] Deploy backend lên Render.com (Web Service)
- [ ] Deploy frontend lên Vercel (hoặc Render Static Site)
- [ ] Upgrade Render free tier → paid ($7/tháng) trước khi demo (tránh sleep)
- [ ] Cấu hình environment variables trên Render
- [ ] Smoke test: URL online, login, alert realtime hoạt động

---

## Giai đoạn 7 — Driver Notification & Polish

- [ ] Driver notification qua WebSocket (room riêng theo busId)
- [ ] Auto-escalate sau 2 phút nếu operator chưa action (theo ADR-004)
- [ ] Âm thanh cảnh báo cho alert đỏ (confidence ≥ 70%)
- [ ] Test MTTD thực tế < 30s end-to-end
- [ ] Kiểm tra Definition of Done (checklist trong `technical-plan.md`)

---

## 📊 Tiến độ tổng quan

```
Giai đoạn 0 — Frontend     ████████████ 100%  ✅
Giai đoạn 1 — Backend      ██████████░░  90%  🔵 Gần xong
Giai đoạn 2 — Kết nối      ░░░░░░░░░░░░   0%  ⏳
Giai đoạn 3 — Auth JWT      ░░░░░░░░░░░░   0%  ⏳
Giai đoạn 4 — AI Service   ░░░░░░░░░░░░   0%  ⏳
Giai đoạn 5 — Analytics    ░░░░░░░░░░░░   0%  ⏳
Giai đoạn 6 — Deploy       ░░░░░░░░░░░░   0%  ⏳
Giai đoạn 7 — Polish       ░░░░░░░░░░░░   0%  ⏳
```

---

*Cập nhật lần cuối: Giai đoạn 1 gần xong — server chạy OK, DB seeded, TypeScript clean. Còn: export Excel + test mock_ai.py*
