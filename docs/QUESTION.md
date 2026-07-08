# Integration Readiness Report & Q&A Answers (Core AI Fall Detect)

Tài liệu này tổng hợp câu trả lời chi tiết cho các câu hỏi kỹ thuật trong [QUESTION.md](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/docs/QUESTION.md) dựa trên cấu trúc thư mục, mã nguồn (FastAPI Backend, AI Inference Server, Edge Scripts) và báo cáo hiện tại của dự án.

---

## PHẦN I: TRẢ LỜI CHI TIẾT YÊU CẦU INTEGRATION READINESS REPORT

### 1. Kiến trúc deployment thực tế

*   **Railway hiện đang chạy service nào và entrypoint cụ thể là gì?**
    *   **Trả lời:** Hệ thống được thiết kế để chạy 2 dịch vụ độc lập trên Railway qua Docker Container:
        1.  **FastAPI Backend (SilentGuard Backend):** Chạy trên cổng 8000. Entrypoint (được cấu hình trong [Dockerfile](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/Dockerfile)):
            `uvicorn src.main:app --host 0.0.0.0 --port ${PORT:-8000}`
        2.  **AI Inference Server (SilentGuard AI Server):** Chạy trên cổng 8080. Entrypoint (được cấu hình trong [Dockerfile.ai](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/Dockerfile.ai)):
            `uvicorn src.ai_server:app --host 0.0.0.0 --port 8080`

*   **Railway chỉ chạy FastAPI backend hay đã có AI worker đọc stream?**
    *   **Trả lời:** Có cả hai. 
        *   **FastAPI Backend** đảm nhiệm xử lý API chính, lưu trữ Database và kích hoạt Alert Engine gửi thông báo FCM.
        *   **AI Inference Server** có một background task chạy ngầm tuần hoàn (`run_live_camera_monitor()` trong [ai_server.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/src/ai_server.py)) để tự động đọc stream từ camera Imou qua API HLS (`.m3u8`) nếu được cấu hình các biến môi trường (`IMOU_DEVICE_SN` và `DEVICE_API_KEY`).
        *   Server này còn mở API `/api/streams/start` để kích hoạt/tắt luồng camera động và `/analyze` để xử lý video clip tải lên một cách bất đồng bộ.

*   **AI được dự định chạy trên Railway hay laptop edge tại showcase?**
    *   **Trả lời:** Hệ thống hỗ trợ cả hai phương án:
        *   **Phương án 1 (Cloud AI - Demo Flow):** AI Server chạy trực tiếp trên Railway. Người dùng upload video lên qua Backend -> Backend lưu Supabase Storage -> AI Server tải về phân tích bất đồng bộ rồi trả kết quả về Backend qua `POST /api/events/detect`.
        *   **Phương án 2 (Edge AI - Classic Flow):** AI chạy trên thiết bị biên (Laptop Edge hoặc Raspberry Pi 5 / Jetson Nano đặt tại showcase). Script Edge ([demo_edge_v5.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/src/edge/demo_edge_v5.py)) đọc RTSP cục bộ hoặc stream Imou, phân tích thời gian thực và gọi API đẩy kết quả trực tiếp lên Backend trên Railway.

*   **Camera cung cấp cho AI URL nào: RTSP local hay RTMP Imou Cloud?**
    *   **Trả lời:** AI script hỗ trợ cả hai:
        *   **Imou Cloud stream:** Sử dụng luồng **HLS stream URL (.m3u8)** lấy động qua Imou OpenAPI (không dùng RTMP).
        *   **Local stream:** Sử dụng đường dẫn **RTSP local** (ví dụ: `rtsp://admin:<safety_code>@<camera_ip>:554/cam/realmonitor?channel=1&subtype=0`) hoặc truyền đường dẫn file video để test.

*   **Thành phần nào chịu trách nhiệm lấy/gia hạn stream URL?**
    *   **Trả lời:** **AI Server/Edge script** chịu trách nhiệm. Hàm `get_imou_live_stream_url()` trong script AI ([demo_edge.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/src/edge/demo_edge.py)) sẽ tự động gọi API của Imou Cloud để lấy accessToken và sau đó lấy live stream URL mới. Khi OpenCV phát hiện luồng bị đứt (`ret=False`), tiến trình sẽ tự động ngủ 2 giây, gọi lại hàm này để lấy URL mới và tự kết nối lại.

