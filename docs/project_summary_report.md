# VinBus SafeWatch AI — Tóm tắt toàn bộ project

> MVP V1 · Hệ thống phát hiện sự cố an toàn hành khách tự động trên xe buýt

---

## 1. 1-Page Brief

**Vấn đề:** Nhân viên giám sát không thể theo dõi hàng trăm camera đồng thời. Sự cố chỉ được phát hiện khi có người báo cáo, làm chậm toàn bộ quy trình xử lý.

**Giải pháp:** AI tự động phát hiện té ngã & xô xát từ video stream, tạo alert thời gian thực, ẩn danh hình ảnh, và yêu cầu xác nhận của con người (Human-in-the-loop).

**Target persona:** Nhân viên giám sát an toàn ca đêm tại Trung tâm Điều hành VinBus — quản lý hàng chục đến hàng trăm xe cùng lúc, không có visibility real-time.

**Core value:** Phát hiện sự cố tự động và sớm mà không cần theo dõi camera liên tục. Toàn bộ hình ảnh được ẩn danh, không nhận diện danh tính.

### Key Metrics

| Metric | Target |
|---|---|
| MTTD (Mean Time to Detect) | < 30 giây |
| Auto-detect rate | 70% |
| AI Precision | ≥ 85% |
| False Positive Rate | < 10% |

### Scope

**In scope — MVP V1:** Fall Detection · Fight Detection · Privacy Layer · Real-time Alert · Human Review · Dashboard · Event Log · RBAC

**Out of scope:** Face recognition · Weapon/smoking detection · Emotion recognition · Passenger counting · Mobile app

### Workflow

```
Camera stream → AI Detect → AI Classify → Anonymize → Tạo Alert → Operator Confirm → Driver Alert → Handle → Feedback
```

### ⚠ Riskiest Assumption
Camera trên xe có đủ chất lượng để AI phát hiện chính xác té ngã và xô xát trong điều kiện thực tế. Nếu giả định này sai → dự án thất bại.

**Definition of Done:** URL online · Login · Dashboard · RBAC · Fall+Fight Detection · Alert · Human Confirm · Privacy Layer · Event Log

---

## 2. PRD — Product Requirements Document

### 2.1 User Stories & Acceptance Criteria

#### US-01 — AI phát hiện sự cố tự động
> *"Là nhân viên giám sát, tôi muốn hệ thống tự động phát hiện té ngã và xô xát từ camera, để tôi không cần theo dõi màn hình liên tục."*

- ✓ Hệ thống phát hiện Fall Detection và Fight Detection từ video stream
- ✓ Output gồm: event_type, confidence, timestamp, bus_id
- ✓ Alert xuất hiện trên dashboard trong vòng < 30 giây kể từ khi sự cố xảy ra
- ✓ Confidence score hiển thị rõ trên mỗi alert; confidence 40–70% hiển thị badge "Uncertain" màu vàng

#### US-02 — Operator xem và xác nhận alert
> *"Là operator, tôi muốn xem clip đã ẩn danh và xác nhận / từ chối alert, để tôi kiểm soát được mọi hành động trước khi thông báo tài xế."*

- ✓ Danh sách alert hiển thị: bus ID, event type, thời gian, confidence
- ✓ Mỗi alert có video clip 10s đã blur mặt & body
- ✓ Operator có thể chọn: **Confirm & Alert Driver** / **Dismiss–Reject** / **Manual Trigger**
- ✓ Sau khi Confirm → tài xế nhận cảnh báo tức thì
- ✓ 100% alert phải qua bước review trước khi gửi tài xế; không auto-confirm
- ✓ Mọi thao tác Confirm/Reject được log kèm timestamp video (Learning Signal)

#### US-03 — Xem dashboard tổng quan fleet
> *"Là nhân viên giám sát, tôi muốn thấy tổng quan toàn bộ fleet ngay khi đăng nhập, để biết xe nào đang có vấn đề."*

