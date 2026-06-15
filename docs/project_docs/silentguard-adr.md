# Architecture Decision Records — SilentGuard AI

> Tài liệu ghi lại các quyết định kiến trúc quan trọng của dự án SilentGuard AI.  
> Mỗi ADR là một bản ghi bất biến. Khi quyết định thay đổi, tạo ADR mới thay vì sửa ADR cũ.

---

## Mục lục

| ID | Tiêu đề | Trạng thái |
|----|---------|------------|
| ADR-001 | Chọn YOLOv8-Pose + Rule-based Classifier cho Fall Detection | Accepted |
| ADR-002 | Chọn FastAPI (Python) thay vì Node.js cho Backend | Accepted |
| ADR-003 | Chọn Supabase cho Database + Storage | Accepted |
| ADR-004 | Chọn Firebase Auth + FCM thay vì tự xây Auth + Push | Accepted |
| ADR-005 | Severity 4 mức thay vì Binary Alert | Accepted |
| ADR-006 | Edge-first Privacy — Raw Video chỉ trong RAM | Accepted |
| ADR-007 | Dùng Claude cho LLM thay vì GPT-4 / Gemini | Accepted |

---

## ADR-001: Chọn YOLOv8-Pose + Rule-based Classifier cho Fall Detection

**Ngày:** 2025-06-10  
**Trạng thái:** Accepted  
**Người quyết định:** Team SilentGuard AI

### Bối cảnh

SilentGuard AI cần phát hiện té ngã thụ động (passive fall detection) cho người cao tuổi sống một mình hoặc cần giám sát. Camera đặt trong phòng khách, phòng ngủ — môi trường riêng tư cao. Hệ thống phải chạy real-time (< 100ms/frame) trên thiết bị edge (Raspberry Pi 5 hoặc Intel NUC) mà không cần kết nối internet liên tục. Accuracy phải đủ cao để không gây alert fatigue (false positive < 5%), đồng thời recall đủ cao để không bỏ sót (false negative < 2% với mức HIGH/CRITICAL).

Yêu cầu cứng:
- Không bao giờ gửi raw video lên cloud
- Latency từ khi ngã đến khi push notification < 10 giây
- Chạy được trên phần cứng edge giá < 5 triệu VNĐ
- Model phải giải thích được (explainable) để debug false positive

### Các lựa chọn

**Lựa chọn 1: Rule-based Velocity / Bounding Box**
- Phát hiện dựa trên tốc độ thay đổi bounding box của người (aspect ratio đổi từ dọc → ngang đột ngột, velocity vector hướng xuống).
- Không cần model AI, chạy cực nhẹ trên mọi phần cứng.
- **Vấn đề:** False positive rất cao với hành động ngồi nhanh, cúi nhặt đồ, trẻ em chạy. Không tách được keypoint → không biết tư thế cụ thể. Accuracy thực tế trên Le2i dataset chỉ ~72%.

**Lựa chọn 2: YOLOv8-Pose + Rule-based Classifier (được chọn)**
- YOLOv8-Pose detect 17 keypoints COCO trên mỗi người. Rule-based classifier tính toán các góc cơ thể (thân người, đầu gối, hông) và velocity vector của các keypoint quan trọng.
- Kết hợp output skeleton với temporal reasoning qua sliding window 30 frame.
- Fine-tune trên URFD + Le2i Fall Detection dataset.

**Lựa chọn 3: VLM Realtime (ví dụ: GPT-4V / Gemini Vision)**
- Gửi frame lên API để nhận phán đoán tự nhiên ngôn ngữ.
- **Vấn đề:** Vi phạm hoàn toàn yêu cầu privacy — raw video lên cloud. Latency API call 500ms–2s, không thể real-time. Chi phí token với 30fps camera là không khả thi (ước tính > 50 USD/ngày/camera). Không hoạt động khi mất internet.

**Lựa chọn 4: VideoMAE / TimeSformer**
- Transformer-based video understanding, state-of-the-art trên UCF101 / Kinetics.
- **Vấn đề:** Yêu cầu GPU inference hoặc NPU mạnh. Trên Raspberry Pi 5 chạy ~ 2–3 fps — không đủ real-time. Model size 300MB–1GB, không phù hợp edge deployment. Không giải thích được, khó debug false positive.

### Quyết định

Chọn **Lựa chọn 2: YOLOv8-Pose + Rule-based Classifier**.

Cụ thể:
- Model: `yolov8n-pose.pt` (nano, 6.5MB) hoặc `yolov8s-pose.pt` (small, 22.6MB) tùy phần cứng
- Inference: OpenCV + Ultralytics Python SDK
- Classifier: Rule-based trên 5 điều kiện keypoint + temporal state machine
- Fine-tune: Transfer learning trên URFD dataset (70 sequences) + Le2i (191 videos)

