# SilentGuard AI — Báo cáo Tổng hợp Dự án

> **Phiên bản:** MVP v1.0 · **Sprint hiện tại:** Sprint 2 · **Ngày cập nhật:** 2026-06-15

---

## 1. One-Page Brief

### Vấn đề

Mỗi năm, hàng triệu người cao tuổi trên thế giới bị té ngã tại nhà mà không ai biết trong 8–24 giờ. Tại Việt Nam, mô hình sống một mình ở tuổi già ngày càng phổ biến khi con cái đi làm xa. Các thiết bị đeo tay (wearable) có tuân thủ thấp — người cao tuổi quên đeo, bỏ sạc, hoặc không chấp nhận thay đổi thói quen. Gia đình không có signal nào để biết khi có biến cố.

### Giải pháp

SilentGuard AI là hệ thống phát hiện té ngã **thụ động** (passive): camera đặt trong nhà, AI chạy trên edge device, không cần người cao tuổi làm gì cả.

- Camera ghi hình → Edge device phân tích bằng YOLOv8-Pose
- Phát hiện té ngã → phân loại severity tự động (4 mức)
- Push notification + auto-call gửi đến gia đình trong vòng **< 60 giây**
- Raw video **không bao giờ lên cloud** — chỉ clip đã blur mặt

### Target Persona

| Người dùng | Mô tả |
|---|---|
| **Người cao tuổi** (65–80 tuổi) | Sống một mình hoặc ít người, không cần tương tác với hệ thống |
| **Gia đình / Người chăm sóc** | Nhận alert, xem clip, confirm/dismiss trên mobile |
| **Admin hệ thống** | Quản lý thiết bị, cấu hình ngưỡng, xem dashboard |

### Core Value

> *"Biết ngay khi mẹ ngã — dù bạn đang ở cách đó 100km."*

### Key Metrics (MVP)

| Chỉ số | Mục tiêu |
|---|---|
| Alert Time | < 60 giây từ té ngã đến mobile nhận push |
| Precision | ≥ 85% |
| Recall | ≥ 80% |
| False Positive Rate | < 15% |
| Edge Uptime | ≥ 99% |
| Severity Accuracy | ≥ 90% |

### Scope

**Trong scope (MVP):**
- Phát hiện té ngã qua camera IP / USB tại nhà
- Severity 4 mức + push notification + auto-call
- Clip 10s đã blur gửi gia đình
- Dashboard thống kê sự kiện
- LLM tạo alert text tự nhiên (Claude)
- Learning signal từ confirm/dismiss

**Ngoài scope (v2+):**
- Nhận diện mặt / facial recognition
- Phát hiện đột quỵ khi ngồi yên
- Tích hợp 115 / dịch vụ cấp cứu thật
- Multi-camera, multi-room

### Workflow tóm tắt

```
Camera → YOLOv8 (Edge) → Fall? → Severity Engine → Blur + Clip
                                                   → POST /detect
                                                   → Alert Engine
                                                   → FCM Push → App gia đình
                                                   → Auto-call (HIGH/CRITICAL)
```

### Riskiest Assumption

> Camera IP phổ thông (720p/1080p, 15–30fps) đặt ở góc phòng đủ để YOLOv8-Pose phát hiện tư thế ngã với độ chính xác ≥ 85% mà không cần camera chuyên dụng đắt tiền.

### Definition of Done MVP

- [ ] MTTD (Mean Time To Detect) < 60s đo được end-to-end với camera thật
- [ ] Precision ≥ 85%, Recall ≥ 80% trên test set ≥ 200 clip
- [ ] Severity Accuracy ≥ 90% trên staged scenarios
- [ ] Edge Uptime ≥ 99% trong 48h stress test
- [ ] Gia đình nhận push notification và xem được clip blur trên mobile
- [ ] Auto-call hoạt động khi HIGH/CRITICAL và không dismiss trong 2 phút
- [ ] Raw video không xuất hiện trong Supabase Storage (kiểm tra bằng audit log)
- [ ] Demo 5 phút chạy mượt với camera thật, không crash