- ✓ Hiển thị tổng số alert trong ngày / tuần / tháng
- ✓ Biểu đồ alert theo ngày, theo loại (Fall vs Fight), theo khung giờ
- ✓ Top xe có nhiều sự cố nhất
- ✓ Tỷ lệ confirm / reject của operator hiển thị dưới dạng %

#### US-04 — Đăng nhập và phân quyền RBAC
> *"Là admin, tôi muốn phân quyền theo vai trò, để tài xế không thể thao tác trên dashboard."*

- ✓ Hệ thống có 3 role: Admin, Operator, Driver
- ✓ Login/Logout hoạt động, session timeout sau 8 giờ
- ✓ Mỗi role chỉ truy cập được đúng tính năng của mình

#### US-05 — Privacy layer — ẩn danh hình ảnh
> *"Là hành khách, tôi muốn danh tính của mình không bị lưu."*

- ✓ Toàn bộ clip trước khi hiển thị phải qua bước blur mặt & body hoặc skeleton
- ✓ Hệ thống không được lưu bất kỳ dữ liệu khuôn mặt nào
- ✓ Clip gốc không được truy cập từ dashboard operator

---

### 2.2 Functional & Non-functional Requirements

**Functional:** Fall Detection · Fight Detection · Real-time alert · Human review (Confirm / Dismiss-Reject / Manual Trigger) · Privacy layer · Event log + Learning Signal · Dashboard · RBAC

**Non-functional:** MTTD < 30s · Precision ≥ 85% · Recall ≥ 80% · FPR < 10% · Uptime ≥ 99% · Hỗ trợ ≥ 50 xe/operator đồng thời

**Out of scope:** Face/emotion recognition · Weapon/smoking detection · Passenger counting · Mobile app

---

### 2.3 Four Paths — Kịch bản & UX an toàn

| Path | Kịch bản | Thiết kế UX |
|---|---|---|
| **✓ Happy Path** (AI đúng & tự tin >85%) | AI phát hiện té ngã chính xác, hiện Alert đỏ chớp nháy trên Dashboard | Hiện video clip 10s, nút **"Confirm & Alert Driver"** nổi bật. Một click để thực thi |
| **⚠ Low-confidence** (AI không chắc 40–70%) | AI thấy chuyển động lạ nhưng không rõ là té ngã hay khách cúi xuống lấy đồ | Hiện Alert màu vàng kèm: *"AI nghi ngờ có sự cố, vui lòng kiểm tra"*. Không tự động báo động |
| **✗ Failure Path** (AI sai/bỏ sót) | A: Báo nhầm (False Positive). B: AI bỏ sót sự cố thật nhưng Operator tự nhìn thấy | A: Nút **"Dismiss/Reject"** tắt nhanh. B: Nút **"Manual Trigger"** để operator tự tạo sự cố |
| **↩ Correction Path** (Học từ lỗi) | Operator xác nhận/từ chối cảnh báo của AI | Mọi thao tác Confirm/Reject log kèm timestamp video → **Learning Signal** cho AI |

---

### 2.4 Privacy Constraints

| ✗ Hệ thống KHÔNG được | ✓ Hệ thống ĐƯỢC phép |
|---|---|
| Nhận diện khuôn mặt | Blur mặt & body trước khi hiển thị |
| Lưu danh tính hành khách | Hiển thị skeleton visualization |
| Suy luận danh tính từ dữ liệu | Lưu clip sự kiện đã ẩn danh |
| Cho phép operator xem clip gốc | Phân tích hành vi (không gắn danh tính) |

---

### 2.5 API Contract

```
POST   /api/events/detect
       Body: { event_type, confidence, timestamp, bus_id }

GET    /api/alerts?status=pending
       Response: { alerts: [{ id, bus_id, type, confidence, clip_url, status }] }

PATCH  /api/alerts/{id}/review
       Body: { action: "confirm"|"reject"|"escalate"|"manual_trigger", reviewer_id, note, learning_signal }

GET    /api/dashboard/summary
       Response: { total_alerts, confirmed, rejected, pending, top_buses, learning_signals }
```

---

### 2.6 RBAC — Phân quyền

