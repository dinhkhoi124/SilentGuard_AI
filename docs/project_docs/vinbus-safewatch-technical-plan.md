# VinBus SafeWatch AI — Kế hoạch Kỹ thuật Tổng hợp

> **Mục tiêu MVP:** MTTD < 30s · Precision ≥ 85% · Recall ≥ 80% · FPR < 10% · 100% alert qua human review

---

## 1. Kiến trúc Tổng thể — 3 Lớp

```
┌─────────────────────────────────────────────────────────┐
│  LỚP 1 — AI Detection (Python service, chạy local)      │
│  Camera RTSP → YOLOv8-Pose → LSTM/Transformer           │
│  → Privacy blur/skeleton → POST /api/events/detect       │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  LỚP 2 — Notification & Human Review (Node.js)          │
│  Alert Engine → WebSocket → Dashboard (Next.js)          │
│  Operator Confirm/Reject → Driver Alert → Event Log      │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  LỚP 3 — Analytics & Learning (Node.js + Python)        │
│  Dashboard thống kê → Time-series → Learning Pipeline   │
│  → Model Registry → A/B test → Retrain                  │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Tech Stack

| Layer | Component | Technology |
|-------|-----------|------------|
| AI | Pose estimation | YOLOv8-Pose (Python) |
| AI | Action classifier | LSTM hoặc VideoMAE |
| AI | Privacy layer | OpenCV blur + skeleton render |
| AI | Edge buffer | FFmpeg circular buffer |
| Backend | API server | Node.js + Express / Fastify |
| Backend | ORM | Prisma |
| Backend | Database | PostgreSQL (Supabase) |
| Backend | Realtime | Socket.io (WebSocket) |
| Backend | Queue | Redis (alert priority queue) |
| Frontend | UI | Next.js (đã có) |
| Frontend | Charts | Recharts hoặc Apache ECharts |
| Frontend | Export | SheetJS |
| Analytics | Time-series query | PostgreSQL window functions (MVP) → TimescaleDB (khi cần) |
| Analytics | Export backend | ExcelJS (Node.js) |
| DevOps | Deploy | Render.com |
| AI infra | Experiment tracking | MLflow hoặc W&B (tuỳ chọn) |

---

## 3. Database Schema (Prisma)

```prisma
model Event {
  id              String   @id @default(cuid())
  busId           String
  routeId         String?
  driverId        String?
  eventType       String   // "fall" | "fight"
  confidence      Float
  timestamp       DateTime
  clipUrl         String?  // clip đã anonymized
  status          String   @default("pending")
  aiModelVersion  String?
  locationLat     Float?
  locationLng     Float?
  createdAt       DateTime @default(now())
  review          Review?
}

model Review {
  id             String   @id @default(cuid())
  eventId        String   @unique
  event          Event    @relation(fields: [eventId], references: [id])
  reviewerId     String
  action         String   // "confirm" | "reject" | "manual_trigger" | "escalate"
  note           String?
  learningSignal Boolean  @default(true)
  videoTimestamp Float?
  reviewedAt     DateTime @default(now())
}

model User {
  id        String @id @default(cuid())
  email     String @unique
  role      String // "admin" | "operator" | "driver"
  busId     String? // chỉ dành cho driver
  createdAt DateTime @default(now())
}
```

> ⚠️ **Quan trọng:** Thiết kế schema đúng ngay từ đầu. Thiếu `routeId`, `aiModelVersion`, `locationLat/Lng` thì sau không thể thống kê "tuyến nào nguy hiểm nhất" hay "model v2 tốt hơn v1 bao nhiêu %".

> 📊 **Analytics phụ thuộc hoàn toàn vào schema:** Mọi filter trên dashboard thống kê (theo ngày, tháng, tuyến, loại sự cố, xe) đều query trực tiếp từ bảng `Event` và `Review`. Không có field nào trong schema → không có filter đó trên UI. Đây là lý do schema phải đúng từ ngày 1.

---

## 4. API Contract

### POST `/api/events/detect`
AI service gọi khi phát hiện sự cố.
```json
// Request body
{
  "event_type": "fall" | "fight",
  "confidence": 0.92,
  "timestamp": "2024-01-15T14:30:00Z",
  "bus_id": "BUS-102",
  "ai_model_version": "yolov8-lstm-v1.2"
}

