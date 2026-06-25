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

### 3.2a Xóa tài khoản (GDPR Compliance) (`DELETE /api/users/me`)
Xóa vĩnh viễn tài khoản người dùng và tất cả dữ liệu cá nhân liên quan. Cần thiết để đáp ứng chính sách xét duyệt của Apple App Store và Google Play.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "status": "ok",
  "message": "Tài khoản đã được xóa thành công"
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

### 3.6a Phản hồi độ chính xác cảnh báo (`POST /api/events/{event_id}/feedback`)
Gửi phản hồi đánh giá độ chính xác của mô hình phát hiện ngã cho một sự kiện cụ thể. Thành viên hoặc chủ hộ đều có quyền gọi.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
Content-Type: application/json
```
- **Request Body**:
```json
{
  "label": "correct", // Hoặc "incorrect", "uncertain"
  "note": "Mô hình phát hiện chính xác cú ngã", // (Tùy chọn)
  "camera_serial": "SN12345678" // Số serial của camera gửi phản hồi (Tùy chọn)
}
```
- **Response 200 OK**:
```json
{
  "status": "received",
  "feedback_id": "feedback-uuid"
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

- **GET /api/settings/thresholds**
  - **Quyền**: Thành viên (`member`) trở lên.
  - **Query Parameters**:
    - `household_id` (Bắt buộc): ID hộ gia đình.
  - **Response 200 OK**:
    ```json
    {
      "household_id": "8c271fac-1165-4142-a7ed-2468f873454b",
      "low_max_sec": 30,
      "medium_max_sec": 120,
      "high_max_sec": 300,
      "dedup_window_sec": 60,
      "suppress_windows": [
        { "start": "13:00", "end": "15:00", "max_still_sec": 3600 }
      ]
    }
    ```

- **PUT /api/settings/thresholds**
  - **Quyền**: Chỉ chủ hộ (`owner`).
  - **Request Body**:
    ```json
    {
      "household_id": "8c271fac-1165-4142-a7ed-2468f873454b",
      "low_max_sec": 30,
      "medium_max_sec": 120,
      "high_max_sec": 300,
      "dedup_window_sec": 60,
      "suppress_windows": [
        { "start": "13:00", "end": "15:00", "max_still_sec": 3600 }
      ]
    }
    ```
  - **Ràng buộc validation**:
    - Trường `suppress_windows` chứa các khung giờ tắt âm. Thuộc tính `start` và `end` phải tuân thủ đúng định dạng `HH:MM` (24 giờ).
    - Nếu sai định dạng, API trả về mã lỗi `422 Unprocessable Entity`.
  - **Response 200 OK**:
    ```json
    {
      "household_id": "8c271fac-1165-4142-a7ed-2468f873454b",
      "low_max_sec": 30,
      "medium_max_sec": 120,
      "high_max_sec": 300,
      "dedup_window_sec": 60,
      "suppress_windows": [
        { "start": "13:00", "end": "15:00", "max_still_sec": 3600 }
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

- **GET /api/contacts**
  - **Quyền**: Thành viên (`member`) trở lên.
  - **Query Parameters**:
    - `household_id` (Bắt buộc): ID hộ gia đình.
  - **Response 200 OK**: Trả về danh sách sắp xếp theo `priority_order` tăng dần:
    ```json
    [
      {
        "id": "contact-uuid-1",
        "household_id": "household-uuid",
        "user_id": "user-uuid-1",
        "priority_order": 1,
        "created_at": "2026-06-17T03:12:35Z"
      },
      {
        "id": "contact-uuid-2",
        "household_id": "household-uuid",
        "user_id": "user-uuid-2",
        "priority_order": 2,
        "created_at": "2026-06-17T03:12:36Z"
      }
    ]
    ```

- **POST /api/contacts**
  - **Quyền**: Chỉ chủ hộ (`owner`).
  - **Request Body**:
    ```json
    {
      "household_id": "household-uuid",
      "user_id": "user-uuid-to-add",
      "priority_order": 3
    }
    ```
  - **Ràng buộc**:
    - `user_id` bắt buộc phải tồn tại trong hệ thống và đã là thành viên (`household_member`) của hộ gia đình `household_id` tương ứng (không thêm liên hệ cho người ngoài hộ gia đình).
    - Nếu vi phạm (ví dụ thêm một user không thuộc hộ gia đình), hệ thống trả về lỗi `400 Bad Request` dạng:
      ```json
      {
        "detail": "User is not a member of the household"
      }
      ```
  - **Response 200 OK**:
    ```json
    {
      "id": "new-contact-uuid",
      "household_id": "household-uuid",
      "user_id": "user-uuid-to-add",
      "priority_order": 3,
      "created_at": "2026-06-17T08:00:00Z"
    }
    ```

- **PATCH /api/contacts/{contact_id}**
  - **Quyền**: Chỉ chủ hộ (`owner`).
  - **Query Parameters**:
    - `priority_order` (Bắt buộc, kiểu `int`): Thứ tự ưu tiên mới muốn đổi sang (ví dụ: `?priority_order=1`).
  - **Cơ chế hoạt động**: 
    - Khi thay đổi thứ tự ưu tiên của một liên hệ, backend sẽ tự động cập nhật và sắp xếp lại thứ tự ưu tiên (`priority_order`) của các liên hệ khác trong cùng hộ gia đình để đảm bảo tính liên tục (từ 1 đến N), không có khoảng trống (gap) và không bị trùng lặp.
  - **Response 200 OK**:
    ```json
    {
      "status": "ok"
    }
    ```

- **DELETE /api/contacts/{contact_id}**
  - **Quyền**: Chỉ chủ hộ (`owner`).
  - **Cơ chế hoạt động**:
    - Khi xóa một liên hệ, backend sẽ tự động cập nhật giảm thứ tự ưu tiên của các liên hệ còn lại để lấp khoảng trống (ví dụ: đang có priority `[1, 2, 3]`, xóa liên hệ thứ `2` thì liên hệ thứ `3` sẽ tự động chuyển thành thứ `2`).
  - **Response 200 OK**:
    ```json
    {
      "status": "ok"
    }
    ```

---

### 3.12 Tạo mã mời thành viên mới (`POST /api/households/invite`)
Sinh mã mời ngẫu nhiên có hiệu lực trong 24 giờ. Chỉ áp dụng cho tài khoản có vai trò `owner` của hộ gia đình đó. Mặc định sử dụng `active_household_id` của người gọi (hoặc gửi `household_id` tùy chọn trong request body).

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Request Body (Optional)**:
```json
{
  "household_id": "household-uuid"
}
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
Lấy thông tin hộ gia đình đang active (`active_household_id`) của user hiện tại cùng với vai trò (`role`) tương ứng của họ. Nếu chưa thiết lập active household, backend tự động thiết lập và fallback về hộ đầu tiên tham gia.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "household_id": "household-uuid",
  "role": "owner", // Hoặc "member"
  "name": "Nha Ba Me",
  "elderly_name": "Nguyen Van A",
  "address": "123 Nguyen Trai",
  "created_at": "2026-06-19T03:00:00.000Z"
}
```

---

### 3.13a Tạo hộ gia đình mới (`POST /api/households`)
Đăng ký một hộ gia đình mới và tự động thiết lập làm hộ gia đình hoạt động của user hiện tại với vai trò `owner`.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
Content-Type: application/json
```
- **Request Body**:
```json
{
  "name": "Nha Ba Me",
  "elderly_name": "Nha ong ba Nguyen",
  "address": "123 Nguyen Trai"
}
```
- **Response 201 Created**:
```json
{
  "id": "household-uuid",
  "name": "Nha Ba Me",
  "elderly_name": "Nha ong ba Nguyen",
  "address": "123 Nguyen Trai",
  "role": "owner",
  "created_at": "2026-06-19T03:00:00.000Z"
}
```