| Tính năng | Admin | Operator | Driver |
|---|---|---|---|
| Xem dashboard | ✓ | ✓ | — |
| Xem alert & clip | ✓ | ✓ | — |
| Confirm / Reject / Manual Trigger | ✓ | ✓ | — |
| Nhận cảnh báo | — | — | ✓ |
| Quản lý user | ✓ | — | — |
| Xem event log & Learning Signal | ✓ | ✓ | — |

---

### 2.7 Success Metrics

| Metric | Target | Loại |
|---|---|---|
| MTTD | < 30s | Business |
| Auto-detect rate | 70% | Business |
| AI Precision | ≥ 85% | AI |
| AI Recall | ≥ 80% | AI |
| False Positive Rate | < 10% | AI |
| Human review rate | 100% | Product |

---

### 2.8 Definition of Done

- ✓ URL truy cập online
- ✓ Login & RBAC hoạt động
- ✓ Fall Detection chạy được
- ✓ Fight Detection chạy được
- ✓ Alert hiển thị trên dashboard
- ✓ Human confirmation flow (Confirm / Reject / Manual Trigger)
- ✓ Privacy layer (blur / skeleton)
- ✓ Event log & Learning Signal

---

## 3. Wireframe — 4 màn hình chính

### Màn hình 1 — Dashboard (Happy Path)
- **Topbar:** Logo + tên ca + avatar operator
- **Sidebar:** Dashboard (active) · Alerts (badge số) · Fleet · Event log · Quản lý user · Cài đặt
- **Content:**
  - Filter: Hôm nay / Tuần / Tháng
  - 4 metric cards: Tổng alert · Confirmed · Rejected · Pending
  - Bar chart: Alert theo ngày (Fall vs Fight)
  - Top xe sự cố (bar mini)

### Màn hình 2 — Alert List
- Filter tabs: Tất cả · **Pending (2)** · Fight · Fall
- Table: Thời gian · Xe · Loại · Confidence bar · Trạng thái · Hành động
- Row styling: Đỏ (Fight urgent) · Vàng (low confidence) · Xanh (confirmed) · Xám (rejected)
- Note: *"Alert confidence 40–70%: AI không chắc chắn — Operator cần xem kỹ trước khi quyết định"*

### Màn hình 3 — Alert Detail (Human Review)
- **Timeline:** AI detect ✓ → Anonymize ✓ → **Operator review** (active) → Confirm/Reject → Driver notified
- **Trái:** Video box đen hiển thị skeleton 2 người + tag "privacy layer active"
- **Phải — Meta cards:**
  - Confidence AI: **92%** (màu xanh)
  - Xe & tuyến: BUS-102 · Tuyến 32
  - MTTD: 18s ✓ (trong ngưỡng)
  - Actions: **Confirm & Alert Driver** · Dismiss/Reject · Escalate
  - Input ghi chú + note "Learning Signal"

### Màn hình 4 — 4 Paths Flow

```
✓ Happy Path         ⚠ Low-confidence
[Xanh]               [Vàng]
AI >85% → 1 click    40-70% → Badge Uncertain
Confirm & Alert      Không auto, review thủ công

✗ Failure Path       ↩ Correction Path
[Đỏ]                 [Xanh dương]
A: Dismiss/Reject    Confirm/Reject → log
B: Manual Trigger    timestamp → Learning Signal
```

---

## 4. Tech Stack (đã quyết định)

| Layer | Tech |
|---|---|
| Backend | Node.js Express + EJS |
| AI Pipeline | Python |
| ORM | Prisma |
| Database | PostgreSQL trên Supabase |
| Deployment | Render |

---

## 5. GitHub Repo Setup (pending)

Artifact còn lại cần tạo:
- `README.md` — mô tả project, hướng dẫn chạy
- `.gitignore` — loại trừ `venv/`, `.env`, `node_modules/`
- Folder structure: `/src`, `/ai`, `/tests`, `/docs`
- Branching: `main` / `dev` / `feature/*`
- GitHub Issues / Project board

---

[Xem tài liệu chi tiết tại đây](https://drive.google.com/drive/folders/12ixcJg3m2tdaomejL3o2eKS3PUoSyWR2)