---

## 2. PRD — Product Requirements Document

### 2.1 User Stories & Acceptance Criteria

---

#### US-01: Push Notification khi phát hiện té ngã

> **Là** thành viên gia đình,  
> **Tôi muốn** nhận push notification ngay khi AI phát hiện bố/mẹ tôi có thể bị ngã,  
> **Để** tôi có thể phản ứng kịp thời dù đang ở bất cứ đâu.

**Acceptance Criteria:**

- AC-01.1: Notification xuất hiện trên điện thoại trong vòng 60 giây kể từ thời điểm té ngã
- AC-01.2: Notification hiển thị severity badge (màu vàng MEDIUM / đỏ HIGH / đỏ nhấp nháy CRITICAL)
- AC-01.3: Notification hiển thị message tự nhiên do Claude tạo ra (VD: *"Mẹ bạn có vẻ bị ngã tại phòng khách lúc 14:32, đã nằm yên hơn 1 phút"*), không phải text robot
- AC-01.4: Notification hoạt động cả khi app đang chạy ngầm (background FCM)
- AC-01.5: Không gửi push khi severity = LOW (chỉ log)

---

#### US-02: Xem clip đã blur + severity + confirm/dismiss

> **Là** thành viên gia đình,  
> **Tôi muốn** xem đoạn clip ngắn (đã làm mờ mặt) và thông tin severity,  
> **Để** tôi tự đánh giá tình trạng và quyết định hành động.

**Acceptance Criteria:**

- AC-02.1: Alert Detail hiển thị clip 10s (T-8s trước ngã đến T+2s sau) có thể phát lại
- AC-02.2: Clip đã blur mặt — không thấy rõ nét mặt, chỉ thấy silhouette/skeleton
- AC-02.3: Hiển thị severity badge, confidence score (%), thời gian sự kiện, vị trí camera
- AC-02.4: Có nút **Confirm** (xác nhận ngã thật) và **Dismiss** (bỏ qua, không phải ngã)
- AC-02.5: Sau khi confirm/dismiss, trạng thái alert cập nhật ngay lập tức trên UI

---

#### US-03: Severity phù hợp — LOW không làm phiền, CRITICAL không bỏ sót

> **Là** thành viên gia đình,  
> **Tôi muốn** nhận alert đúng mức độ,  
> **Để** tôi không bị "alert fatigue" từ những cú ngã nhẹ nhưng cũng không bỏ sót tình huống nguy hiểm.

**Acceptance Criteria:**

- AC-03.1: LOW (tự đứng < 30s) → chỉ log, không push, không làm phiền
- AC-03.2: MEDIUM (bất động 30s–2 phút) → push 1 lần, có thể dismiss
- AC-03.3: HIGH (> 2 phút) → push + auto-call lần 1 sau 2 phút không phản hồi
- AC-03.4: CRITICAL (> 5 phút + không dismiss) → push liên tục toàn bộ emergency contacts + gọi mỗi 60s
- AC-03.5: Severity Accuracy ≥ 90% trên staged test scenarios
- AC-03.6: Người dùng Admin có thể điều chỉnh ngưỡng thời gian bất động per-user

---

#### US-04: Auto-call khi HIGH/CRITICAL không có phản hồi

> **Là** thành viên gia đình,  
> **Tôi muốn** hệ thống tự động gọi điện cho tôi nếu tôi không phản hồi push,  
> **Để** đảm bảo tôi biết được tình huống dù đang bận hoặc không nhìn màn hình.

**Acceptance Criteria:**

- AC-04.1: Sau khi gửi push HIGH, nếu không có confirm/dismiss trong 2 phút → trigger auto-call
- AC-04.2: Gọi lần lượt theo danh sách emergency_contacts (tối đa 3 người)
- AC-04.3: Nếu có người confirm trên app → dừng auto-call ngay lập tức
- AC-04.4: CRITICAL: gọi lại mỗi 60s cho đến khi có phản hồi
- AC-04.5: Log lại toàn bộ lịch sử call attempt (timestamp, contact, kết quả)