---

### 3.13b Danh sách hộ gia đình của user (`GET /api/households`)
Liệt kê toàn bộ hộ gia đình mà user hiện tại đang tham gia, kèm thông tin vai trò và cờ `is_active`.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "households": [
    {
      "id": "household-uuid",
      "name": "Nha Ba Me",
      "elderly_name": "Nha ong ba Nguyen",
      "address": "123 Nguyen Trai",
      "role": "owner",
      "is_active": true
    }
  ],
  "active_household_id": "household-uuid"
}
```

---

### 3.13c Chuyển đổi hộ gia đình hoạt động (`POST /api/users/switch-household`)
Chuyển đổi hộ gia đình active hiện tại của user. Chỉ thành viên của hộ gia đình đích mới được phép switch.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
Content-Type: application/json
```
- **Request Body**:
```json
{
  "household_id": "household-uuid"
}
```
- **Response 200 OK**:
```json
{
  "active_household_id": "household-uuid"
}
```

---

---

### 3.13d Cập nhật thông tin hộ gia đình (`PATCH /api/households/{household_id}`)
Cập nhật thông tin hộ gia đình (Partial Update). Chỉ áp dụng cho tài khoản chủ hộ (`owner`).

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
Content-Type: application/json
```
- **Request Body**:
```json
{
  "name": "Nha Ong Ba Ngoai",
  "elderly_name": "Ong Nguyen Van A",
  "address": "456 Tran Hung Dao"
}
```
*(Các trường đều là tùy chọn. Cần gửi ít nhất 1 trường)*

- **Response 200 OK**:
```json
{
  "id": "household-uuid",
  "name": "Nha Ong Ba Ngoai",
  "elderly_name": "Ong Nguyen Van A",
  "address": "456 Tran Hung Dao",
  "created_at": "2026-06-19T03:00:00Z"
}
```

---

### 3.13e Mời thành viên bằng Email (`POST /api/households/invite-by-email`)
Mời người dùng tham gia hộ gia đình bằng địa chỉ Email của họ. Chỉ áp dụng cho chủ hộ (`owner`).

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
Content-Type: application/json
```
- **Request Body**:
```json
{
  "household_id": "household-uuid",
  "email": "user@example.com"
}
```
- **Response 201 Created**:
```json
{
  "invite_request_id": "invite-uuid",
  "invitee_id": "user-uuid",
  "status": "pending"
}
```