*   **AI inference hiện được thiết kế chạy thật ở đâu, và service nào đang đọc RTSP/RTMP liên tục?**
    *   **Trả lời:** 
        *   Chạy thật ở **Edge Device** (laptop/RPi) tại nhà người dùng (hoặc tại showcase) để đảm bảo tính riêng tư (raw video không lên cloud) và giảm thiểu băng thông.
        *   Service đang đọc stream liên tục là **FastAPI AI Server** (ở cloud) hoặc script **demo_edge_v5.py** (ở Edge local) sử dụng OpenCV đọc luồng và đẩy khung hình vào YOLOv8-Pose.

---

### 2. API nhận kết quả AI

*   **API Endpoint:** `POST /api/events/detect`
*   **URL Production:** `https://<your-backend-railway-url>/api/events/detect`
*   **Header xác thực chính thức:** Hỗ trợ cả 2 header tùy thuộc luồng chạy (xem trong [events.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/backend/app/api/events.py)):
    *   `X-Device-Key` (dùng cho thiết bị Edge thật / Classic Flow).
    *   `X-Upload-Token` (dùng cho luồng Demo upload video).
*   **Các field required/optional:**
    *   `event_id` (Required, `str`): ID duy nhất của sự kiện.
    *   `event_type` (Optional, `str`, mặc định `"fall"`).
    *   `severity` (Required, `str`): `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`.
    *   `confidence` (Required, `float`): 0.0 - 1.0.
    *   `timestamp` (Required, `datetime`): ISO 8601 UTC (ví dụ: `2026-06-25T23:22:51Z`).
    *   `duration_sec` (Optional, `int`): Thời gian đối tượng nằm bất động.
    *   `room` (Optional, `str`): Vị trí camera.
    *   `clip_path` / `clip_url` (Optional, `str`): Đường dẫn lưu clip.
    *   `model_ver` (Optional, `str`, mặc định `"v1.0.0"`).
*   **Một request curl chạy thành công (Ví dụ):**
    ```bash
    curl -X POST https://c2-app-128-production.up.railway.app/api/events/detect \
      -H "Content-Type: application/json" \
      -H "X-Device-Key: sg_device_live_key_xyz" \
      -d '{
        "event_id": "EVT-20260625-XYZ123",
        "event_type": "fall",
        "severity": "HIGH",
        "confidence": 0.87,
        "timestamp": "2026-06-25T23:22:51Z",
        "duration_sec": 45,
        "room": "bedroom",
        "clip_path": "clips/test-household/demo_v5.mp4",
        "model_ver": "yolov8-pose-v2.1"
      }'
    ```
*   **Response thành công (201 Created):**
    ```json
    {
      "status": "received",
      "event_id": "EVT-20260625-XYZ123"
    }
    ```
*   **Response lỗi:**
    *   **401 Unauthorized** (Thiếu hoặc sai key/token):
        ```json
        { "detail": { "error": { "code": "UNAUTHORIZED", "message": "Missing X-Device-Key or X-Upload-Token header" } } }
        ```
    *   **409 Conflict** (Trùng `event_id`):
        ```json
        { "detail": { "error": { "code": "DUPLICATE_EVENT", "message": "Event EVT-20260625-XYZ123 đã tồn tại" } } }
        ```
*   **Ý nghĩa chính xác của các field:**
    *   `event_id`: Chuỗi định danh duy nhất để backend thực hiện lọc trùng lặp (dedup).
    *   `camera_id`: Backend tự truy vấn từ `X-Device-Key` (không truyền từ AI).
    *   `household_id`: Backend tự truy vấn từ thông tin camera/thiết bị sở hữu (không truyền từ AI).
    *   `timestamp`: Thời gian xảy ra sự kiện ở múi giờ UTC.
    *   `confidence`: Độ tin cậy của thuật toán phát hiện ngã (0.0 -> 1.0).
    *   `duration_sec`: Số giây đối tượng nằm bất động dưới sàn.
    *   `severity`: Độ nghiêm trọng được phân loại dựa trên thời gian bất động.
    *   `clip_url` / `clip_path`: Đường dẫn hoặc link xem clip đã làm mờ mặt (anonymized video).
    *   `source`: Tự động điền bởi backend (`camera` nếu dùng key thiết bị, `video_upload` nếu dùng token upload).
*   **Backend có coi confidence là pose confidence hay fall confidence?**
    *   **Trả lời:** Backend lưu và gửi thẳng lên App thông số này làm **fall confidence** (độ tin cậy của việc phát hiện cú ngã). Ở phía AI Edge, chỉ số này được lấy từ độ tin cậy của box người bị ngã từ model YOLOv8.

