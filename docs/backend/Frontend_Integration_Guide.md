# Hướng Dẫn Tích Hợp API Dành Cho Frontend (Mobile/Web) — SilentGuard

Tài liệu này hướng dẫn cách kết nối và tích hợp các API của backend FastAPI SilentGuard dành cho lập trình viên Frontend (Flutter / React Native).

---

## 1. Thông Tin Chung (Base URL)
- **Local Development**: `http://localhost:8000`
- **Headers Mặc Định**:
  - `Content-Type: application/json`

---

## 2. Quy trình Đăng nhập & Mời thành viên (Login & Invite Flow)

Mọi API gửi từ Mobile App đến Backend bắt buộc phải kèm theo Firebase ID Token.

### Các bước tích hợp trên Mobile:
1. Đăng nhập qua Firebase Auth SDK trên App (Google Login, Email/Password, v.v.).
2. Lấy ID Token từ Firebase user instance:
   - *Firebase Auth SDK*: `await user.getIdToken(forceRefresh: true)`
3. Gắn token này vào Header của tất cả các request dưới dạng **Bearer Token**:

```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```

### Quy trình phân loại người dùng khi Đăng nhập lần đầu (JIT Provisioning):
Backend hỗ trợ cơ chế **Just-in-Time Provisioning** giúp tự động tạo tài khoản khi gọi API lần đầu. Cụ thể có hai kịch bản:

* **Kịch bản A: Người dùng tự tạo tài khoản và sở hữu hộ gia đình mới (Owner)**
  - Gọi bất kỳ API nào lần đầu (ví dụ: `GET /api/households/me`) mà **KHÔNG** truyền thêm header đặc biệt nào khác.
  - Backend sẽ tự động:
    1. Tạo bản ghi trong bảng `users`.
    2. Khởi tạo một hộ gia đình (`households`) mới.
    3. Gán user này làm thành viên với quyền chủ hộ (`role: owner`) trong `household_members`.

* **Kịch bản B: Người dùng tham gia vào hộ gia đình có sẵn thông qua Mã Mời (Member)**
  - Người dùng nhập mã mời nhận từ thành viên khác trên giao diện.
  - Khi thực hiện cuộc gọi API đầu tiên, đính kèm thêm header tùy chọn `X-Invite-Code`:
    ```http
    X-Invite-Code: <MA_MOI_NHAN_DUOC>
    ```
  - Backend sẽ tự động:
    1. Xác thực mã mời có tồn tại, chưa bị dùng và còn hạn (24 giờ).
    2. Tạo bản ghi trong bảng `users`.
    3. Gán user này vào hộ gia đình tương ứng với vai trò thành viên thường (`role: member`) trong `household_members`.
    4. Đánh dấu mã mời đã được sử dụng.
  - *Nếu mã mời bị sai/hết hạn/đã dùng*: API sẽ trả về lỗi `400 Bad Request` với mã lỗi `"INVALID_INVITE_CODE"`.

---

## 3. Các API Endpoints Chính (Mobile App)

### 3.1 Đăng nhập hệ thống (`POST /api/users/login`)
Verify Firebase Token của người dùng, thực hiện JIT Provisioning (khởi tạo tài khoản tự động trong DB nếu chưa có) và trả về thông tin user. Hỗ trợ truyền mã mời để tham gia hộ gia đình khi đăng ký lần đầu.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
X-Invite-Code: <OPTIONAL_MA_MOI>
```
- **Response 200 OK**:
```json
{
  "status": "success",
  "user": {
    "id": "uuid-nội-bộ-của-user",
    "firebase_uid": "firebase-uid-chuẩn",
    "full_name": "Tên Người Dùng",
    "email": "user@example.com",
    "role": "family"
  }
}
```

---

### 3.2 Đăng xuất hệ thống (`POST /api/users/logout`)
Đăng xuất tài khoản, tự động hủy liên kết (clear) token FCM ở DB để tránh nhận thông báo đẩy sau khi đăng xuất.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "status": "ok",
  "message": "Logged out successfully. FCM token cleared."
}
```

