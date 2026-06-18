# Hướng Dẫn Tích Hợp Video Upload & Detect Cho AI Engineer (Demo Flow)

Tài liệu này hướng dẫn AI Engineer (Kaggle / Local) cách tích hợp luồng upload video giả lập camera stream cho mục đích Demo và các lưu ý kỹ thuật (Technical Debt) cần xử lý trước khi đưa vào sản xuất (Production).

---

## 1. Luồng Hoạt Động (Demo Flow)

Do demo sử dụng video upload thay vì camera stream thời gian thực, luồng sự kiện được thiết kế như sau:

```
[Web/App Client] 
     │  POST /api/events/upload-video (Firebase User Token)
     ▼
[Backend] (Lưu video vào Supabase Storage 'clips', tạo token)
     │  Trả về: { "upload_token": "vid_xxx", "video_url": "https://..." }
     ▼
[Client] (Nhận kết quả và chuyển thông tin cho AI Engine để xử lý)
     │
     ▼
[AI Engineer / AI Server] (Xử lý video phát hiện té ngã)
     │
     ├─► [Trường hợp NORMAL (Không có ngã)]: Im lặng, KHÔNG gọi API nào lên backend.
     │
     └─► [Trường hợp HIGH (Có té ngã)]:
           POST /api/events/detect
           Header: X-Upload-Token: vid_xxx
           Body: { "severity": "HIGH", "confidence": 0.91, "clip_url": "..." }
```

---

## 2. API Specifications

### 2.1 API Upload Video (`POST /api/events/upload-video`)
Dành cho Client (App/Web) tải video lên để demo.
- **Xác thực**: Firebase Bearer Token (`Authorization: Bearer <idToken>`).
- **Body**: `multipart/form-data`
  - `household_id` (Form Field): UUID của hộ gia đình.
  - `file` (Form Field): Tệp tin video (`.mp4`, `.webm`, v.v.).
- **Response 201 Created**:
  ```json
  {
    "upload_id": "video-upload-uuid",
    "video_url": "https://supabase-signed-url-valid-for-1-year...",
    "upload_token": "vid_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }
  ```

### 2.2 API Đưa Kết Quả Phân Tích (`POST /api/events/detect`)
Dành cho AI Engineer gọi khi phát hiện sự kiện té ngã ở trạng thái **HIGH**.
- **Xác thực**: Đính kèm `X-Upload-Token` nhận được từ luồng upload thay vì `X-Device-Key`.
- **Headers**:
  ```http
  X-Upload-Token: vid_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  Content-Type: application/json
  ```
- **Body**:
  ```json
  {
    "event_id": "EVT-UNIQUE-STRING",
    "event_type": "fall",
    "severity": "HIGH",
    "confidence": 0.91,
    "timestamp": "2026-06-18T16:00:00Z",
    "room": "bedroom",
    "clip_url": "<nhận từ video_url của bước upload>",
    "model_ver": "v1.0.0"
  }
  ```
- **Xử lý đặc biệt cho Demo**:
  - Không cần truyền `duration_sec`. Backend tự động ép default thành `999` để đưa vào nhóm ưu tiên cao nhất qua Alert Engine.
  - Backend bỏ qua bước tính toán lại độ nghiêm trọng (reclassify severity) dựa trên thời gian thực — giữ nguyên severity = `"HIGH"`.

---

## 3. Nhật Ký Nợ Kỹ Thuật (Technical Debt Checklist)

Dưới đây là các phần chỉ phục vụ cho bản Demo cần phải sửa đổi/loại bỏ trước khi lên môi trường Production thực tế:

- [ ] **Xác thực qua X-Upload-Token**:
  - *Hiện tại (Demo)*: Cho phép bypass xác thực camera thật bằng cách sử dụng `X-Upload-Token` lấy từ bảng `video_uploads`.
  - *Sản xuất (Production)*: Xóa bỏ hoàn toàn nhánh kiểm tra `X-Upload-Token` trong route `/api/events/detect`, chỉ cho phép `X-Device-Key` để bảo mật thiết bị biên.
- [ ] **Dọn dẹp video & Quản lý vòng đời Token**:
  - *Hiện tại (Demo)*: `upload_token` không có hạn sử dụng và các video tải lên Supabase Storage qua demo chưa được tự động dọn dẹp (cleanup).
  - *Sản xuất (Production)*: Thêm cơ chế hết hạn cho `upload_token` (ví dụ sau 1 giờ) và tự động xóa video sau khi xử lý thành công hoặc thất bại qua scheduler.
- [ ] **Bypass Severity Reclassification**:
  - *Hiện tại (Demo)*: Khi `source` là `video_upload`, backend bypass hoàn toàn việc tính toán lại `severity` dựa trên `duration_sec`.
  - *Sản xuất (Production)*: Mọi luồng sự kiện phải đi qua Severity Engine để chuẩn hóa mức độ cảnh báo nhằm tránh sai sót báo động ảo.
- [ ] **Lưu Trữ Signed URL Quá Hạn**:
  - *Hiện tại (Demo)*: Tạo signed URL có thời hạn 1 năm để tiện demo.
  - *Sản xuất (Production)*: Sử dụng signed URL ngắn hạn (5 phút) sinh động khi client request qua endpoint `GET /api/events/{id}`.