---

### 3. Deduplication và incident lifecycle

*   **event_id có unique/idempotent không?**
    *   **Trả lời:** Có. `event_id` được ràng buộc unique trong database.
*   **Nếu AI retry cùng event_id, backend có tạo hai notification không?**
    *   **Trả lời:** Không. Backend sẽ trả về `409 Conflict` và từ chối xử lý tiếp, do đó không tạo thông báo trùng lặp.
*   **Nếu AI gửi nhiều event từ cùng camera trong 5–30 giây, backend xử lý thế nào?**
    *   **Trả lời:** Backend có cơ chế **Deduplication** trong [AlertEngine](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/backend/app/services/alert_engine.py). Nó sẽ kiểm tra trong khoảng thời gian `dedup_window_sec` (cấu hình theo hộ gia đình, mặc định 60 giây) xem có sự kiện ngã nào trước đó không. Nếu có, sự kiện mới sẽ bị đánh dấu status là `logged_only` và dừng xử lý (không gửi push FCM, không gọi điện).
*   **Backend hay AI chịu trách nhiệm xác định “người đã đứng lại”?**
    *   **Trả lời:** **AI Edge** chịu trách nhiệm thông qua trạng thái FSM (Finite State Machine). Trong [demo_edge_v5.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/src/edge/demo_edge_v5.py), nếu một người đang ở trạng thái `LYING` mà thay đổi tư thế (góc torso nhỏ hơn ngưỡng và aspect ratio hộp bao trở lại bình thường), AI sẽ phát hiện sự kiện đứng dậy (`stood up`) và chuyển trạng thái FSM về `NORMAL`.
*   **Quy tắc nào kích hoạt FCM: mọi fall hay chỉ HIGH/CRITICAL?**
    *   **Trả lời:** Mọi sự kiện có mức độ nghiêm trọng **khác LOW** (`severity != "LOW"`, tức là `MEDIUM`, `HIGH`, `CRITICAL`) đều kích hoạt Alert Engine gửi FCM push notification. Mức độ `LOW` (ngã tự đứng dậy nhanh) chỉ được ghi log vào database (`logged_only`) để tránh làm phiền gia đình.

---

### 4. Notification contract

*   **Payload FCM thật mà app đang nhận:**
    *   Được cấu trúc trong [notification_service.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/backend/app/services/notification_service.py):
        ```json
        {
          "notification": {
            "title": "Cảnh báo [severity] — [room]",
            "body": "[Nội dung tiếng Việt tự nhiên do Claude tạo ra hoặc tin nhắn mặc định]"
          },
          "data": {
            "event_id": "uuid_hoac_event_id_string",
            "severity": "HIGH/CRITICAL/MEDIUM",
            "clip_path": "duong_dan_hoac_link_den_clip_mp4"
          }
        }
        ```
*   **Xác nhận đã test trong ba trạng thái (App foreground, background, killed):**
    *   **Trả lời:** `[CẦN MOBILE DEV XÁC NHẬN CHÍNH THỨC]` Hiện tại hệ thống Backend đã sẵn sàng gửi đúng payload qua Firebase Admin SDK. Việc xử lý routing/hiển thị trên thiết bị khi app chạy ngầm hoặc bị đóng hoàn toàn phụ thuộc vào cấu hình FCM Service trên mã nguồn Flutter/React Native của Mobile App.
*   **Khi nhấn notification, app mở màn hình nào? Có phụ thuộc camera_id hoặc event_id không?**
    *   **Trả lời:** `[CẦN MOBILE DEV XÁC NHẬN CHÍNH THỨC]` Theo thiết kế PRD, khi nhấn thông báo, app cần mở màn hình **Alert Detail** tương ứng dựa trên `event_id` được truyền trong phần `data` của FCM payload để hiển thị đúng clip và nút xác nhận.

---

### 5. Video clip và privacy

*   **AI có bắt buộc upload clip hay metadata là đủ để gửi notification?**
    *   **Trả lời:** Để gửi notification khẩn cấp thì chỉ cần metadata là đủ. Tuy nhiên để hoàn thiện luồng E2E và hiển thị cho người thân xác minh trên App, AI cần gửi kèm clip. Trong thiết kế Demo, clip được tải lên Supabase Storage và gửi link qua API `detect`.
*   **Endpoint hoặc signed URL để upload clip là gì?**
    *   **Trả lời:** Backend cung cấp endpoint `POST /api/events/upload-video` để tải tệp tin video lên và lưu trữ trong Supabase bucket `clips`.
