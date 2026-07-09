# SilentGuard AI — Theo dõi tiến độ

> Cập nhật lần cuối: Sprint 2 đang chạy  
> Format: `- [x]` Xong · `- [~]` Đang làm · `- [ ]` Chưa làm

---

## Giai đoạn 0 — Sprint 1: Thiết kế & Lên kế hoạch ✅

- [x] Xác định vấn đề & persona (người cao tuổi sống một mình, gia đình lo ngại)
- [x] PRD v1 (Problem Statement, Solution, User Stories)
- [x] Kiến trúc 3 lớp (Edge → Backend → Mobile)
- [x] Tech stack decision (FastAPI + Supabase + Firebase Auth/FCM)
- [x] Severity classification (4 mức: LOW / MEDIUM / HIGH / CRITICAL)
- [x] 4 Paths (Happy Path / Low-confidence / Failure / Correction)
- [x] API contract draft
- [x] DB schema draft
- [x] GitHub repo setup
- [x] Phân công task theo backlog (T-001 → T-028)

---

## Giai đoạn 1 — Sprint 2: Core Pipeline + API + Alert Engine 🔵 Đang làm

### AI Engineer — Edge Device

- [~] **T-008** Fall Detection model (YOLOv8-Pose fine-tune trên URFD + Le2i dataset)
- [ ] **T-009** Severity Classifier edge (rule-based: duration bất động + motion score)
- [ ] **T-010** Privacy layer (blur mặt bằng OpenCV trước khi encode clip)
- [ ] **T-011** Clip capture 10s (circular buffer FFmpeg: T-8s trước ngã → T+2s sau)
- [ ] Test edge pipeline end-to-end với camera IP thật (kiểm tra FPS + độ trễ)

### Backend — FastAPI + Supabase

- [ ] **T-007** Firebase token verification (`firebase-admin` SDK, middleware FastAPI)
- [ ] Setup FastAPI project + kết nối Supabase (env, connection pool)
- [ ] DB schema migrate (bảng: `events`, `alert_reviews`, `devices`, `users`)
- [ ] **T-012** `POST /api/events/detect` — nhận event từ edge device
- [ ] **T-013** `GET /api/alerts` + `PATCH /api/alerts/:id/review` — alert list & review
- [ ] **T-014** Alert Engine (severity double-check + FCM push + auto-call logic Twilio/VGTS)
- [ ] **T-017** `GET /api/dashboard/summary` — thống kê tổng quan
- [ ] **T-021** `GET /api/events` — event log lịch sử (có filter date/severity)
- [ ] **T-024** Camera offline detection (heartbeat timeout → push thông báo mất kết nối)

### Frontend / Mobile — Flutter hoặc React Native

- [ ] **T-005** Wireframe 4 màn hình chính (Figma: Home, Alert List, Alert Detail, Settings)
- [ ] **T-015** Home / Alert List screen (badge số alert chưa đọc, sort by time)
- [ ] **T-016** Alert Detail screen (clip player blur, severity badge, nút Confirm / Dismiss)
- [ ] Firebase Auth client setup (login flow: email + password hoặc Google)
- [ ] FCM token registration + nhận push notification khi app background/foreground

---

## Giai đoạn 2 — Sprint 3: LLM + Dashboard + Bug Fix

- [ ] **T-018** LLM alert message (Claude Sonnet → tiếng Việt, tự nhiên, không robot — VD: "Mẹ bạn có vẻ bị ngã tại phòng khách lúc 14:32, đã nằm yên hơn 1 phút")
- [ ] **T-019** Daily report generation (Claude tóm tắt 24h events cho gia đình mỗi sáng)
- [ ] **T-020** Config via chat (parse "tắt alert ban đêm từ 10pm đến 6am" → lưu config_json)
- [ ] **T-022** Learning Signal (lưu confirm/dismiss từ gia đình → dataset retrain sau)
- [ ] Dashboard charts: số alert theo ngày, phân bố theo severity, giờ nguy hiểm cao nhất
- [ ] Severity threshold configurable per user (VD: ông A bất động 45s mới push thay vì 30s)
- [ ] Sửa bug từ Sprint 2 testing (backlog bug tracker)

---

## Giai đoạn 3 — Sprint 4: Deploy + Production

- [ ] Docker hóa FastAPI backend (`Dockerfile` + `docker-compose`)
- [ ] Deploy backend lên Render hoặc Railway (auto-deploy từ GitHub main)
- [ ] Supabase production setup (storage bucket, Row Level Security policies)
- [ ] Firebase project production config (tách prod/dev environment)
- [ ] Edge device hardening (auto-restart systemd service, watchdog timer)
- [ ] End-to-end test với camera thật trong môi trường thực (phòng ngủ, phòng khách)
- [ ] Test MTTD (Mean Time To Detect) < 60s từ té ngã đến mobile nhận push
- [ ] Definition of Done checklist pass đầy đủ
- [ ] Demo preparation (kịch bản demo 5 phút, slide, video fallback)

---

## Giai đoạn 4 — Post-MVP (Addon v2, ngoài scope hiện tại)

- [ ] Facial recognition — nhận diện đúng người (OUT OF SCOPE MVP)
- [ ] Phát hiện đột quỵ khi ngồi yên bất thường (behavioral anomaly)
- [ ] Behavioral baseline cá nhân hóa theo thói quen của từng cụ
- [ ] Tích hợp dịch vụ cấp cứu 115 thật (API hoặc SIP trunk)
- [ ] Multi-camera support trong một căn hộ
- [ ] Báo cáo sức khỏe tuần/tháng gửi qua email

---

## Tổng quan tiến độ

```
Sprint 1 — Thiết kế       ██████████████████████████  100% ✅
Sprint 2 — Core Pipeline  ████░░░░░░░░░░░░░░░░░░░░░░   15% 🔵
Sprint 3 — LLM + Dashboard░░░░░░░░░░░░░░░░░░░░░░░░░░    0% ⬜
Sprint 4 — Deploy + Prod  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0% ⬜

Tổng MVP: [████░░░░░░░░░░░░░░░░░░░░░░]  ~25% hoàn thành
```

> **Blocker cần giải quyết ngay:**  
> 🔴 Camera IP: xác nhận resolution/FPS đủ để YOLOv8 detect pose  
> 🔴 Edge device: benchmark RPi 5 vs Jetson Nano với budget thực tế  
> 🔴 Dataset: URFD + Le2i có đủ góc camera cao (top-down VN phổ biến) không?