### Lý do

1. **Privacy by design:** YOLOv8-Pose chỉ output skeleton (17 keypoint tọa độ x,y,confidence) — không phải ảnh. Skeleton không thể reconstruct lại khuôn mặt hay nhận dạng cá nhân. Privacy layer được giải quyết ngay tại bước inference, không cần xử lý thêm.

2. **Hiệu năng đủ dùng:** YOLOv8n-Pose chạy ~30ms/frame (~33fps) trên Raspberry Pi 5 với NCNN backend. YOLOv8s-Pose chạy ~25ms/frame trên Intel NUC. Đủ real-time cho bài toán phát hiện té ngã (không cần 60fps).

3. **Không phụ thuộc cloud:** Toàn bộ inference trên edge. Hoạt động bình thường khi mất internet — critical cho hộ gia đình người cao tuổi ở vùng có mạng không ổn định.

4. **Pretrained tốt:** YOLOv8-Pose đã được train trên COCO với 17 keypoints chuẩn. Keypoints hông, vai, đầu gối, mắt cá đủ để tính góc nghiêng thân người và phát hiện tư thế ngã.

5. **Explainable:** Rule-based classifier output log rõ ràng: "hip_angle=23°, threshold=45°, velocity_y=+180px/s → FALL_DETECTED". Dễ debug false positive, dễ calibrate per-user.

6. **Ecosystem:** Ultralytics YOLOv8 có Python SDK, model export sang NCNN/ONNX/TFLite, tài liệu đầy đủ. Team có thể fine-tune trong 1–2 ngày với URFD dataset.

### Hệ quả

**Tích cực:**
- Privacy layer được xử lý tự nhiên trong pipeline inference
- Có thể chạy offline hoàn toàn
- Debug và calibrate dễ dàng
- Chi phí phần cứng thấp (Raspberry Pi 5: ~2.5 triệu VNĐ)

**Tiêu cực / Cần theo dõi:**
- Cần dataset annotation cho fine-tuning (URFD, Le2i cần download và preprocess)
- Rule-based thresholds cần calibrate per-user (người béo, người gầy có góc keypoint khác nhau)
- Accuracy giảm trong điều kiện ánh sáng yếu — cần test với IR camera hoặc low-light mode
- Occlusion (người bị che khuất một phần) có thể làm mất keypoints → cần fallback logic

---

## ADR-002: Chọn FastAPI (Python) thay vì Node.js cho Backend

**Ngày:** 2025-06-10  
**Trạng thái:** Accepted  
**Người quyết định:** Team SilentGuard AI

### Bối cảnh

Backend của SilentGuard AI cần xử lý các luồng sau:
- Nhận event từ edge device (POST /api/events/detect)
- Trigger alert engine (tính severity, gửi FCM)
- Gọi Claude API để tạo alert message
- Cung cấp REST API cho mobile app
- Upload / serve video clip đã blur lên Supabase Storage

Team có 3 lập trình viên, tất cả quen Python (đã dùng Python cho edge AI service). Thời gian MVP là 2 tuần.

### Các lựa chọn

**Lựa chọn 1: Node.js + Express / Fastify**
- Ecosystem lớn, nhiều package, performance I/O tốt.
- **Vấn đề:** Team phải context-switch giữa Python (edge) và JavaScript (backend). SDK `anthropic` và `firebase-admin` có bản Python chính thức đầy đủ hơn; bản JS ổn nhưng team ít quen. Không có lợi thế rõ ràng so với FastAPI cho bài toán này.

**Lựa chọn 2: FastAPI (Python) (được chọn)**
- Async framework, auto-generate OpenAPI/Swagger docs, type hints với Pydantic.
- Cùng ngôn ngữ với edge service.

**Lựa chọn 3: Django REST Framework**
- Mature, batteries-included, ORM mạnh.
- **Vấn đề:** Quá nặng cho API service nhỏ. Django ORM không cần thiết khi dùng Supabase. Async support kém hơn FastAPI. Boilerplate nhiều, tốn thời gian setup cho MVP 2 tuần.

**Lựa chọn 4: Go + Fiber**
- Performance cao nhất, binary nhỏ, deploy dễ.
- **Vấn đề:** Không ai trong team biết Go. SDK `anthropic` và `firebase-admin` không có bản Go chính thức. Phải tự implement HTTP client cho Anthropic API. Rủi ro quá cao cho timeline 2 tuần.

### Quyết định

