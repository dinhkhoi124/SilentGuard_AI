# 🛡️ SilentGuard AI

<!--![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.111+-009688?style=flat&logo=fastapi&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20FCM-FFCA28?style=flat&logo=firebase&logoColor=black)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=flat&logo=supabase&logoColor=white)
![YOLOv8](https://img.shields.io/badge/YOLOv8-Pose-00FFFF?style=flat&logo=ultralytics&logoColor=black)-->

> **Team 128** · Mentor: Công Nguyễn · AI20K Build Cohort 2
> 🔗 [github.com/AI20K-Build-Cohort-2/C2-App-128](https://github.com/AI20K-Build-Cohort-2/C2-App-128)

---

## 📌 Giới thiệu

**SilentGuard AI** là hệ thống phát hiện té ngã thụ động dành cho người cao tuổi sống một mình. Camera sẵn có trong nhà kết hợp với AI edge device tự động phân tích tư thế người, phát hiện té ngã, và gửi cảnh báo đến gia đình trong vòng **dưới 60 giây** — không cần đeo bất kỳ thiết bị nào. Toàn bộ video thô được xử lý tại chỗ, **không bao giờ** truyền lên cloud ở dạng chưa làm mờ.

---

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
- 🧠 **Claude LLM** — tạo message cảnh báo tự nhiên, báo cáo hàng ngày, và phân tích cấu hình.

---

## 🏗️ Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────────┐
│                   EDGE DEVICE                       │
│            (Raspberry Pi / Intel NUC)               │
│                                                     │
│  [Camera IP/RTSP] → Video 15 FPS                   │
│         ↓                                           │
│  YOLOv8-Pose → Skeleton Keypoints                  │
│         ↓                                           │
│  Fall Classifier (rule-based, < 50ms)              │
│         ↓                                           │
│  Severity Engine (duration timer)                  │
│         ↓                                           │
│  Anonymization: blur mặt + encode clip 10s         │
│         ↓                                           │
│  POST /api/events/detect (metadata + clip đã blur) │
└───────────────────────┬─────────────────────────────┘
                        │ HTTPS (chỉ metadata + clip blur)
                        ↓
┌─────────────────────────────────────────────────────┐
│               BACKEND API                           │
│           (FastAPI + Supabase)                      │
│                                                     │
│  Event Processing → Severity double-check           │
│         ↓                                           │
│  Alert Engine → Claude LLM (message generation)    │
│         ↓                                           │
│  Firebase Admin SDK → FCM Push + Auto-call logic   │
│         ↓                                           │
│  Supabase Storage (lưu clip đã blur)               │
│  Supabase PostgreSQL (event log, review)           │
└───────────────────────┬─────────────────────────────┘
                        │ FCM Push / WebSocket
                        ↓
┌─────────────────────────────────────────────────────┐
│               MOBILE APP                            │
│           (iOS / Android — Firebase)                │
│                                                     │
│  Firebase Auth → đăng nhập gia đình                │
│  FCM → nhận push notification                      │
│  Alert List → Alert Detail (clip + severity)       │
│  Confirm / Dismiss → learning signal               │
└─────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

| Lớp | Công nghệ | Mục đích |
|---|---|---|
| **Edge AI** | Python + YOLOv8-Pose + OpenCV | Phát hiện tư thế, phân loại té ngã |
| **Edge Runtime** | Raspberry Pi 4B / Intel NUC | Chạy inference tại chỗ |
| **Backend API** | FastAPI (Python) | REST API xử lý event, alert engine |
| **Database** | Supabase (PostgreSQL) | Lưu event log, review, device info |
| **File Storage** | Supabase Storage | Clip đã blur (≤ 10 giây) |
| **Auth** | Firebase Authentication | Đăng nhập gia đình / caregiver |
| **Push** | Firebase Cloud Messaging (FCM) | Notification iOS + Android |
| **LLM** | Claude (Sonnet) | Alert message, báo cáo ngày, config parser |
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
                   → Blur mặt (OpenCV face anonymization)
                   → Encode clip 10s (H.264, độ phân giải giảm)
                   → Chỉ clip đã blur + metadata được gửi lên cloud
```

- ❌ Không stream video lên server.
- ❌ Không lưu raw frame vào disk edge.
- ✅ Clip cloud chỉ chứa silhouette + tư thế, không nhận diện được danh tính.
- ✅ Clip tự động xóa sau 30 ngày (Supabase Storage lifecycle).

---

## 📊 Success Metrics

| Chỉ số | Mục tiêu |
|---|---|
| Alert Time (ngã → push) | < 60 giây |
| AI Precision | ≥ 85% |
| AI Recall | ≥ 80% |
| False Positive Rate | < 15% |
| Edge Device Uptime | ≥ 99% |
| Severity Accuracy | ≥ 90% |

---

## 👥 Thành viên & Phân công

| Vai trò | Phụ trách |
|---|---|
| **AI Engineer** | Fall Detection model (YOLOv8-Pose), Severity Classifier edge, Privacy/blur pipeline, Clip capture |
| **Backend Engineer** | Firebase token verification, API `/events` + `/alerts` + `/review`, Alert Engine + Push + Auto-call, Dashboard API, LLM integration, Event Log, Learning Signal |
| **Frontend / Mobile** | Wireframe thiết kế, màn hình Home / Alert List / Alert Detail, Firebase Auth client, FCM token registration |

---

## 🚀 Quick Start

> ⚙️ Phần này sẽ được cập nhật sau khi hoàn thành Sprint 2 (Core Pipeline).

**Yêu cầu môi trường:**
- Python 3.11+
- Raspberry Pi 4B (≥ 4GB RAM) hoặc Intel NUC
- Camera IP hỗ trợ RTSP
- Tài khoản Supabase + Firebase project

```bash
# Clone repo
git clone https://github.com/AI20K-Build-Cohort-2/C2-App-128.git
cd C2-App-128/team-128

# Cài đặt backend
cd src
cp .env.example .env   # điền biến môi trường
pip install -r requirements.txt
uvicorn main:app --reload

# Cài đặt edge (trên Raspberry Pi)
cd src/edge
pip install -r requirements-edge.txt
python run_edge.py
```

---

## 🗓️ Sprint Roadmap

| Sprint | Tuần | Trạng thái | Mục tiêu chính |
|---|---|---|---|
| **Sprint 1** | W1–W2 | ✅ Hoàn thành | Thiết kế kiến trúc, wireframe, ERD, API contract |
| **Sprint 2** | W2–W3 | 🔄 Đang làm | Core pipeline edge, API backend, Alert Engine, push notification |
| **Sprint 3** | W4 | 📋 Lên kế hoạch | Claude LLM integration, Dashboard, sửa lỗi từ Sprint 2 |
| **Sprint 4** | W5–W6 | 📋 Lên kế hoạch | Deploy production, threshold per-user, kiểm thử E2E |

---

## 📁 Cấu trúc thư mục

```
team-128/
├── src/                  ← Backend FastAPI chính của SilentGuard
│   ├── edge/             ← Edge AI pipeline (YOLOv8-Pose + blur)
│   ├── api/              ← FastAPI routes, models, services
│   ├── alert/            ← Alert Engine + FCM + auto-call
│   └── llm/              ← Claude integration
├── frontend/             ← ⚠️ Prototype Next.js (VinBus cũ, không dùng production)
├── backend/              ← ⚠️ Prototype Node.js/Fastify (VinBus cũ, không dùng)
├── docs/                 ← Tài liệu kỹ thuật chi tiết
├── scripts/              ← Scripts tiện ích (setup, migration, eval)
├── tests/                ← Test suite (unit + integration)
├── eval/                 ← Đánh giá model AI (precision/recall)
├── README.md             ← File này
├── ARCHITECTURE.md       ← Kiến trúc hệ thống chi tiết
└── PROJECT_MAP.md        ← Bản đồ thư mục và phân công
```

---

> 📄 Xem thêm: [ARCHITECTURE.md](./ARCHITECTURE.md) · [PROJECT_MAP.md](./PROJECT_MAP.md)