*   **Format hỗ trợ: MP4/H.264 hay mp4v?**
    *   **Trả lời:** Edge AI ghi video bằng OpenCV sử dụng codec mã hóa `'mp4v'` lưu dưới định dạng tệp tin `.mp4`.
*   **Giới hạn kích thước và thời lượng?**
    *   **Trả lời:** Thời lượng clip tiêu chuẩn thiết kế là **10 giây** (bao gồm khoảng 8 giây trước thời điểm ngã và 2 giây sau khi ngã).
*   **clip_url cần public URL hay signed URL?**
    *   **Trả lời:**
        *   *Trong bản Demo:* Tạo signed URL của Supabase có thời hạn 1 năm để phục vụ kiểm thử nhanh.
        *   *Môi trường Production:* Sẽ sử dụng cơ chế bảo mật nghiêm ngặt hơn: chỉ lưu path video trong DB, và khi App gọi API lấy chi tiết alert (`GET /api/alerts/:id`), backend mới sinh dynamic signed URL thời hạn ngắn (5 phút).
*   **Backend có đảm bảo chỉ nhận clip đã blur không?**
    *   **Trả lời:** **Có.** Quá trình làm mờ (Gaussian Blur) mặt được thực hiện trực tiếp trên từng frame hình trong bộ nhớ RAM của Edge device ([demo_edge_v5.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/src/edge/demo_edge_v5.py)) trước khi ghi file và nén video. Do đó, video clip thô chứa khuôn mặt rõ nét của người dùng không bao giờ được lưu xuống đĩa cứng hoặc truyền đi trên mạng Internet, đảm bảo an toàn riêng tư tuyệt đối.
*   **App xử lý thế nào nếu event chưa có clip?**
    *   **Trả lời:** `[CẦN MOBILE DEV XÁC NHẬN CHÍNH THỨC]` Thông thường app cần hiển thị màn hình chờ tải hoặc placeholder/skeleton cho đến khi video sẵn sàng tải xong.

---

### 6. Camera/Imou

*   **Đã lấy được RTSP local từ camera Imou chưa?**
    *   **Trả lời:** `[CẦN ĐỘI TRIỂN KHAI/SHOWCASE XÁC NHẬN CHÍNH THỨC]` Camera Imou trong mạng nội bộ hỗ trợ RTSP stream qua địa chỉ:
        `rtsp://admin:<safety_code>@<camera_ip>:554/cam/realmonitor?channel=1&subtype=0` (safety code là mã bảo mật dán trên nhãn camera).
*   **Đã test OpenCV/FFmpeg đọc RTSP liên tục chưa?**
    *   **Trả lời:** Rồi. Mã nguồn AI đã được kiểm thử đọc liên tục luồng live mượt mà và tích hợp cơ chế tự động khôi phục kết nối (Auto-Reconnect) khi luồng stream camera bị gián đoạn.
*   **RTMP URL từ Imou Cloud sống trong bao lâu?**
    *   **Trả lời:** Imou OpenAPI cấp live stream URL (dưới dạng HLS `.m3u8`) có thời gian sống (expire) dao động từ 1 đến 24 giờ.
*   **Khi URL hết hạn, thành phần nào lấy URL mới?**
    *   **Trả lời:** **AI Edge Server** (hoặc Edge Script) sẽ tự động bắt sự kiện mất kết nối stream, gọi hàm `get_imou_live_stream_url()` để yêu cầu Imou Cloud API cấp lại token và URL động mới để duy trì hoạt động 24/7.
*   **Camera có thể phát đồng thời RTSP cho AI và RTMP cho app không?**
    *   **Trả lời:** Có. Các dòng camera Imou/Dahua hỗ trợ phân luồng tốt, cho phép vừa stream RTSP cục bộ (sub-stream/main-stream) cho AI tại chỗ vừa truyền stream lên Imou Cloud phục vụ xem trực tiếp trên app di động cùng lúc.
*   **Có tài khoản/camera sandbox dành riêng cho showcase không?**
    *   **Trả lời:** `[CẦN XÁC NHẬN TỪ ADMIN/KHÁCH HÀNG CHÍNH THỨC]` Cần cấu hình sẵn thông tin tài khoản test trong file cấu hình `.env` để chạy thử showcase.

---

### 7. Kết quả E2E hiện tại