---

#### US-05: Lịch sử sự kiện + Dashboard thống kê

> **Là** Admin hoặc thành viên gia đình,  
> **Tôi muốn** xem lịch sử đầy đủ và thống kê theo thời gian,  
> **Để** theo dõi xu hướng và phát hiện vấn đề sức khỏe dài hạn.

**Acceptance Criteria:**

- AC-05.1: Event log hiển thị toàn bộ sự kiện (có thể filter theo ngày, severity, trạng thái)
- AC-05.2: Dashboard hiển thị: số alert hôm nay, tỷ lệ false positive, giờ nguy hiểm cao nhất
- AC-05.3: Chart thống kê alert theo ngày (7 ngày / 30 ngày)
- AC-05.4: Phân bố severity (LOW/MEDIUM/HIGH/CRITICAL) theo tuần
- AC-05.5: Dữ liệu load trong < 2 giây

---

#### US-06: Claude tạo alert message tự nhiên

> **Là** thành viên gia đình,  
> **Tôi muốn** đọc thông báo viết như con người, không phải text hệ thống,  
> **Để** hiểu ngay tình huống mà không cần giải thích thêm.

**Acceptance Criteria:**

- AC-06.1: Alert message do Claude Sonnet tạo ra bằng tiếng Việt
- AC-06.2: Message có context: ai (tên người cao tuổi), ở đâu (vị trí camera), khi nào, bao lâu
- AC-06.3: Ví dụ đầu ra tốt: *"Mẹ bạn (bà Lan) có vẻ bị ngã ở phòng khách lúc 14:32 và đã nằm yên khoảng 1 phút. Vui lòng kiểm tra ngay."*
- AC-06.4: Ví dụ đầu ra không chấp nhận: *"FALL_DETECTED. Severity: MEDIUM. Timestamp: 1718424720"*
- AC-06.5: Generation time < 3 giây (không làm trễ push notification)
- AC-06.6: Fallback message nếu Claude timeout: dùng template cố định

---

### 2.2 Bốn Paths — Luồng xử lý chính

#### Happy Path — Confidence cao, severity MEDIUM/HIGH

```
1. YOLOv8-Pose phát hiện tư thế ngã (confidence ≥ 85%)
2. Severity Engine: bất động 45 giây → MEDIUM
3. Anonymizer blur mặt, circular buffer xuất clip 10s
4. Edge gửi POST /api/events/detect
5. Backend: INSERT events, upload clip → Supabase
6. Claude generate: "Mẹ bạn có vẻ bị ngã tại phòng khách..."
7. Firebase FCM push đến tất cả family members
8. Gia đình nhận notification < 60s, mở app
9. Xem clip blur, đọc message → nhấn Confirm
10. Backend log learning_signal = true_positive
11. Alert resolved, auto-call không kích hoạt
```

**Kết quả:** Gia đình biết trong < 60s, không cần auto-call, sự kiện được log để cải thiện model.

---

#### Low-Confidence Path — Confidence thấp (50–75%)

```
1. YOLOv8 phát hiện tư thế ngã nhưng confidence 60%
2. Severity Engine: bất động 20 giây → LOW + low-confidence flag
3. Backend: INSERT event với status = "uncertain"
4. Push notification màu vàng: "Có thể có điều bất thường ở phòng ngủ"
5. Không auto-call
6. Gia đình xem clip → nhấn Dismiss
7. Backend log learning_signal = false_positive, confidence_threshold = 60%
```

**Kết quả:** Gia đình được thông báo nhẹ nhàng, không bị làm phiền quá mức, hệ thống học từ feedback.

---

#### Failure Path A — False Positive (người ngồi xuống đột ngột)