Chọn **Lựa chọn 2: FastAPI (Python)**.

Stack cụ thể:
- FastAPI + Uvicorn (ASGI server)
- Pydantic v2 cho data validation
- `httpx` cho async HTTP client (gọi edge, gọi Claude)
- `firebase-admin` Python SDK cho Auth verify + FCM
- `anthropic` Python SDK cho Claude
- `supabase-py` cho Supabase client
- Deploy: Render (free tier) hoặc Railway

### Lý do

1. **Cùng ngôn ngữ với edge:** Edge device chạy Python + YOLOv8. Dùng FastAPI cho backend, team không cần context-switch. Code shared utilities (ví dụ: severity constants, event types) có thể tái sử dụng trực tiếp.

2. **Async native:** FastAPI chạy trên ASGI với `async/await`. Alert engine cần gọi song song Claude API + FCM + Supabase insert — async giúp giảm latency từ ~1.5s xuống ~600ms.

3. **Auto OpenAPI docs:** FastAPI tự generate `/docs` (Swagger UI) và `/redoc` từ type annotations. Mobile dev có thể test API trực tiếp mà không cần Postman collection riêng — tiết kiệm 0.5 ngày trong MVP sprint.

4. **SDK tích hợp tự nhiên:** `firebase-admin`, `anthropic`, `supabase-py` đều có Python SDK chính thức được maintain tốt. Import và dùng trong vài dòng code.

5. **Team quen Python:** Giảm rủi ro bug do unfamiliar syntax trong deadline ngắn. Code review nhanh hơn.

### Hệ quả

**Tích cực:**
- Development speed cao trong 2 tuần đầu
- API docs tự động, mobile dev không bị block
- Shared code giữa edge và backend

**Tiêu cực / Cần theo dõi:**
- Python không tối ưu về memory so với Go/Rust cho concurrent connections lớn — không vấn đề ở quy mô MVP (< 100 device)
- Uvicorn single worker trên Render free tier có thể bị bottleneck nếu demo nhiều camera cùng lúc → scale lên Gunicorn + Uvicorn workers khi cần
- Cần đặt timeout rõ ràng cho tất cả external API calls (Claude, FCM) để tránh request hanging

---

## ADR-003: Chọn Supabase cho Database + Storage

**Ngày:** 2025-06-10  
**Trạng thái:** Accepted  
**Người quyết định:** Team SilentGuard AI

### Bối cảnh

SilentGuard AI cần:
- Lưu trữ events (té ngã detection, severity, timestamp, clip URL)
- Lưu trữ alert reviews (người dùng xác nhận/bác bỏ alert)
- Lưu trữ thông tin device và user
- Lưu video clip đã blur (10 giây/clip, ~5–15MB/clip, H.264)
- Query phức tạp: lấy events trong khoảng thời gian, group by severity, join với device info

Team đã quyết định dùng Firebase Auth + FCM cho authentication và push notification. Câu hỏi là: database và file storage dùng gì?

### Các lựa chọn

**Lựa chọn 1: Firebase Firestore + Firebase Storage**
- Cùng hệ sinh thái với Auth + FCM, SDK đồng nhất.
- **Vấn đề:** Firestore là NoSQL document — data model Event-Review-Device có quan hệ rõ ràng, cần JOIN khi query báo cáo. Query phức tạp trên Firestore cần nhiều index thủ công và denormalization. Không có SQL → khó viết daily report query. Firebase Storage tính phí theo GB download — video clip nhiều sẽ tốn tiền hơn Supabase.

**Lựa chọn 2: Supabase (PostgreSQL + Storage) (được chọn)**
- PostgreSQL với full SQL support. Supabase Storage tương thích S3. Supabase Studio là UI quản lý database và file.
- Free tier: 500MB database, 1GB storage, 5GB bandwidth.

**Lựa chọn 3: PlanetScale (MySQL) + AWS S3**
- PlanetScale là MySQL managed với branching workflow tốt.
- **Vấn đề:** Cần quản lý 2 service riêng biệt (PlanetScale + S3). Chi phí AWS S3 phức tạp cho sinh viên. MySQL thiếu JSONB, array operators — cần cho `emergency_contacts` và `notification_settings`. PlanetScale đã thông báo ngừng free tier.

**Lựa chọn 4: MongoDB Atlas**
- Flexible schema, document-oriented.
- **Vấn đề:** Tương tự Firestore — không phù hợp với relational data model. Aggregation pipeline khó hơn SQL cho báo cáo. Team ít quen MongoDB.

### Quyết định

Chọn **Lựa chọn 2: Supabase (PostgreSQL + Storage)**.