// Response
{ "alert_id": "EVT-001", "status": "pending" }
```

### GET `/api/alerts?status=pending&limit=20`
Operator lấy danh sách alert.
```json
{
  "alerts": [{
    "id": "EVT-001",
    "bus_id": "BUS-102",
    "event_type": "fight",
    "confidence": 0.92,
    "clip_url": "...",
    "status": "pending",
    "timestamp": "..."
  }]
}
```

### PATCH `/api/alerts/:id/review`
Operator xác nhận hoặc từ chối.
```json
// Request body
{
  "action": "confirm" | "reject" | "escalate" | "manual_trigger",
  "reviewer_id": "OP-01",
  "note": "Xác nhận té ngã thật",
  "learning_signal": true,
  "video_timestamp": 4.2
}
```

### GET `/api/dashboard/summary`
Metrics tổng quan — load ngay khi operator đăng nhập.
```json
{
  "total_alerts": 42,
  "confirmed": 30,
  "rejected": 10,
  "pending": 2,
  "false_alarm_rate": 0.08,
  "avg_mttd_seconds": 24,
  "top_buses": [
    { "bus_id": "BUS-102", "count": 8 }
  ],
  "by_type": { "fall": 18, "fight": 24 },
  "by_hour": [{ "hour": 17, "count": 12 }]
}
```

### GET `/api/analytics/timeseries?from=2024-01-01&to=2024-01-31&group_by=day`
Biểu đồ theo thời gian — dùng cho chart ngày/tuần/tháng.
```json
{
  "series": [
    { "date": "2024-01-15", "fall": 4, "fight": 2, "total": 6 },
    { "date": "2024-01-16", "fall": 1, "fight": 5, "total": 6 }
  ],
  "group_by": "day",
  "from": "2024-01-01",
  "to": "2024-01-31"
}
```

### GET `/api/analytics/buses?from=...&to=...&route_id=32`
Top xe sự cố — hỗ trợ filter theo tuyến và khoảng thời gian.
```json
{
  "buses": [
    { "bus_id": "BUS-102", "route_id": "32", "fall": 5, "fight": 3, "total": 8, "confirm_rate": 0.87 }
  ]
}
```

### GET `/api/analytics/export?from=...&to=...&format=xlsx`
Xuất Excel — trả về file stream, không phải JSON.
> Dùng `SheetJS` (frontend) hoặc `ExcelJS` (backend). Columns: Bus ID, Tuyến, Loại sự cố, Thời gian, Confidence, Kết quả review, Reviewer.

---

## 5. Hệ thống 3 vùng Confidence

| Vùng | Confidence | Hành động | UX |
|------|-----------|-----------|-----|
| **Bỏ qua** | 0% – 40% | Không tạo alert, lưu log nội bộ | Operator không bị làm phiền |
| **Uncertain** | 40% – 70% | Badge vàng, không có âm thanh | Hiện sidebar, không interrupt |
| **Alert đỏ** | 70% – 100% | Alert nổi bật + âm thanh | Phải action trong 60s |

> **Lưu ý:** Threshold 40% và 70% là điểm bắt đầu — cần calibrate lại sau 2–4 tuần vận hành dựa trên operator feedback thực tế.

---

## 6. Metric Đánh giá

### Metric AI (offline — đo trên test set)

| Metric | Công thức | KPI |
|--------|-----------|-----|
| Recall | TP / (TP + FN) | ≥ 80% |
| Precision | TP / (TP + FP) | ≥ 85% |
| False Alarm Rate | FP / (TN + FP) | < 10% |
| Missing Alarm | FN / (TP + FN) | ≤ 20% |
| F-beta (β=1.5) | (1+β²)×(P×R) / (β²×P+R) | Tham khảo |
| ROC AUC | Area under ROC curve | Dùng để chọn threshold |

> **Tại sao F-beta thay vì F1?** β=1.5 weight recall cao hơn precision 1.5 lần — phù hợp bài toán safety-critical.
> 
> **Tại sao không dùng Accuracy?** Dataset imbalanced nặng (~95% clip bình thường), model luôn predict "normal" đạt accuracy 95% nhưng vô dụng.

### Metric Vận hành (online — đo từ production)

| Metric | Mô tả | Ngưỡng cảnh báo |
|--------|-------|----------------|
| Alert fatigue rate | Reject / tổng alert | > 30% → precision thực tế quá thấp |
| MTTD thực tế | Từ sự cố đến operator thấy alert | > 30s → cần điều tra |
| Operator response time | Từ alert đến Confirm/Reject | > 2 phút liên tục → UX có vấn đề |
| False alarm by bus | Xe nào hay bị báo nhầm | Kiểm tra camera góc/ánh sáng |
| Learning signal quality | Tỷ lệ Confirm/Reject theo model version | Dùng để calibrate threshold |

---

## 7. Dataset & Training Plan

### Dataset công khai cần download

**Cho Fall Detection:**
- **Le2i Fall Detection Dataset** — môi trường thực, nhiều góc camera, ưu tiên nhất
- **URFD (UR Fall Detection)** — có RGB + depth, ~70 clip chuẩn
- **Multiple Cameras Fall Dataset** — nhiều góc, gần thực tế giám sát

**Cho Fight/Violence Detection:**
- **RWF-2000** — 2000 clip từ CCTV thật, góc cao, chất lượng thấp → gần nhất với xe buýt, **ưu tiên số 1**
- **Surveillance Camera Fight Dataset** — camera an ninh thật, overhead view
- **RLVS (Real-Life Violence Situations)** — clip YouTube, diverse

**Cho pretrain base model:**
- **NTU RGB+D 120** — 114K clip, 120 action class, có skeleton data sẵn
- **Kinetics-700** — nhiều pretrained model available để fine-tune

### Staged Data (tự quay)

Cần quay **100–200 clip** đúng góc camera xe buýt (overhead 45–60°, cao 2–2.5m):

**Fall scenarios:**
- Té ngã ra phía trước (phanh gấp)
- Té ngã sang ngang (xe cua)
- Ngã khi đứng dậy
- ⚠️ Negative: cúi lấy đồ, ngồi xuống nhanh, khom lưng (hay bị false positive)

**Fight scenarios:**
- Xô đẩy nhẹ, cãi vã vung tay
- ⚠️ Negative: vươn tay lấy hành lý, bế trẻ em, bắt tay

### Training Pipeline

```
Public dataset + Staged data
        ↓
   EDA + Validation
        ↓
  YOLOv8-Pose (skeleton extraction)
        ↓
  LSTM / VideoMAE (action classification)
        ↓
   Evaluate: FalseAlarm + MissingAlarm + AUC
        ↓
  Fine-tune với staged data (bus-specific)
        ↓
    Deploy → collect operator feedback
        ↓
   Retrain hàng tuần (Learning Signal)