---

### 3.3 Đăng ký FCM token nhận Push Notification (`POST /api/users/device-token`)
Gọi mỗi khi ứng dụng khởi chạy hoặc khi token FCM thay đổi (rotate) để đảm bảo nhận được thông báo khẩn cấp.

- **Request Body**:
```json
{
  "fcm_token": "fMEIyxxxxxxxxxxxxxxxx..."
}
```
- **Response 200 OK**:
```json
{
  "updated": true
}
```

---

### 3.4 Lấy danh sách cảnh báo ngã (`GET /api/alerts`)
Lấy danh sách các sự kiện bất thường.

- **Query Parameters**:
  - `status`: `pending` (mặc định), `acknowledged`, `dismissed`, `escalated`, `logged_only`.
  - `limit`: Số bản ghi tối đa (mặc định `20`).
  - `offset`: Phục vụ phân trang (mặc định `0`).
  - `household_id`: ID của hộ gia đình cần lọc (nếu có).

- **Response 200 OK**:
```json
{
  "items": [
    {
      "id": "event-uuid",
      "event_id": "EVT-20260613-001",
      "severity": "HIGH",
      "confidence": 0.89,
      "timestamp": "2026-06-13T02:15:10Z",
      "duration_sec": 145,
      "room": "bedroom",
      "clip_path": "clips/household-uuid/EVT-20260613-001_blur.mp4",
      "llm_message": "Ba bạn vừa ngã trong phòng ngủ lúc 2 giờ sáng...",
      "status": "pending"
    }
  ],
  "total": 1
}
```

---

### 3.5 Xem chi tiết cảnh báo + Link Video (`GET /api/events/{event_id}`)
Dùng để tải thông tin chi tiết của một sự kiện ngã và nhận **Signed URL** để phát video clip.

- **Response 200 OK**:
Trả về chi tiết 1 event tương tự như trong list nhưng bổ sung trường `clip_url` (đường dẫn tạm thời phát video trên Supabase Storage, tự hết hạn sau 5 phút):
```json
{
  "id": "event-uuid",
  "event_id": "EVT-20260613-001",
  "severity": "HIGH",
  "confidence": 0.89,
  "timestamp": "2026-06-13T02:15:10Z",
  "duration_sec": 145,
  "room": "bedroom",
  "clip_path": "clips/household-uuid/EVT-20260613-001_blur.mp4",
  "clip_url": "https://xxxx.supabase.co/storage/v1/object/sign/clips/...?token=...",
  "llm_message": "Ba bạn vừa ngã trong phòng ngủ lúc 2 giờ sáng...",
  "status": "pending"
}
```

---

### 3.6 Phản hồi cảnh báo (`PATCH /api/alerts/{event_id}/review`)
Gọi khi người nhà xác nhận trạng thái cảnh báo trên App (ví dụ: đã kiểm tra hoặc báo động giả).

- **Request Body**:
```json
{
  "action": "acknowledged", // Hoặc "dismissed"
  "note": "Đã gọi cho bố, ổn rồi",
  "clip_timestamp": 8.2 // (Tùy chọn) Giây phát hiện ngã rõ nhất trong video
}
```
- **Response 200 OK**:
```json
{
  "status": "ok"
}
```

---

### 3.7 Xem báo cáo ngày (`GET /api/reports/daily`)
Báo cáo tổng hợp tình trạng sức khỏe/sự cố của người cao tuổi do AI Claude tổng hợp.

- **Query Parameters**:
  - `date`: Định dạng `YYYY-MM-DD` (ví dụ: `2026-06-13`).

- **Response 200 OK**:
```json
{
  "date": "2026-06-13",
  "summary": "Hôm nay cụ Nam có 1 cảnh báo ngã mức độ HIGH tại phòng ngủ lúc 02:15, cụ được hỗ trợ kịp thời sau 42 giây...",
  "events": [...]
}
```

---

### 3.8 Dashboard Summary (`GET /api/dashboard/summary`)
Thống kê nhanh các chỉ số hiển thị trên trang chủ App.