---

### 3.13f Lấy danh sách lời mời đang chờ xử lý (`GET /api/households/invite-requests/pending`)
Lấy toàn bộ các lời mời vào hộ gia đình đang ở trạng thái `pending` của người dùng hiện tại.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "items": [
    {
      "id": "invite-uuid",
      "household_id": "household-uuid",
      "household_name": "Nha Ba Me",
      "elderly_name": "Nguyen Van A",
      "invited_by_name": "Chủ Hộ A",
      "invited_by_email": "owner@example.com",
      "status": "pending",
      "created_at": "2026-06-24T08:00:00Z"
    }
  ],
  "total": 1
}
```

---

### 3.13g Trả lời lời mời gia đình (`POST /api/households/invite-requests/{invite_id}/respond`)
Đồng ý hoặc từ chối lời mời gia đình. Nếu đồng ý (`accepted`), người dùng được tự động thêm vào `household_members` với quyền `member` và danh sách liên hệ khẩn cấp `contacts` của hộ gia đình đó.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
Content-Type: application/json
```
- **Request Body**:
```json
{
  "action": "accepted" // Hoặc "declined"
}
```
- **Response 200 OK**:
```json
{
  "status": "accepted"
}
```

---

### 3.13h Lấy danh sách thành viên hộ gia đình (`GET /api/households/{household_id}/members`)
Lấy danh sách tất cả các thành viên hiện tại thuộc hộ gia đình (kèm thông tin liên hệ khẩn cấp của họ nếu có). Áp dụng cho cả chủ hộ (`owner`) và thành viên (`member`).

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "members": [
    {
      "user_id": "user-uuid",
      "full_name": "Nguyen Van B",
      "email": "member@example.com",
      "phone": "0987654321",
      "role": "member",
      "joined_at": "2026-06-24T08:00:00.000Z",
      "is_in_contacts": true,
      "contacts_priority": 1
    }
  ],
  "total": 1
}
```

---

### 3.14 Đăng ký camera mới (`POST /api/cameras`)
Đăng ký camera mới cho hộ gia đình. Chỉ áp dụng cho tài khoản chủ hộ (`owner`).

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Request Body**:
```json
{
  "household_id": "household-uuid",
  "name": "Camera Phòng Khách",
  "room": "living-room",
  "fps": 15,
  "serial_number": "SN12345678" // (Tùy chọn)
}
```
*(Nếu `serial_number` trùng với một camera đang hoạt động khác, API sẽ trả về lỗi `409 Conflict` với body `{"error": {"code": "DUPLICATE_SERIAL", "message": "..."}}`)*

- **Response 21Created**:
Trả về thông tin camera cùng mã API Key để điền vào thiết bị biên (Edge Device). **Plaintext key chỉ được hiển thị 1 lần duy nhất này**.
```json
{
  "camera_id": "camera-uuid",
  "name": "Camera Phòng Khách",
  "room": "living-room",
  "serial_number": "SN12345678",
  "device_api_key": "sg_live_xxxxxx...",
  "warning": "Lưu lại key này ngay — sẽ không hiển thị lại được"
}
```

---

### 3.15 Lấy danh sách camera (`GET /api/cameras`)
Lấy toàn bộ danh sách các camera đang hoạt động trong một hộ gia đình. Thành viên hoặc chủ hộ đều có quyền gọi.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Query Parameters**:
  - `household_id`: ID hộ gia đình cần lấy danh sách camera.
- **Response 200 OK**:
*(Lưu ý: Không bao giờ trả về trường device_api_key hoặc hash của nó để bảo mật)*
```json
[
  {
    "id": "camera-uuid",
    "name": "Camera Phòng Khách",
    "room": "living-room",
    "status": "unknown", // "online", "offline", hoặc "unknown"
    "fps": 15,
    "last_heartbeat": null,
    "created_at": "2026-06-16T09:00:00Z"
  }
]
```

---

### 3.15a Lấy thông tin chi tiết camera (`GET /api/cameras/{camera_id}`)
Lấy thông tin chi tiết của 1 camera. Thành viên hoặc chủ hộ đều có quyền gọi.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "id": "camera-uuid",
  "name": "Camera Phòng Khách",
  "room": "living-room",
  "status": "online",
  "fps": 15,
  "last_heartbeat": "2026-06-20T10:00:00Z",
  "created_at": "2026-06-16T09:00:00Z"
}
```