```

### Data Validation Script (chạy trước khi train)

```python
import cv2, os

def validate_clip(path):
    cap = cv2.VideoCapture(path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
    height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
    frame_count = cap.get(cv2.CAP_PROP_FRAME_COUNT)
    duration = frame_count / fps if fps > 0 else 0
    cap.release()

    issues = []
    if fps < 15:    issues.append(f"FPS thấp: {fps:.1f}")
    if height < 720: issues.append(f"Resolution thấp: {width:.0f}x{height:.0f}")
    if duration < 3: issues.append(f"Clip ngắn: {duration:.1f}s")
    return issues

for split in ["fall", "fight", "normal"]:
    bad, total = 0, 0
    for f in os.listdir(f"dataset/{split}"):
        issues = validate_clip(f"dataset/{split}/{f}")
        total += 1
        if issues:
            bad += 1
            print(f"[{split}] {f}: {issues}")
    print(f"\n{split}: {total - bad}/{total} clips đạt chuẩn\n")
```

---

## 8. Kế hoạch 1 Tuần — Demo Ban đầu

> **Mục tiêu:** Fake AI data chạy qua đúng pipeline thật. Operator thấy alert realtime, bấm Confirm/Reject, log được lưu. Dashboard thống kê hiển thị được data cơ bản. Model thật chưa cần.

| Ngày | Việc cần làm | Output |
|------|-------------|--------|
| **Ngày 1** | Setup Node.js + Prisma + Supabase, viết DB schema đầy đủ (bao gồm `routeId`, `aiModelVersion`, `locationLat/Lng`) | Schema migrate thành công |
| **Ngày 2** | Viết 4 API endpoint cốt lõi | POST detect · GET alerts · PATCH review · GET dashboard/summary |
| **Ngày 3** | Tích hợp Socket.io, push alert realtime | Alert hiện ngay khi POST detect |
| **Ngày 4** | Viết Mock AI script (Python) + seed data thống kê | Script gửi fake alert mỗi 15–30s, có đủ data để test chart |
| **Ngày 5** | Kết nối Next.js → backend: Alert List + Alert Detail + Dashboard summary | 2 màn hình chính hoạt động với data thật |
| **Ngày 6** | Analytics API: timeseries + top buses + filter theo ngày/tuyến | Chart hiển thị được trên dashboard |
| **Ngày 7** | Sửa bug, chuẩn bị kịch bản demo | Demo 3 path alert + màn hình thống kê chạy được |

> **Lưu ý ngày 4:** Seed ít nhất 50–100 fake events với `timestamp` trải đều trong 7 ngày qua, mix đủ `busId`, `routeId`, `eventType`. Không có data đủ đa dạng thì chart thống kê trông rỗng và không thuyết phục khi demo.

### Mock AI Script

```python
import requests, time, random, datetime

API_URL = "http://localhost:3001/api/events/detect"
BUSES = ["BUS-101", "BUS-102", "BUS-103", "BUS-104"]

while True:
    time.sleep(random.uniform(15, 30))
    confidence = random.uniform(0.35, 0.98)
    payload = {
        "event_type": random.choice(["fall", "fight"]),
        "confidence": round(confidence, 2),
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "bus_id": random.choice(BUSES),
        "ai_model_version": "mock-v0.1"
    }
    r = requests.post(API_URL, json=payload)
    print(f"[{payload['bus_id']}] {payload['event_type']} conf={confidence:.2f} → {r.status_code}")
```

### Circular Buffer (FFmpeg — trên thiết bị xe)

```bash
ffmpeg -i rtsp://camera_url \
  -f segment \
  -segment_time 2 \
  -segment_wrap 5 \
  -reset_timestamps 1 \
  "buffer_segment_%03d.mp4"
```
Khi có alert → ghép 5 đoạn × 2 giây = clip 10 giây đầy đủ từ T-7 đến T+3.

---

## 9. Thứ tự Ưu tiên (nếu bị chậm tiến độ)

Giữ lại từ trên xuống, cắt từ dưới lên:

1. ✅ DB schema đúng và đầy đủ field (bao gồm `routeId`, `aiModelVersion`)
2. ✅ 4 API endpoint + WebSocket (detect, alerts, review, summary)
3. ✅ Mock AI script + seed data đa dạng
4. ✅ Alert List + Alert Detail kết nối thật
5. ✅ Confirm/Reject lưu DB với learning signal
6. ✅ Dashboard summary + analytics timeseries cơ bản
7. ✅ Filter theo ngày/tuyến trên dashboard thống kê
8. ⏳ Xuất Excel — để ngày 7 nếu còn thời gian
9. ⏳ Auth / RBAC — để sprint sau
10. ⏳ Driver notification — để sprint sau
11. ⏳ Model thật (YOLOv8 + LSTM) — song song sprint 2–3

> **Tại sao analytics (6, 7) không thể cắt:** Đây là US-03 và US-05 trong PRD — ngang tầm quan trọng với alert. Stakeholder kỳ vọng thấy cả 2 tính năng trong demo đầu tiên, không phải chỉ alert.

---

## 10. Rủi ro & Biện pháp

| Rủi ro | Mức độ | Biện pháp |
|--------|--------|-----------|
| Camera chất lượng thấp | 🔴 Cao | Test với camera VinBus thật trước Sprint 2 |
| Thiếu data sự cố thật | 🔴 Cao | Kết hợp RWF-2000 + staged video + Mixamo synthetic |
| MTTD > 30s khi tích hợp | 🟡 Trung bình | WebSocket (không dùng polling), circular buffer |
| Alert fatigue — operator mất tin | 🟡 Trung bình | 3-zone confidence, chỉ alert đỏ mới có âm thanh |
| Driver notification không ổn định (3G/4G) | 🟡 Trung bình | Dùng MQTT hoặc kết nối nội bộ, không qua internet |
| Model overfit vào staged data | 🟠 Trung bình | Mix public dataset + staged + augmentation |

---

## 11. Definition of Done (MVP)

- [ ] URL sản phẩm online (Render.com)
- [ ] Login + RBAC 3 role hoạt động
- [ ] Fall Detection chạy được (≥ baseline)
- [ ] Fight Detection chạy được (≥ baseline)
- [ ] Alert hiển thị trên dashboard < 30s
- [ ] Human confirmation flow: Confirm / Reject / Manual Trigger
- [ ] Badge "Uncertain" cho confidence 40–70%
- [ ] Privacy layer: blur face + skeleton visualization
- [ ] Event log + Learning Signal được lưu đầy đủ
- [ ] Dashboard thống kê: tổng alert, by-type, top xe, filter ngày/tuần/tháng
- [ ] Xuất Excel

---

*Tài liệu này tổng hợp từ PRD v2, phân tích kỹ thuật, và kế hoạch triển khai của VinBus SafeWatch AI — Team 128*