Phân công rõ ràng:
- **Firebase:** Auth (verify identity) + FCM (push notification) — không dùng Firestore, không dùng Firebase Storage
- **Supabase:** PostgreSQL (toàn bộ data) + Storage (video clip đã blur)

### Lý do

1. **PostgreSQL phù hợp data model:** Events có quan hệ với Devices, AlertReviews có quan hệ với Events và Users. SQL JOIN tự nhiên hơn nhiều so với Firestore's subcollection queries. JSONB columns cho `emergency_contacts` và `notification_settings` — tốt nhất của cả hai thế giới (relational + document).

2. **Supabase Studio = built-in log viewer:** Team có thể xem events, query database trực tiếp qua UI mà không cần setup admin panel riêng. Trong giai đoạn MVP, đây là công cụ debug nhanh nhất.

3. **Storage cho video clip:** Supabase Storage cung cấp S3-compatible API, signed URLs, và CDN. Upload clip đã blur từ edge, mobile app tải về qua signed URL (hết hạn sau 1 giờ). Không cần quản lý AWS credentials phức tạp.

4. **Tránh 2 nguồn data song song:** Nếu dùng cả Firestore lẫn Supabase, sẽ có vấn đề về consistency — event được lưu ở đâu? User data ở đâu? Supabase là single source of truth cho tất cả business data.

5. **Free tier đủ cho MVP:** 500MB PostgreSQL đủ cho hàng trăm nghìn events. 1GB Storage đủ cho demo (100 clip × 10MB = 1GB). Không cần upgrade plan trong giai đoạn MVP.

### Hệ quả

**Tích cực:**
- Single source of truth cho business data
- SQL query mạnh cho reporting và dashboard
- Supabase Studio giảm thời gian debug

**Tiêu cực / Cần theo dõi:**
- Backend phải tự verify Firebase ID token bằng `firebase-admin` SDK trước khi query Supabase (không thể dùng Supabase Auth built-in với Firebase token)
- Cần implement middleware `verify_firebase_token()` trong FastAPI — thêm ~0.5 ngày setup
- Supabase free tier giới hạn connection pool 60 connections — cần dùng connection pooling (Supabase tự cung cấp PgBouncer)
- Row Level Security (RLS) của Supabase không áp dụng tự động với Firebase Auth — backend chịu trách nhiệm authorization

---

## ADR-004: Chọn Firebase Auth + FCM thay vì tự xây Auth + Push

**Ngày:** 2025-06-10  
**Trạng thái:** Accepted  
**Người quyết định:** Team SilentGuard AI

### Bối cảnh

SilentGuard AI cần:
- **Authentication:** Người dùng (gia đình, caregiver) đăng nhập vào mobile app. Backend verify identity trước khi trả data.
- **Push Notification:** Khi phát hiện té ngã severity MEDIUM trở lên, gửi push notification tức thì đến điện thoại gia đình — kể cả khi app đang tắt hoàn toàn (background push).

Background push là tính năng critical: nếu app phải mở để nhận thông báo thì hệ thống vô dụng trong thực tế. User có thể ngủ quên không mở app.

### Các lựa chọn

**Lựa chọn 1: Custom JWT + WebSocket**
- Tự implement JWT authentication, dùng WebSocket để push realtime.
- **Vấn đề:** WebSocket không hoạt động khi app bị kill trên iOS/Android (hệ điều hành đóng kết nối). Background push trên iOS/Android bắt buộc đi qua APNs (Apple) và FCM (Google) — không có cách nào bypass. Tự xây auth tốn 3–5 ngày và nhiều edge cases (refresh token, revocation).

**Lựa chọn 2: Firebase Auth + FCM (được chọn)**
- Firebase Auth: Google/Email sign-in, ID token verify bằng `firebase-admin`.
- FCM: Push notification đến iOS + Android, hoạt động khi app tắt hoàn toàn.

**Lựa chọn 3: Auth0 + OneSignal**
- Auth0: Enterprise-grade auth với nhiều tính năng.
- OneSignal: Push notification service.
- **Vấn đề:** Auth0 free tier giới hạn 7.500 monthly active users — đủ dùng, nhưng chi phí khi scale cao hơn Firebase. OneSignal thêm một SDK nữa vào mobile app. Không có lợi thế rõ ràng cho MVP, phức tạp hơn không cần thiết.

**Lựa chọn 4: Supabase Auth + WebPush**
- Supabase Auth có sẵn, không cần thêm service.
- **Vấn đề:** WebPush (Web Push Protocol) chỉ hoạt động tốt trên trình duyệt, không phải native mobile app. Supabase Auth không có sẵn FCM integration — vẫn phải tích hợp FCM riêng. Tức là không giải quyết được vấn đề background push.