```
1. Người cao tuổi ngồi xuống ghế nhanh → YOLOv8 nhầm là ngã (confidence 87%)
2. Severity MEDIUM vì bất động 35 giây (đang xem TV)
3. Push notification gửi đến gia đình
4. Gia đình mở app, xem clip → thấy rõ đang ngồi xem TV
5. Nhấn Dismiss + thêm note "Đang ngồi, không phải ngã"
6. Backend log: learning_signal = {false_positive: true, context: "sitting"}
7. Alert count: false positive rate tăng → trigger model review nếu FPR > 15%
```

**Kết quả:** Gia đình không bị lo lắng oan, hệ thống thu thập data để giảm FPR.

---

#### Correction Path — Gia đình confirm/dismiss để cải thiện model

```
1. Mọi action confirm/dismiss từ gia đình đều ghi vào alert_reviews
2. learning_signal jsonb ghi: {true_positive, false_positive, missed_detection}
3. Hàng tuần: AI Engineer export learning signals để review
4. Nếu FPR > 15% hoặc Recall < 80% → trigger fine-tuning sprint
5. Model version mới deploy lên edge device qua OTA update
6. Vòng lặp cải thiện liên tục
```

**Kết quả:** Hệ thống ngày càng chính xác hơn theo thói quen sinh hoạt của người dùng cụ thể.

---

### 2.3 API Contract

#### Tổng quan endpoint

| Method | Endpoint | Mô tả | Auth |
|---|---|---|---|
| `POST` | `/api/events/detect` | Edge gửi event phát hiện té ngã | Edge API Key |
| `GET` | `/api/alerts` | Lấy danh sách alert (có filter) | Firebase JWT |
| `GET` | `/api/alerts/:id` | Chi tiết 1 alert + signed clip URL | Firebase JWT |
| `PATCH` | `/api/alerts/:id/review` | Confirm / dismiss / escalate | Firebase JWT |
| `GET` | `/api/dashboard/summary` | Thống kê tổng quan dashboard | Firebase JWT |
| `GET` | `/api/events` | Event log lịch sử (filter date/severity) | Firebase JWT |
| `POST` | `/api/llm/alert-message` | Generate alert text bằng Claude | Internal |
| `GET` | `/api/llm/daily-report` | Báo cáo tóm tắt 24h | Firebase JWT |

---

#### `POST /api/events/detect`

Edge device gửi khi phát hiện sự kiện.

**Request body:**
```json
{
  "device_id": "cam-01-hanoi",
  "event_type": "fall",
  "severity": "MEDIUM",
  "confidence": 0.87,
  "timestamp": "2026-06-15T14:32:10Z",
  "duration_seconds": 45.2,
  "clip_url": "https://storage.supabase.co/.../clip_blurred_xyz.mp4",
  "ai_model_version": "yolov8-pose-v2.1"
}
```

**Response 201:**
```json
{
  "event_id": "evt_a1b2c3d4",
  "status": "received",
  "alert_triggered": true,
  "push_sent_to": 2
}
```

---

#### `GET /api/alerts`

**Query params:** `?status=pending&severity=HIGH&limit=20&offset=0`

**Response 200:**
```json
{
  "alerts": [
    {
      "id": "evt_a1b2c3d4",
      "severity": "HIGH",
      "confidence": 0.91,
      "timestamp": "2026-06-15T14:32:10Z",
      "status": "pending",
      "location": "Phòng khách",
      "llm_message": "Mẹ bạn có vẻ bị ngã tại phòng khách lúc 14:32..."
    }
  ],
  "total": 5,
  "unread": 3
}
```

---

#### `PATCH /api/alerts/:id/review`

**Request body:**
```json
{
  "action": "confirm",
  "note": "Đã gọi về, mẹ bị vấp nhưng không sao",
  "learning_signal": {
    "true_positive": true,
    "context": "actual_fall"
  }
}
```