---

### 3.16 Đổi mã kết nối camera mới (`PATCH /api/cameras/{camera_id}/rotate-key`)
Sinh một mã API Key mới cho thiết bị Edge (dùng khi nghi ngờ rò rỉ mã cũ). Chỉ áp dụng cho tài khoản chủ hộ (`owner`).

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
Trả về mã kết nối plaintext mới duy nhất 1 lần. **Khóa cũ sẽ bị vô hiệu hóa ngay lập tức**.
```json
{
  "camera_id": "camera-uuid",
  "device_api_key": "sg_live_newkey_xxxxxx...",
  "warning": "Lưu lại key này ngay — sẽ không hiển thị lại được"
}
```

---

### 3.17 Xóa camera (`DELETE /api/cameras/{camera_id}`)
Gỡ camera khỏi hộ gia đình (sử dụng soft-delete để không làm hỏng khóa ngoại dữ liệu cảnh báo cũ). Chỉ chủ hộ (`owner`) được quyền gọi.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Response 200 OK**:
```json
{
  "status": "ok"
}
```

---

### 3.18 Sửa thông tin camera (`PATCH /api/cameras/{camera_id}`)
Sửa đổi thông tin cơ bản của camera (không đổi mã key qua đây). Chỉ chủ hộ (`owner`) được quyền gọi.