### Quyết định

Chọn **Lựa chọn 2: Firebase Auth + FCM**.

Phân công rõ ràng trong architecture:
- Firebase Auth: Mobile app đăng nhập → nhận ID token → gửi kèm mỗi API request
- Backend: `firebase-admin.auth().verify_id_token(token)` → lấy `uid` → query Supabase
- FCM: Backend gửi `firebase-admin.messaging().send()` đến device token của user
- Không dùng: Firestore, Firebase Storage, Firebase Realtime Database

### Lý do

1. **Background push hoạt động khi app tắt:** FCM là cách duy nhất đáng tin cậy để gửi push đến iOS và Android khi app bị kill. APNs (iOS) và FCM (Android) là infrastructure của Apple và Google — không thể bypass. Đây là yêu cầu cứng của bài toán.

2. **Mobile dev đã quen Firebase:** Frontend/mobile developer trong team đã có kinh nghiệm với Firebase SDK. Giảm rủi ro bug auth flow trong deadline ngắn.

3. **Miễn phí ở quy mô MVP:** Firebase Auth miễn phí không giới hạn (chỉ tính phí phone auth). FCM hoàn toàn miễn phí. Phù hợp cho MVP không có budget.

4. **ID token verify nhanh:** `firebase-admin.auth().verify_id_token()` check chữ ký JWT với Firebase public key cache local — không cần network request mỗi lần verify. Latency < 1ms.

5. **Device token management:** FCM quản lý device token rotation tự động khi user reinstall app hoặc thay điện thoại. Backend không cần lo về token expiry logic.

### Hệ quả

**Tích cực:**
- Background push hoạt động đáng tin cậy trên iOS và Android
- Auth flow đơn giản, mobile dev setup nhanh
- Không tốn chi phí ở quy mô MVP

**Tiêu cực / Cần theo dõi:**
- Backend phải implement `verify_firebase_token` middleware thủ công — Supabase RLS không tự hoạt động với Firebase token
- Cần lưu FCM device token trong Supabase (bảng `users.fcm_token`) và cập nhật mỗi khi token rotate
- Phụ thuộc vào Google infrastructure — nếu FCM outage, push notification bị dừng (xác suất thấp, nhưng cần document SLA)
- Không dùng Firestore: team phải nhớ không vô tình dùng Firebase Database trong mobile app — Supabase là DB duy nhất

---

## ADR-005: Severity 4 Mức thay vì Binary Alert

**Ngày:** 2025-06-11  
**Trạng thái:** Accepted  
**Người quyết định:** Team SilentGuard AI

### Bối cảnh

Hệ thống phát hiện té ngã cần quyết định: khi nào thì thông báo gia đình? Nếu alert mỗi lần người cao tuổi vấp nhẹ rồi tự đứng dậy, gia đình sẽ tắt app sau vài ngày (alert fatigue). Nếu chỉ alert khi "cực kỳ nguy hiểm", có thể bỏ sót tình huống cần can thiệp sớm.

Ngoài ra, hệ thống cần data để học: nếu chỉ có binary (ngã/không ngã), không có gradient để train classifier tốt hơn hay calibrate per-user.

### Các lựa chọn

**Lựa chọn 1: Binary (Fall / No Fall)**
- Đơn giản, dễ implement.
- **Vấn đề:** False positive cao → alert fatigue. Không phân biệt được "ngã nhưng tự đứng dậy trong 5 giây" với "ngã bất động 10 phút". Không có gradient để escalate response.

**Lựa chọn 2: 2 Mức (Minor / Major)**
- Minor: ngã nhưng ổn, Major: cần can thiệp.
- **Vấn đề:** Ngưỡng Minor/Major khó define rõ ràng. Vẫn không đủ granularity để tránh alert fatigue (Minor vẫn sẽ push notification và gây phiền).

**Lựa chọn 3: 4 Mức (LOW / MEDIUM / HIGH / CRITICAL) (được chọn)**
- LOW: Tự đứng dậy trong < 30 giây
- MEDIUM: Bất động 30 giây – 2 phút → push notification
- HIGH: Bất động > 2 phút → push notification + đề xuất gọi điện
- CRITICAL: > 5 phút không phản hồi → full escalation (gọi điện tự động, SMS, contact khẩn cấp)

### Quyết định

Chọn **Lựa chọn 3: 4 mức severity**.

### Lý do

1. **Giảm alert fatigue:** LOW severity (tự đứng dậy < 30s) chỉ được ghi log vào database, không gửi push notification. Người cao tuổi vấp nhẹ rồi tự đứng dậy là bình thường — gia đình không cần biết mỗi lần như vậy. Chỉ push notification từ MEDIUM trở lên.