**Response 200:**
```json
{
  "review_id": "rev_x9y8z7",
  "event_id": "evt_a1b2c3d4",
  "action": "confirm",
  "reviewed_at": "2026-06-15T14:35:22Z"
}
```

---

#### `GET /api/dashboard/summary`

**Response 200:**
```json
{
  "today": {
    "total_events": 3,
    "confirmed": 1,
    "dismissed": 1,
    "pending": 1,
    "false_positive_rate": 0.33
  },
  "week": {
    "total_events": 12,
    "by_severity": {
      "LOW": 5, "MEDIUM": 4, "HIGH": 2, "CRITICAL": 1
    },
    "peak_hour": 14
  },
  "devices": {
    "online": 1,
    "offline": 0
  }
}
```

---

### 2.4 DB Schema — Supabase / PostgreSQL

#### Bảng `events`

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | `uuid` PRIMARY KEY | Auto-generated |
| `device_id` | `uuid` FK → devices | Camera nguồn |
| `event_type` | `text` | `fall`, `anomaly` |
| `severity` | `text` | `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` |
| `confidence` | `float4` | 0.0 – 1.0 |
| `timestamp` | `timestamptz` | Thời điểm sự kiện xảy ra |
| `clip_url` | `text` | URL Supabase Storage (clip đã blur) |
| `status` | `text` | `pending`, `reviewed`, `auto_resolved` |
| `ai_model_version` | `text` | VD: `yolov8-pose-v2.1` |
| `duration_seconds` | `float4` | Thời gian bất động (giây) |
| `created_at` | `timestamptz` | DEFAULT now() |

---

#### Bảng `alert_reviews`

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | `uuid` PRIMARY KEY | |
| `event_id` | `uuid` FK → events | |
| `reviewer_id` | `text` FK → users.id | Firebase UID |
| `action` | `text` | `confirm`, `dismiss`, `escalate` |
| `note` | `text` | Ghi chú tuỳ ý |
| `learning_signal` | `jsonb` | `{true_positive, false_positive, context}` |
| `reviewed_at` | `timestamptz` | DEFAULT now() |

---

#### Bảng `devices`

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | `uuid` PRIMARY KEY | |
| `name` | `text` | VD: `Camera phòng khách` |
| `location` | `text` | VD: `Phòng khách`, `Phòng ngủ` |
| `owner_id` | `text` FK → users.id | |
| `status` | `text` | `online`, `offline` |
| `last_seen` | `timestamptz` | Heartbeat cuối cùng |
| `config_json` | `jsonb` | `{severity_threshold_medium: 30, ...}` |

---

#### Bảng `users`

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | `text` PRIMARY KEY | Firebase UID |
| `email` | `text` | |
| `name` | `text` | |
| `role` | `text` | `admin`, `family`, `caregiver` |
| `emergency_contacts` | `jsonb` | `[{name, phone, priority}]` |
| `notification_settings` | `jsonb` | `{quiet_hours: "22:00-06:00", min_severity: "MEDIUM"}` |

---

### 2.5 Privacy Constraints

| Dữ liệu | Lưu trong RAM Edge | Upload Cloud | Lưu Supabase | Hiển thị App |
|---|:---:|:---:|:---:|:---:|
| Raw video frame | ✓ | ✗ | ✗ | ✗ |
| Video đã blur mặt | ✓ | ✓ | ✓ | ✓ |
| Skeleton keypoints | ✓ | ✗ | ✗ | ✗ |
| Metadata JSON | ✓ | ✓ | ✓ | ✓ |
| Tên / thông tin cá nhân | — | ✓ | ✓ | ✓ (gia đình) |
| FCM token | — | ✓ | ✓ | ✗ |
| Learning signal | — | ✓ | ✓ | ✗ (admin) |

> **Nguyên tắc:** Raw video frame chỉ tồn tại trong RAM. Khi edge device khởi động lại, toàn bộ buffer bị xóa. Không có cơ chế nào ghi raw video ra disk hay upload cloud.

---

### 2.6 Success Metrics