- **Headers**:
```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```
- **Request Body**:
```json
{
  "name": "Camera Phòng Khách VIP",
  "room": "living-room-vip",
  "fps": 10,
  "serial_number": "SN87654321" // (Tùy chọn)
}
```
*(Nếu `serial_number` trùng với một camera đang hoạt động khác, API sẽ trả về lỗi `409 Conflict` với body `{"error": {"code": "DUPLICATE_SERIAL", "message": "..."}}`)*
- **Response 200 OK**:
```json
{
  "status": "ok"
}
```

### 3.19 Lấy presigned URL để upload clip (`POST /api/cameras/upload-url`)
Lấy địa chỉ URL dùng một lần để tải lên clip sự kiện (video phát hiện té ngã đã làm mờ). Thiết bị camera sử dụng header `X-Device-Key` để xác thực.

- **Headers**:
```http
X-Device-Key: <plain-text-device-api-key>
```
- **Request Body**:
```json
{
  "filename": "EVT-20260613-001_blur.mp4",
  "content_type": "video/mp4"
}
```
- **Response 200 OK**:
```json
{
  "upload_url": "https://xxxx.supabase.co/storage/v1/object/sign/clips/...?token=...",
  "clip_path": "clips/household-uuid/EVT-20260613-001_blur.mp4",
  "expires_in": 300
}
```

---

### 3.20 Gửi báo hiệu trạng thái hoạt động (Heartbeat) (`POST /api/cameras/{camera_id}/heartbeat`)
Gửi tín hiệu báo camera còn hoạt động, cập nhật trạng thái `online` và cập nhật chỉ số fps thực tế. Thiết bị camera sử dụng header `X-Device-Key` để xác thực. `camera_id` trên path phải khớp với ID camera được xác thực bởi key, nếu không khớp sẽ trả về lỗi `403 Forbidden`.

- **Headers**:
```http
X-Device-Key: <plain-text-device-api-key>
```
- **Request Body (Tùy chọn)**:
```json
{
  "fps": 15
}
```
- **Response 200 OK**:
```json
{
  "status": "ok",
  "last_heartbeat": "2026-06-17T03:12:35+07:00"
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

---

## 5. Cơ Chế Cuộc Gọi Khẩn Cấp Tự Động (Auto-Call) & Leo Thang Cảnh Báo

Để đảm bảo an toàn tối đa cho người cao tuổi, hệ thống tích hợp cơ chế tự động gọi điện thoại qua Twilio đối với các cảnh báo khẩn cấp:

### 5.1 Xử lý đối với sự kiện CRITICAL (Cực kỳ nguy hiểm)
1. **Cuộc gọi tự động tức thì**: Ngay khi hệ thống phát hiện sự cố `CRITICAL` (ví dụ: bất động trên 5 phút), backend sẽ tự động thực hiện cuộc gọi Twilio đồng thời tới số điện thoại của **tất cả thành viên liên hệ (contacts)** trong gia đình.
2. **Cơ chế gọi lại tự động (Retry Job)**: Nếu sự kiện vẫn ở trạng thái `pending` (người nhà chưa bấm Xác nhận hoặc Bỏ qua trên ứng dụng), sau mỗi 2 phút, backend sẽ tự động thực hiện cuộc gọi lại cho toàn bộ liên hệ trong gia đình cho đến khi cảnh báo được xử lý.

### 5.2 Xử lý leo thang đối với sự kiện HIGH (Nguy hiểm)
1. **Thông báo đẩy (Push Notification)**: Gửi cảnh báo tức thì tới người liên hệ chính (Primary Contact).
2. **Leo thang sau 3 phút**: Nếu sau 3 phút kể từ khi phát hiện sự kiện mà người liên hệ chính chưa xác nhận, hệ thống sẽ thực hiện cuộc gọi VoIP (Twilio) tới người liên hệ phụ tiếp theo (contacts[1]) để cảnh báo.