- **Response 200 OK**:
```json
{
  "total_alerts_today": 3,
  "avg_response_time_sec": 42,
  "acknowledged": 2,
  "total": 3,
  "by_severity": { "LOW": 1, "MEDIUM": 1, "HIGH": 1, "CRITICAL": 0 },
  "cameras": [
    { "name": "Camera phòng ngủ", "status": "online", "fps": 15 },
    { "name": "Camera phòng khách", "status": "online", "fps": 15 }
  ]
}
```

---

### 3.9 Cấu hình ngưỡng cảnh báo (`GET/PUT /api/settings/thresholds`)
- **GET**: Lấy cấu hình hiện tại.
- **PUT**: Cập nhật cấu hình mới.

- **Request / Response Body**:
```json
{
  "low_max_sec": 30,      // Ngưỡng tối đa báo động nhẹ (giây)
  "medium_max_sec": 120,   // Ngưỡng tối đa báo động vừa (giây)
  "high_max_sec": 300,    // Ngưỡng tối đa báo động cao (giây)
  "dedup_window_sec": 60,  // Thời gian chặn trùng lặp giữa các camera
  "suppress_windows": [
    { "start": "13:00", "end": "15:00", "max_still_sec": 3600 } // Khoảng thời gian cụ đi ngủ trưa
  ]
}
```

---

### 3.10 Đặt cấu hình bằng chat với AI (`POST /api/llm/config`)
Dành cho tính năng ra lệnh bằng giọng nói/tin nhắn cấu hình.

- **Request Body**:
```json
{
  "message": "Ba tôi hay ngủ trưa dưới sàn, đừng báo lúc 1-3 giờ chiều"
}
```
- **Response 200 OK**: Trả về bản xem trước (preview) cấu hình AI phân tích được để ứng dụng hiển thị popup cho người dùng xác nhận trước khi cập nhật.

---

### 3.11 Quản lý danh bạ liên hệ khẩn cấp (`GET/POST/PATCH/DELETE /api/contacts`)
Hệ thống liên hệ khẩn cấp dạng danh sách ưu tiên để escalate cuộc gọi/thông báo khi người dùng chính không phản hồi.

- **POST**: Thêm liên hệ mới.
- **PATCH**: Đổi thứ tự ưu tiên (`priority_order`).
- **DELETE**: Xóa liên hệ.
  
> **Lưu ý:** Thứ tự ưu tiên `priority_order` là một dãy số nguyên liên tục bắt đầu từ 1. Khi xóa một liên hệ, ứng dụng Frontend cần gọi cập nhật lại thứ tự ưu tiên của các liên hệ còn lại để tránh các khoảng hở (ví dụ: đang có `1, 2, 3`, xóa `2` thì cần reorder lại để danh sách thành `1, 2`).

---

### 3.12 Tạo mã mời thành viên mới (`POST /api/households/invite`)
Sinh mã mời ngẫu nhiên có hiệu lực trong 24 giờ. Chỉ áp dụng cho tài khoản có vai trò `owner`.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 201 Created**:
```json
{
  "code": "random_invite_code_string",
  "expires_at": "2026-06-17T02:15:10Z"
}
```

---

### 3.13 Lấy thông tin hộ gia đình hiện tại (`GET /api/households/me`)
Lấy thông tin hộ gia đình của user hiện tại cùng với vai trò (`role`) tương ứng của họ.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "household_id": "household-uuid",
  "role": "owner", // Hoặc "member"
  "elderly_name": "Nguyen Van A"
}
```

---

## 4. Định Dạng Lỗi Chuẩn (Error Handling)

Khi API gặp lỗi xử lý, Backend sẽ trả về định dạng JSON chuẩn RFC sau để Frontend có thể dễ dàng hiển thị thông báo lỗi thân thiện cho người dùng:

```json
{
  "error": {
    "code": "VALIDATION_ERROR", // Hoặc: UNAUTHORIZED, EVENT_NOT_FOUND, LLM_TIMEOUT
    "message": "Chi tiết thông điệp lỗi bằng tiếng Việt để hiển thị"
  }
}
```