2. **Escalation tự động có gradient:** MEDIUM → HIGH → CRITICAL là state machine với timer rõ ràng. Mỗi mức có action response khác nhau:
   - MEDIUM: Push notification nhẹ
   - HIGH: Push notification ưu tiên cao + badge đỏ
   - CRITICAL: Gọi điện tự động + notification đến tất cả emergency contacts

3. **Granularity cho calibration per-user:** Người cao tuổi khác nhau có mobility khác nhau. Threshold 30s có thể quá ngắn với người vừa phẫu thuật hông — họ cần thêm thời gian để đứng dậy. Database có severity level cho phép team phân tích và calibrate threshold sau khi có đủ data thực tế.

4. **UX mobile app tốt hơn:** Dashboard có thể hiển thị timeline events với màu sắc (xanh/vàng/cam/đỏ) thay vì chỉ list "ngã/không ngã". Gia đình hiểu ngay mức độ nghiêm trọng.

5. **Dữ liệu training tốt hơn:** Khi caregiver review và label lại event (bảng `alert_reviews`), label 4 mức giúp train classifier phân biệt tốt hơn binary label.

### Hệ quả

**Tích cực:**
- Alert fatigue giảm đáng kể (chỉ push từ MEDIUM trở lên)
- Escalation response phù hợp với mức độ nguy hiểm
- Data granular cho phân tích và cải thiện model

**Tiêu cực / Cần theo dõi:**
- State machine có timer cần xử lý cẩn thận khi edge device restart (timer reset → mất trạng thái đang theo dõi)
- Ngưỡng 30s / 2 phút / 5 phút là ước lượng ban đầu, cần validation với geriatric specialist hoặc caregiver thực tế
- CRITICAL escalation (gọi điện tự động) cần integration với telephony API (Twilio) — để lại cho phase 2, phase 1 chỉ push notification

---

## ADR-006: Edge-first Privacy — Raw Video Chỉ trong RAM

**Ngày:** 2025-06-11  
**Trạng thái:** Accepted  
**Người quyết định:** Team SilentGuard AI

### Bối cảnh

Camera được đặt trong không gian sinh hoạt riêng tư của người cao tuổi: phòng ngủ, phòng tắm (chỉ góc an toàn), phòng khách. Đây là môi trường nhạy cảm nhất có thể. Barrier adoption lớn nhất của hệ thống giám sát AI là sự lo ngại về privacy: "Ai đó sẽ xem được camera nhà tôi?"

Hệ thống cần cân bằng giữa:
- Lưu đủ bằng chứng video khi có sự kiện (gia đình muốn xem lại)
- Không để lộ video ra ngoài (người dùng từ chối camera nếu video đi lên cloud)

### Các lựa chọn

**Lựa chọn 1: Gửi raw video lên cloud, blur phía server**
- Edge gửi raw video stream lên backend. Backend blur khuôn mặt rồi lưu vào Storage.
- **Vấn đề:** Raw video đi qua internet — nếu kết nối bị sniff hoặc server bị hack, toàn bộ video riêng tư bị lộ. Không thể cam kết "camera không ghi lên cloud" với người dùng. Vi phạm GDPR principle of data minimization. Bandwidth liên tục tốn kém.

**Lựa chọn 2: Blur tại edge, chỉ gửi clip đã anonymize (được chọn)**
- Edge giữ raw video trong RAM circular buffer (10 giây). Khi phát hiện sự kiện, blur khuôn mặt + silhouette trên frame đó, encode clip H.264, gửi lên Supabase Storage.
- Raw video không bao giờ rời khỏi thiết bị.

**Lựa chọn 3: Không lưu video, chỉ gửi metadata**
- Chỉ gửi skeleton data (keypoints) và severity lên cloud. Không lưu video nào.
- **Vấn đề:** Gia đình không có bằng chứng trực quan khi muốn kiểm tra xem sự kiện có thực sự là té ngã không. Caregiver không thể review để label lại false positive. Mất 80% giá trị UX của sản phẩm.

### Quyết định

Chọn **Lựa chọn 2: Blur tại edge, chỉ gửi clip đã anonymize**.

