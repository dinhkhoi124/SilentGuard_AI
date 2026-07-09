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
- 🤖 **AI edge inference** — YOLOv8-Pose chạy trực tiếp trên Camera/HLS, phát hiện té ngã theo keypoint.
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

| Lớp              | Công nghệ                                      | Mục đích                                   |
| ---------------- | ---------------------------------------------- | ------------------------------------------ |
| **Edge AI**      | Python + YOLOv8-Pose + OpenCV + LightGBM model | Phát hiện tư thế, phân loại té ngã         |
| **Edge Runtime** | Raspberry Pi 4B / Intel NUC                    | Chạy inference tại chỗ                     |
| **Backend API**  | FastAPI (Python)                               | REST API xử lý event, alert engine         |
| **Database**     | Supabase (PostgreSQL)                          | Lưu event log, review, device info         |
| **File Storage** | Supabase Storage                               | Clip đã blur (≤ 10 giây)                   |
| **Auth**         | Firebase Authentication                        | Đăng nhập gia đình / caregiver             |
| **Push**         | Firebase Cloud Messaging (FCM)                 | Notification iOS + Android                 |
| **LLM**          | OPENAI                                         | Alert message, báo cáo ngày, config parser |
| **Mobile**       | Firebase SDK (iOS/Android)                     | Ứng dụng di động gia đình                  |
| **Deploy**       | Render / Railway                               | Host backend API                           |

---

## 🚨 Phân loại mức độ (Severity)

| Mức          | Điều kiện                            | Hành động                                 |
| ------------ | ------------------------------------ | ----------------------------------------- |
| **LOW**      | Tự đứng dậy trong < 30 giây          | Chỉ ghi log, không thông báo              |
| **MEDIUM**   | Bất động 30 giây – 2 phút            | Push notification đến gia đình            |
| **HIGH**     | Bất động > 2 phút                    | Push notification + tự động gọi điện      |
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

| Chỉ số                  | Mục tiêu  |
| ----------------------- | --------- |
| Alert Time (ngã → push) | < 60 giây |
| AI Precision            | ≥ 72%     |
| AI Recall               | ≥ 94%     |
| F1-Score                | ≥ 82%     |
| False Positive Rate     | < 20%     |
| Edge Device Uptime      | ≥ 99%     |
| Severity Accuracy       | ≥ 90%     |

---

## 👥 Thành viên & Phân công

| Vai trò               | Phụ trách                                                                                                                                                       |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AI Engineer**       | Fall Detection model (YOLOv8-Pose), Set Rule Base, Training LightGBM model, FSM, Severity Classifier edge, Privacy/blur pipeline, Clip capture                  |
| **Backend Engineer**  | Firebase token verification, API `/events` + `/alerts` + `/review`, Alert Engine + Push + Auto-call, Dashboard API, LLM integration, Event Log, Learning Signal |
| **Frontend / Mobile** | Wireframe thiết kế, màn hình Home / Alert List / Alert Detail, Firebase Auth client, FCM token registration                                                     |

---

## 🚀 Hướng Dẫn Cấu Hình & Chạy Dự Án (Setup Instructions)

Dự án gồm hai phần chính chạy độc lập: **Backend API (FastAPI)** và **AI Server (Edge AI Pipeline Worker)**.

### 1. Backend API (FastAPI)

Nằm trong thư mục `backend/`.

#### Yêu cầu cài đặt:

- Python 3.11+
- Cơ sở dữ liệu Supabase đã tạo sẵn các bảng.

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

```

---

# MIT — Sử dụng tự do cho mục đích giáo dục.

> 📄 Xem thêm: [ARCHITECTURE.md](./ARCHITECTURE.md) · [PROJECT_MAP.md](./PROJECT_MAP.md)