| Chỉ số | Mục tiêu | Warning | Critical |
|---|---|---|---|
| Alert Time (MTTD) | < 60s | > 60s | > 120s |
| Precision | ≥ 85% | < 85% | < 70% |
| Recall | ≥ 80% | < 80% | < 65% |
| False Positive Rate | < 15% | > 15% | > 25% |
| Severity Accuracy | ≥ 90% | < 90% | < 75% |
| Edge Uptime | ≥ 99% | < 99% | < 95% |
| Push Delivery Rate | ≥ 98% | < 98% | < 90% |
| Claude Response Time | < 3s | > 3s | > 8s |
| App Load Time (Alert Detail) | < 2s | > 2s | > 5s |

---

### 2.7 Definition of Done MVP

Toàn bộ checklist sau phải pass trước khi gọi là MVP hoàn thành:

**AI / Edge:**
- [ ] YOLOv8-Pose fine-tune trên URFD + Le2i, Precision ≥ 85%, Recall ≥ 80% trên test set ≥ 200 clip
- [ ] Severity Classifier đúng ≥ 90% trên 4 staged scenarios (LOW/MEDIUM/HIGH/CRITICAL)
- [ ] Blur mặt không thể nhận dạng được mặt người (kiểm tra bằng mắt thường)
- [ ] Circular buffer 10s hoạt động đúng, không leak memory
- [ ] Pipeline xử lý < 500ms per frame trên edge device đã chọn

**Backend:**
- [ ] Tất cả endpoint API trả response đúng schema, status code đúng
- [ ] Firebase token verification từ chối token invalid
- [ ] Alert Engine: push đúng severity, auto-call kích hoạt đúng thời điểm
- [ ] Learning signal được ghi đúng vào DB sau mỗi confirm/dismiss
- [ ] Camera offline detection gửi push trong vòng 5 phút sau khi mất heartbeat

**Frontend / Mobile:**
- [ ] Nhận push notification khi app background và foreground
- [ ] Clip blur phát được trên cả iOS và Android
- [ ] Confirm/Dismiss gọi API thành công, UI cập nhật ngay
- [ ] Login/logout Firebase Auth hoạt động

**End-to-end:**
- [ ] MTTD < 60s đo được 3 lần liên tiếp với camera thật và người thật diễn ngã
- [ ] Raw video không có trong Supabase Storage (audit bằng tay)
- [ ] Uptime edge device ≥ 99% trong 48h stress test
- [ ] Demo 5 phút không crash, không lỗi hiển thị

---

### 2.8 Rủi ro & Phương án giảm thiểu

| # | Rủi ro | Mức độ | Phương án |
|---|---|---|---|
| R-01 | Camera IP resolution/FPS không đủ detect | 🔴 Blocker | Benchmark sớm với ≥ 3 dòng camera; fallback sang USB webcam nếu cần |
| R-02 | Edge device không chạy YOLOv8 realtime với budget | 🔴 Blocker | Thử RPi 5 (8GB) và Jetson Nano; cân nhắc YOLOv8n (nano) thay full model |
| R-03 | URFD + Le2i không đủ góc camera VN (top-down cao) | 🔴 Blocker | Tự quay 200 clip staged ở góc thực tế; augmentation tăng góc nhìn |
| R-04 | False positive khi ngồi xuống đột ngột | 🟠 High | Thêm temporal smoothing (3 frame vote); tune confidence threshold |
| R-05 | Gia đình không chấp nhận blur, muốn thấy mặt | 🟠 High | UX research sớm; offer option "blur chỉ người lạ" hoặc "xác nhận trước khi xem" |
| R-06 | Severity threshold cần customizable per user | 🟡 Medium | Lưu config_json trong bảng devices; UI settings cho Admin |

---

*Tài liệu này được cập nhật mỗi sprint. Mọi thay đổi lớn về scope, tech stack, hoặc metrics cần được ghi lại kèm ngày và lý do.*