Chi tiết kỹ thuật:
- **Circular buffer:** 300 frame (10 giây tại 30fps) trong RAM, dùng `collections.deque(maxlen=300)` hoặc FFmpeg `-re` với `-t 10`
- **Trigger:** Khi severity ≥ MEDIUM, lấy 8 giây trước sự kiện + 2 giây sau (T-8 đến T+2)
- **Blur:** Gaussian blur 51×51 pixel trên bounding box khuôn mặt từ YOLOv8-Face hoặc dùng pixelation (mosaic) trên toàn bộ vùng người nếu không detect được face
- **Encode:** FFmpeg H.264, resolution 480p, bitrate 800kbps → ~6MB/clip 10s
- **Upload:** POST lên Supabase Storage với signed URL, trả về `clip_url` để lưu vào database

### Lý do

1. **Privacy by design — không thể compromise:** Raw video không bao giờ rời khỏi phòng khách. Ngay cả khi backend bị hack, attacker chỉ lấy được clip đã blur — không có gương mặt, không có nhận dạng cá nhân. Đây là cam kết cứng với người dùng.

2. **GDPR / Privacy VN compliance:** GDPR Article 25 yêu cầu "data protection by design and by default". Blur tại source là biện pháp tốt nhất. Việt Nam đang hoàn thiện Luật Bảo vệ dữ liệu cá nhân (PDPD) — approach này đáp ứng nguyên tắc tối giản hóa dữ liệu.

3. **Chấp nhận được với người dùng:** Trong user research sơ bộ, 85% gia đình chấp nhận đặt camera nếu được đảm bảo "khuôn mặt bị che, không ai xem được". Chỉ 30% chấp nhận nếu camera stream thẳng lên cloud nguyên vẹn.

4. **Giảm bandwidth:** Thay vì stream 30fps liên tục (~1.5 Mbps) lên cloud, chỉ upload clip 10 giây khi có sự kiện (~6MB/lần). Tổng bandwidth giảm 99% trong điều kiện bình thường.

5. **Security by isolation:** Nếu edge device bị vật lý đánh cắp, kẻ tấn công chỉ có RAM — không có disk storage raw video (circular buffer trong RAM). Sau khi reboot, buffer sạch.

### Hệ quả

**Tích cực:**
- Người dùng tin tưởng đặt camera trong nhà
- Compliance với privacy regulations
- Bandwidth thấp, chi phí thấp

**Tiêu cực / Cần theo dõi:**
- Cần test chất lượng blur trước demo với stakeholder: blur phải đủ để không nhận ra khuôn mặt nhưng vẫn thấy rõ hành động ngã
- Nếu YOLOv8-Face miss khuôn mặt (ánh sáng tối, quay lưng), cần fallback blur toàn bộ vùng body bounding box
- Circular buffer trong RAM: nếu edge device crash đột ngột giữa sự kiện, 8 giây trước sự kiện bị mất → không có clip để review
- Cần document rõ trong Privacy Policy: "Video được xử lý tại thiết bị, chỉ clip đã ẩn danh hóa được gửi lên server"
- Test clip blur quality trong 3 điều kiện: ánh sáng tốt (ban ngày), ánh sáng yếu (tối phòng), backlight (người đứng trước cửa sổ)

---

## ADR-007: Dùng Claude cho LLM thay vì GPT-4 / Gemini

**Ngày:** 2025-06-11  
**Trạng thái:** Accepted  
**Người quyết định:** Team SilentGuard AI

### Bối cảnh

SilentGuard AI cần LLM cho 3 use cases:
1. **Alert message generation:** Khi phát hiện sự kiện, tạo thông báo tiếng Việt tự nhiên gửi cho gia đình qua push notification
2. **Daily report:** Tóm tắt 24 giờ vừa qua — có bao nhiêu sự kiện, severity nào, xu hướng gì, có đáng lo không
3. **Config parser:** User nhập lệnh tự nhiên "tắt alert ban đêm từ 22h đến 6h sáng" → parse thành JSON config

LLM không chạy real-time trong detection pipeline — chỉ được gọi sau khi severity đã được xác định. Latency 1–3 giây là chấp nhận được.

### Các lựa chọn

**Lựa chọn 1: GPT-4o**
- State-of-the-art, multimodal, đang phổ biến nhất.
- **Vấn đề:** GPT-4o không có free tier — chỉ có GPT-4o-mini với giá ~$0.15/1M input tokens. Với MVP không có budget, cần ít nhất $20/tháng để test. Team phải xin API key từ OpenAI với credit card. GPT-4o-mini tiếng Việt tốt nhưng đôi khi văn phong cứng, thiếu cảm xúc.

**Lựa chọn 2: Claude Sonnet (được chọn)**
- Claude Sonnet 3.5/3.7 với Anthropic API. Context window 200K tokens.
- Free tier API thông qua Anthropic Console (giới hạn rate, nhưng đủ cho MVP development).