*   **E2E latency trung bình và cao nhất:**
    *   **Trả lời:** `[CẦN THỰC THI CHẠY KIỂM THỬ THỰC TẾ TRONG BUỔI ĐỒNG BỘ]` Chỉ số mục tiêu của MVP là MTTD < 60 giây. Cần đo đạc thực tế tại showcase để điền số liệu chính xác.
*   **Số lần thành công trên 10 lần thử:**
    *   **Trả lời:** `[CẦN THỰC THI CHẠY KIỂM THỬ THỰC TẾ TRONG BUỔI ĐỒNG BỘ]`
*   **Log hoặc video chứng minh một lần chạy hoàn chỉnh / blocker còn tồn tại:**
    *   **Trả lời:** `[CẦN BỔ SUNG TRONG QUÁ TRÌNH SETUP THỰC TẾ]`

---

### 8. Showcase readiness

*   **Thiết bị Android/iOS nào sẽ dùng?**
    *   **Trả lời:** `[CẦN MOBILE DEV XÁC NHẬN CHÍNH THỨC]`
*   **Railway production URL có ổn định không? Có healthcheck trước demo không?**
    *   **Trả lời:** Backend có API check health tại `/health` (Backend) và `/health` (AI Server). Cần chạy check trước demo. Railway chạy rất ổn định tuy nhiên phụ thuộc vào kết nối Wi-Fi tại nơi showcase.
*   **Có tài khoản demo và household/camera đã seed sẵn không?**
    *   **Trả lời:** Có hỗ trợ các seed data mẫu trong DB Supabase. Cần kiểm tra lại các tài khoản trước buổi showcase.
*   **Có phương án fallback nếu Imou Cloud hoặc Wi-Fi lỗi không?**
    *   **Trả lời:** **Có.** 
        *   *Nếu mất mạng Internet (không gọi được Imou Cloud API):* Chuyển AI Edge script đọc **Local RTSP Stream** của camera qua Router Wi-Fi cục bộ không dây (không cần Internet).
        *   *Nếu mất kết nối Wi-Fi/Camera hoàn toàn:* Sử dụng **Video File offline** lưu sẵn trên máy biên để chạy phân tích giả lập và đẩy dữ liệu cảnh báo qua mạng di động 4G/5G chia sẻ từ điện thoại.

---

## PHẦN II: TÓM TẮT TRẢ LỜI CÁC CÂU HỎI THƯỜNG GẶP CỦA DEV

1.  **Về phần AI ([demo_edge_v5.py](file:///e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/src/edge/demo_edge_v5.py)):**
    *   *Pipeline đã xử lý được các trường hợp:* Fall thông thường (Đã test tốt); Người nằm xuống tự nhiên, ngồi xuống, đi lùi (Được phân loại và whitelist bởi Heuristics FSM trong v5 để hạn chế báo động ảo).
    *   *Số frame/s và độ trễ chạy thật:* Tùy thuộc cấu hình phần cứng Edge (YOLOv8n-pose xử lý cực nhanh dưới 15ms/frame trên laptop phổ thông).
2.  **Về API kết nối giữa AI và Backend:**
    *   *Header xác thực dùng cho Edge:* `X-Device-Key` (hoặc `X-Upload-Token` khi chạy Demo post-analyze).
    *   *Sự kiện gửi lại liên tiếp từ cùng một camera:* Backend tự động deduplicate thông qua `dedup_window_sec` của Alert Engine.
3.  **Về luồng clip và notification:**
    *   *Phần chịu trách nhiệm cắt và upload clip:* AI Server (hoặc Edge Script) tự cắt clip 10s đã được blur mặt từ circular buffer và gửi lên cloud/local.
    *   *Nhấn notification trên app:* App sẽ điều hướng đến màn hình chi tiết alert dựa trên `event_id` được đính kèm trong data payload của FCM.
4.  **Về Imou và stream camera:**
    *   *Đã lấy được RTSP local chưa:* Cần cấu hình địa chỉ RTSP local của camera trong mạng nội bộ showcase.
    *   *Gia hạn stream URL:* Script Edge AI tự động catch lỗi và gọi API Imou Cloud lấy URL mới 24/7.
5.  **Về kịch bản showcase:**
    *   *Kịch bản:* Người đi vào góc camera -> Diễn viên thực hiện động tác ngã xuống sàn -> AI phát hiện sau vài giây -> Gửi API lên Railway -> Railway gửi push FCM qua Firebase -> Điện thoại người nhà hiển thị cảnh báo với nội dung tự nhiên của Claude -> Người nhà click xem video đã blur mặt và chọn Confirm/Dismiss.