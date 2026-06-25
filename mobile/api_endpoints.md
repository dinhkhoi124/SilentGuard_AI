# Danh sách API Endpoints đang được sử dụng trong App

Dưới đây là tổng hợp tất cả các API endpoints được tìm thấy trong source code, được phân chia theo từng chức năng kèm theo các trường (fields) đang được ứng dụng sử dụng.

## 1. Xác thực & Người dùng (Authentication & User)

### **Đăng nhập**
- **Endpoint**: `POST /api/users/login`
- **Headers**:
  - `X-Invite-Code` (tùy chọn - nếu người dùng tham gia qua mã mời)
- **Body**: Không có
- **Response Fields (ánh xạ vào model)**:
  - `id`
  - `firebase_uid` (hoặc `uid`)
  - `full_name` (tùy chọn)
  - `email`
  - `role`

### **Đăng xuất**
- **Endpoint**: `POST /api/users/logout`
- **Body**: Không có

### **Đăng ký FCM Token**
- **Endpoint**: `POST /api/users/device-token`
- **Body**:
  - `fcm_token`

---

## 2. Quản lý hộ gia đình (Households)

### **Lấy thông tin hộ gia đình hiện tại**
- **Endpoint**: `GET /api/households/me`
- **Response Fields (ánh xạ vào model)**:
  - `household_id`
  - `role`
  - `elderly_name` (tùy chọn)

### **Lấy danh sách thành viên trong hộ gia đình**
- **Endpoint**: `GET /api/households/{householdId}/members`
- **Response Fields**: Trả về danh sách đối tượng `HouseholdMember`.

### **Mời thành viên qua Email**
- **Endpoint**: `POST /api/households/invite-by-email`
- **Body**:
  - `email`
  - `household_id`

### **Lấy danh sách lời mời đang chờ (Pending Invites)**
- **Endpoint**: `GET /api/households/invite-requests/pending`
- **Response Fields**: Trả về danh sách đối tượng `InviteRequest`.

### **Phản hồi lời mời (Chấp nhận/Từ chối)**
- **Endpoint**: `POST /api/households/invite-requests/{inviteRequestId}/respond`
- **Body**:
  - `action` (Ví dụ: `accept`, `reject`)

---

## 3. Quản lý Thiết bị / Camera (Devices)

### **Lấy danh sách thiết bị đã ghép nối (Paired Devices)**
- **Endpoint**: `GET /api/cameras`
- **Query Params**:
  - `household_id`
- **Response Fields (các trường app đọc từ JSON)**:
  - `camera_id` (hoặc `device_id`, `id`)
  - `display_name` (hoặc `name`)
  - `ip_address` (hoặc `ip`)
  - `rtsp_url` (hoặc `stream_url`)
  - `status`
  - `room` (hoặc `location`)
  - `is_armed` (hoặc `armed`)
  - `accessories`
  - `accessory_states`
  - `model` (hoặc `model_name`)
  - `serial_number` (hoặc `serial`, `sn`, `SN`)
  - `product_id` (hoặc `pid`, `PID`)

### **Đăng ký / Thêm Camera mới**
- **Endpoint**: `POST /api/cameras`
- **Body**:
  - `household_id`
  - `name` (tên hiển thị)
  - `room` (mặc định gửi `unknown`)
  - `fps` (mặc định gửi `15`)
  - `serial_number`

### **Xóa Camera**
- **Endpoint**: `DELETE /api/cameras/{deviceId}`
- **Body**: Không có

---

## 4. Sự kiện & Cảnh báo (Events & Alerts)

### **Lấy lịch sử sự kiện (Reports)**
- **Endpoint**: `GET /api/events/history`
- **Query Params**:
  - `household_id`
  - `page`
  - `page_size`
  - `severity` (tùy chọn)
  - `room` (tùy chọn)
  - `from_date` (tùy chọn)
  - `to_date` (tùy chọn)
- **Response Fields**:
  - `event_id`, `severity`, `confidence`, `timestamp`, `duration_sec`, v.v.

### **Upload Video Sự kiện**
- **Endpoint**: `POST /api/events/upload-video` (Gửi dưới dạng Multipart request)
- **Fields**:
  - `household_id`
  - `file` (file video)
- **Response Fields**:
  - `upload_id`

### **Gửi phản hồi cho một Sự kiện (Event Feedback)**
- **Endpoint**: `POST /api/events/{eventId}/feedback`
- **Body**:
  - `label` (nhãn phản hồi, ví dụ: fall_confirmed, no_fall, v.v.)
  - `note` (tùy chọn)

### **Xử lý Cảnh báo (Alert Review)**
- **Endpoint**: `PATCH /api/alerts/{eventId}/review`
- **Body**:
  - `action` (hành động xử lý, vd: `dismissed`)
  - `note` (tùy chọn)
  - `feedback_label` (tùy chọn)
  - `false_positive_reason` (tùy chọn)
  - `clip_timestamp` (tùy chọn)