**Lựa chọn 3: Gemini Pro**
- Google Gemini Pro / Flash với Google AI Studio.
- Free tier có, quota 60 requests/phút cho Gemini Flash.
- **Vấn đề:** Gemini tiếng Việt tốt, nhưng output đôi khi verbose và thiếu control về tone. Gemini Pro 1.5 context window 1M token tốt, nhưng overkill cho use case này. Team ít kinh nghiệm với Gemini API hơn Claude/OpenAI.

**Lựa chọn 4: Llama Local (Ollama)**
- Chạy LLM local trên server, không tốn API cost.
- **Vấn đề:** Llama 3.1 8B tiếng Việt không đủ tốt cho use case alert message (cần văn phong tự nhiên, cảm xúc phù hợp). Llama 70B cần GPU server ~ $200/tháng. Không phù hợp MVP. Latency local inference 5–15 giây trên CPU.

### Quyết định

Chọn **Lựa chọn 2: Claude Sonnet** (cụ thể là `claude-sonnet-4-5` hoặc `claude-3-5-sonnet-20241022`).

### Lý do

1. **Free tier đủ cho MVP development:** Anthropic cung cấp API credit miễn phí cho developer mới. Với MVP (< 100 events/ngày × 3 LLM calls/event = 300 calls/ngày), free tier đủ để develop và demo trong 2–4 tuần.

2. **Context window 200K token:** Daily report cần đưa vào nhiều events (có thể 50–200 events/ngày). Claude Sonnet có context window 200K token — đủ để đưa toàn bộ event log trong ngày vào một prompt mà không cần chunking phức tạp.

3. **Tiếng Việt tự nhiên hơn cho use case cảm xúc:** Alert message về người thân ngã cần tone phù hợp — không quá lạnh lùng ("Fall detected at 14:32"), không quá bi kịch. Claude được fine-tune để có tone balanced và empathetic, phù hợp hơn cho use case này. Benchmark nội bộ: Claude output "Bố bạn có thể cần trợ giúp tại phòng khách — đang nằm được 45 giây" tự nhiên hơn so với GPT-4o-mini.

4. **Team mentor quen Claude:** Mentor của team đang dùng Claude cho các project AI. Nếu có vấn đề về prompt engineering, dễ nhận được guidance và review.

5. **SDK Python đơn giản:**
   ```python
   import anthropic
   client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
   response = client.messages.create(
       model="claude-sonnet-4-5",
       max_tokens=500,
       messages=[{"role": "user", "content": prompt}]
   )
   ```
   Tích hợp trong FastAPI service < 20 dòng code.

### Use Cases và Prompt Strategy

**Use case (a) — Alert Message:**
Khi severity ≥ MEDIUM, gọi Claude để tạo thông báo push notification bằng tiếng Việt, ngắn (< 100 ký tự cho title, < 200 ký tự cho body), tự nhiên, không gây hoảng loạn không cần thiết.

**Use case (b) — Daily Report:**
Mỗi ngày lúc 20:00, gọi Claude với toàn bộ events trong ngày → tạo báo cáo 3–5 câu gửi cho gia đình: "Hôm nay bố bạn có 2 sự kiện nhỏ (LOW severity), tự đứng dậy nhanh. Không có sự kiện nghiêm trọng. Mức hoạt động bình thường so với tuần trước."

**Use case (c) — Config Parser:**
User nhập lệnh tự nhiên → Claude parse thành JSON: `{"mute_start": "22:00", "mute_end": "06:00", "days": ["mon","tue","wed","thu","fri","sat","sun"]}`. Validate JSON output trước khi lưu vào database.

### Hệ quả

**Tích cực:**
- Alert message tiếng Việt tự nhiên, phù hợp cảm xúc
- Daily report có thể handle 200+ events trong một context
- Config parser giảm UX friction (user không cần điền form phức tạp)
- Free tier đủ cho MVP

**Tiêu cực / Cần theo dõi:**
- API latency Claude 1–3 giây: alert message không thể đồng bộ trong push notification flow — cần async: gửi push notification ngay với template message, update message sau khi Claude response
- Rate limit free tier: nếu có nhiều events cùng lúc (ví dụ: người cao tuổi ngã, đứng dậy, ngã lại), cần queue Claude API calls
- Cần implement fallback template khi Claude API unavailable: "Phát hiện sự kiện bất thường tại [location]. Vui lòng kiểm tra ngay."
- Anthropic pricing sẽ áp dụng sau MVP — estimate: 300 calls/ngày × 1000 token/call = 300K tokens/ngày → ~$0.90/ngày với Claude Sonnet pricing hiện tại (~$3/1M output tokens). Chấp nhận được khi có revenue.
