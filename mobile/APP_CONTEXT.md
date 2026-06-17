# Smartify App Context

Tài liệu này tóm tắt bức tranh hiện tại của app Flutter `mobile/` để dùng như handover note cho các lần làm tiếp theo.

## 1. App đang làm gì

Smartify là ứng dụng Flutter cho gia đình/caregiver dùng để:

- Đăng nhập bằng Firebase Auth
- Đồng bộ phiên người dùng với backend FastAPI SilentGuard
- Xem danh sách camera, chi tiết camera và luồng video trực tiếp
- Quét QR để ghép camera mới
- Nhận thông báo FCM và mở màn hình alert/event
- Quản lý tài khoản, logout, và các luồng liên quan đến household

Ngôn ngữ hiển thị cho người dùng là tiếng Việt.

## 2. Stack và kiến trúc hiện tại

- Flutter 3.x
- BLoC cho state management
- GoRouter cho điều hướng
- GetIt cho DI
- Clean Architecture theo feature

Các điểm quan trọng:

- `AuthNotifier` là nguồn trạng thái auth cho router
- `HomeBloc` đang giữ state của home và danh sách device hiển thị
- `SessionRepository` là lớp nối giữa Firebase login và backend session
- `FcmService` xử lý đăng ký token FCM và nhận notification
- `DevicePairingBloc` xử lý luồng quét QR và ghép camera

## 3. Luồng auth hiện tại

Luồng đăng nhập hiện tại đi theo hướng:

1. User đăng nhập bằng Firebase Auth
2. `AuthNotifier` nghe `authStateChanges()`
3. Khi có user mới, app gọi `SessionRepository.provisionSession()`
4. `SessionRepository` gọi backend:
   - `POST /api/users/login`
   - `GET /api/households/me`
5. Sau khi provision thành công, `AuthNotifier` gọi đăng ký FCM token
6. `GoRouter` dùng `AuthNotifier.isAuthenticated` để redirect giữa:
   - `/welcome`
   - `/signup`
   - `/signin`
   - `/home`

Logout hiện tại đi theo thứ tự:

1. Gọi backend logout
2. Clear session cache
3. Firebase sign-out

## 4. Luồng camera / device hiện tại

Luồng ghép camera đang là:

1. Quét QR hoặc chọn QR từ gallery
2. Resolve QR sang `ResolvedDevice`
3. Kiểm tra camera qua Imou cloud
4. Lấy RTMP stream URL từ Imou cloud
5. Lưu camera đã ghép vào backend

Hiện tại phần camera trực tiếp đã chuyển sang `media_kit` thay vì VLC.

## 5. Backend integration đã rõ

Theo tài liệu backend trong `docs/backend/` và code hiện tại, app đang phụ thuộc các nhóm API sau:

- Auth/session
  - `POST /api/users/login`
  - `POST /api/users/logout`
  - `POST /api/users/device-token`
  - `GET /api/households/me`
- Home/dashboard
  - lấy devices, thời tiết, summary
- Alerts/events/reports
  - danh sách cảnh báo
  - chi tiết event
  - review confirm/dismiss
  - daily report
- Camera
  - tạo, sửa, xoá, rotate key
  - upload-url cho clip

## 6. Những thứ đang ổn

- Auth flow đã có lớp trung gian rõ ràng, không gọi backend trực tiếp từ UI
- Router đã bám vào một nguồn trạng thái auth duy nhất
- FCM token được đăng ký sau khi provision session thành công
- Camera pairing không còn là code thử nghiệm rời rạc, mà đã có datasource/repository/bloc rõ ràng
- `media_kit` đã được đưa vào để mở luồng camera ổn định hơn trên mobile

## 7. Những chỗ còn vướng

- `AppConfig.backendAuthToken` hiện thấy chỉ còn declaration, chưa thấy nơi dùng thực tế
- Có nhiều log debug kiểu `[GoogleAuth]` và `[DEBUG_TOKEN]`/`[DEBUG_FCM_TOKEN]` phục vụ debug tạm thời, cần nhớ dọn khi chốt release
- Trong repo vẫn còn code ONVIF cũ, nhưng flow pairing hiện tại đã chuyển sang Imou cloud
- Imou cloud yêu cầu `IMOU_API_BASE_URL`, `IMOU_APP_ID`, `IMOU_APP_SECRET`; nếu thiếu một trong ba thì flow pairing sẽ fail sớm
- Cần xác nhận dứt khoát backend JIT provisioning là bắt buộc trước khi đăng ký FCM token hay không, dù hiện tại code đang làm theo thứ tự đó

## 8. Những điểm chưa rõ / cần xác nhận

- Source of truth cho camera:
  - ONVIF local discovery
  - Imou cloud API
  - Hay chỉ giữ Imou cho luồng live preview và onboarding?
- `POST /api/users/login` trả về shape response nào là chuẩn cuối cùng:
  - object có `user`
  - hay trả thẳng user root-level
- Backend có thật sự cần `backendAuthToken` không, hay đây là biến cũ chưa xóa
- Có muốn tiếp tục giữ các debug token print trong `HomeBloc` và `FcmService` sau giai đoạn test không
- Luồng ghép camera nên đi theo QR từ gallery hay camera live là chính

## 9. File nên đọc khi đụng vào các luồng này

- `lib/core/router/auth_notifier.dart`
- `lib/core/router/app_router.dart`
- `lib/features/session/data/datasources/session_remote_datasource.dart`
- `lib/features/session/data/repositories/session_repository_impl.dart`
- `lib/core/services/fcm_service.dart`
- `lib/features/devices/presentation/bloc/device_pairing_bloc.dart`
- `lib/features/devices/data/datasources/imou_cloud_datasource.dart`
- `lib/features/home/presentation/widgets/camera_video_player.dart`

## 10. Tóm tắt một câu

Smartify hiện là app Flutter cho family/caregiver, đăng nhập bằng Firebase, đồng bộ session với backend SilentGuard, đăng ký FCM token sau khi provision xong, và đang dùng Imou cloud để resolve/lấy stream camera trong luồng ghép thiết bị.
