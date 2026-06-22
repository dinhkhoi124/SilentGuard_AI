# Smartify App Context

Tài liệu này tóm tắt trạng thái hiện tại của ứng dụng Flutter `mobile/` để dùng làm handover note cho các lần phát triển tiếp theo.

## 1. App đang làm gì

Smartify là ứng dụng Flutter dành cho gia đình/caregiver dùng để:

- Đăng nhập bằng Firebase Auth.
- Đồng bộ phiên người dùng với backend FastAPI SilentGuard.
- Hiển thị màn hình khởi động (native splash + loading), onboarding 3 trang, welcome/login, đăng ký (sign up), trang chủ (home) và tài khoản (account).
- Xem danh sách camera, chi tiết camera và xem luồng video trực tiếp (live stream).
- Quét mã QR (quét trực tiếp hoặc chọn ảnh từ thư viện) để ghép nối camera mới thông qua Imou Cloud.
- Nhận thông báo đẩy (push notification) từ FCM, hiển thị thông báo cục bộ (local notification) và chuyển hướng nhanh đến màn hình camera tương ứng khi nhấn vào thông báo.
- Quản lý tài khoản cá nhân, đăng xuất và quản lý household.
- **Mới**: Gửi video từ thư viện (gallery) lên máy chủ qua API `POST /api/events/upload-video` để phân tích hành vi/sự kiện bất thường và hiển thị phản hồi từ AI.

Ngôn ngữ hiển thị cho người dùng là tiếng Việt.

## 2. Stack và kiến trúc hiện tại

- Flutter 3.x
- BLoC/Cubit cho quản lý trạng thái (state management).
- GoRouter cho điều hướng ứng dụng (routing).
- GetIt cho Dependency Injection (DI).
- Clean Architecture tổ chức theo feature.
- `shared_preferences` dùng để lưu cờ đã hoàn thành onboarding (`onboarding_completed`).

Những thành phần giữ vai trò trung tâm:

- `AuthNotifier`: Nguồn dữ liệu duy nhất (source of truth) cho trạng thái auth và điều hướng của router lúc startup.
- `SessionRepository`: Cầu nối đồng bộ giữa Firebase Auth và SilentGuard backend session.
- `OnboardingService`: Lưu trữ cờ kiểm tra khởi chạy lần đầu (first-run onboarding).
- `HomeBloc`: Quản lý dữ liệu trang chủ bao gồm danh sách thiết bị, thời tiết, bộ lọc phòng, trạng thái thiết bị ngoại vi và ảnh chụp thumbnail camera.
- `DevicePairingBloc`: Xử lý luồng quét mã QR, kiểm tra trạng thái camera trên Imou Cloud và lưu camera vào hệ thống.
- `FcmService` & `LocalNotificationService`: Xử lý đăng ký token FCM, nhận thông báo đẩy và kích hoạt thông báo cục bộ.
- `VideoUploadBloc`: Quản lý việc chọn video từ thư viện thông qua `image_picker` và tải lên backend.

## 3. Startup flow hiện tại

Quy trình khởi động nguội (cold start) được thiết kế tối ưu hai tầng để tránh hiện tượng nháy màn hình (flash) welcome/login khi Firebase đang phục hồi session:

1. **Tầng 1 (Trước runApp)**:
   - Đảm bảo Flutter binding được khởi tạo.
   - Bảo lưu màn hình native splash (`FlutterNativeSplash.preserve()`).
   - Khởi tạo Firebase Core và đăng ký các dịch vụ DI (`di.init()`).
   - Ứng dụng luôn đi vào route mặc định ban đầu là `/loading` để hiển thị widget `WaveTextLoader`.

2. **Tầng 2 (Sau khung hình đầu tiên - Post-Frame)**:
   - Gọi `AppInitializer.initializeAfterFirstFrame()` để khởi động `LocalNotificationService` và lấy thông tin notification ban đầu nếu ứng dụng được mở từ thông báo đẩy.
   - `AuthNotifier` kiểm tra trạng thái auth từ Firebase và thực hiện đồng bộ session với backend (`SessionRepository.provisionSession()`).
   - Chỉ khi trạng thái auth được xác định xong **VÀ** thời gian hiển thị splash tối thiểu (900ms) đã trôi qua, native splash mới được gỡ bỏ bằng `FlutterNativeSplash.remove()`.
   - GoRouter tự động chuyển hướng người dùng từ `/loading` tới màn hình đích phù hợp:
     - Đã đăng nhập: `/home` hoặc `/camera/:id` (nếu mở từ notification).
     - Chưa đăng nhập: `/onboarding` (nếu chưa xem) hoặc `/welcome` (nếu đã xong onboarding).

3. **Tầng 3 (Deferred Setup)**:
   - Sau 3 giây kể từ khi kết xuất khung hình đầu tiên, ứng dụng đăng ký FCM background handler và khởi chạy `FcmService.initialize` nhằm tránh nghẽn luồng DartMessenger trong lúc tải giao diện ban đầu.

## 4. Luồng auth hiện tại

Luồng xác thực chia thành 2 nhánh chính:

- **Email/Password**:
  - Biểu mẫu đăng nhập được tích hợp trực tiếp ngay trong `WelcomePage`.
  - UI phát sự kiện `AuthSignInRequested`, qua đó `AuthBloc` gọi `AuthRepository.signInWithEmail()`.
  - Khi thành công, ứng dụng thực hiện `SessionRepository.provisionSession()`.
- **Google Sign-In**:
  - Đăng nhập bằng tài khoản Google có sẵn ở cả `WelcomePage` và `SignUpPage`.
  - Thực hiện xác thực Firebase -> Provisioning session -> Đăng ký token FCM.

Không còn màn hình đăng nhập riêng (`signin_page.dart`). Các cổng đăng nhập xã hội khác như Apple, Facebook, X/Twitter đã bị loại bỏ khỏi giao diện và mã nguồn.

## 5. Màn hình auth/onboarding hiện tại

- **Màn hình tải ban đầu (`/loading`)**:
  - Nền tối (`AppColors.background`).
  - Sử dụng widget `WaveTextLoader` với hiệu ứng sóng chữ mượt mà.
  - Màn hình `SplashPage` cũ đã bị loại bỏ hoàn toàn.
- **Màn hình Onboarding (`OnboardingPage`)**:
  - Gồm 3 trang trượt PageView mô phỏng ứng dụng.
  - Nút Skip và Continue ở các trang 1-2. Trang cuối cùng có nút `Let's Get Started` để chuyển hướng sang `/welcome` và lưu trạng thái đã xem.
- **Màn hình Welcome (`WelcomePage`)**:
  - Chứa form nhập email/password trực tiếp, nút đăng nhập chính và tuỳ chọn Google Sign-in.
  - Lối dẫn sang `SignUpPage` dành cho tài khoản mới.
- **Màn hình Đăng ký (`SignUpPage`)**:
  - Giao diện đăng ký tài khoản mới bằng Email/Password hoặc Google.

## 6. Router và redirect logic

`AppRouter` cấu hình các đường dẫn chính:

- `/loading`: Màn hình chờ khởi động và xử lý logic auth.
- `/onboarding`: Màn hình giới thiệu ứng dụng.
- `/welcome`: Màn hình chào mừng kiêm đăng nhập.
- `/signup`: Màn hình đăng ký tài khoản.
- `/home`: Trang chủ (bảng điều khiển thiết bị).
- `/add-device`: Ghép nối thiết bị camera mới.
- `/camera/:id`: Chi tiết camera. Nếu truy cập trực tiếp bằng ID mà không có tham số extra, ứng dụng sẽ tự động tải danh sách thiết bị để tìm camera khớp với ID.

Redirect logic dựa trên 3 trạng thái từ `AuthNotifier`: `isReady` (đã khởi tạo xong), `isAuthenticated` (đã xác thực), và `onboardingCompleted` (đã hoàn thành giới thiệu).

## 7. Đăng xuất (Logout) hiện tại

Quy trình đăng xuất diễn ra tuần tự:

1. `AccountPage` phát sự kiện `AuthSignOutRequested`.
2. `AuthRepositoryImpl.signOut()` gửi yêu cầu huỷ session lên backend SilentGuard trước.
3. Giải phóng session đã cache cục bộ (`SessionRepository.clearCachedSession()`).
4. Đăng xuất khỏi Firebase Auth.
5. Router tự động chuyển hướng người dùng về màn hình `/welcome`.
6. Hiển thị dialog tiến trình (Progress Dialog) trong suốt quá trình đăng xuất để tối ưu trải nghiệm người dùng (UX).

## 8. Luồng camera / thiết bị hiện tại

### Ghép nối camera
1. Quét mã QR trực tiếp qua camera hoặc tải ảnh QR từ thư viện ảnh.
2. Trích xuất thông tin `{SN:...,SC:...,PID:...}` và lấy số Serial Number (SN).
3. Gọi Imou Cloud API để kiểm tra trạng thái hoạt động và lấy địa chỉ luồng RTMP/RTSP.
4. Gửi thông tin đăng ký camera lên backend qua API `POST /api/cameras`.
5. Cập nhật camera mới vào danh sách đang hiển thị trên trang chủ.

### Phát video trực tiếp (Live Stream)
- Sử dụng thư viện `media_kit` để phát video.
- Bản tin URL stream được gửi trực tiếp vào player.
- **Khắc phục lỗi xung đột âm thanh trên Android**: Nhằm tránh tình trạng lỗi driver âm thanh hoặc ứng dụng bị crash khi khởi động cùng Firebase/FCM, các plugin của `media_kit` được loại bỏ khỏi cấu hình tự động đăng ký của Flutter Engine tại `MainActivity.kt`. Thay vào đó, chúng được đăng ký động thông qua MethodChannel `smartify/media_kit` khi `CameraLivePreview` bắt đầu tải luồng video thực tế (`_openStreamWhenReady`).

### Chụp ảnh xem trước (Thumbnail Capture)
- Khi rời khỏi màn hình chi tiết camera (`CameraDetailPage`), trình phát sẽ chụp lại khung hình cuối cùng của luồng phát trực tiếp (`player.screenshot()`).
- Bức ảnh này (định dạng `image/png`) được chuyển về và lưu trong `HomeBloc` để hiển thị làm thumbnail cập nhật của camera đó trên Grid trang chủ, thay thế cho logo mặc định.

### Xoá camera
- Thực hiện gọi API `DELETE /api/cameras/{camera_id}` để gỡ bỏ thiết bị khỏi backend.

## 9. Tích hợp Backend hiện tại

Ứng dụng kết nối với SilentGuard backend thông qua các nhóm API chính:

- **Auth & Session**:
  - `POST /api/users/login`
  - `POST /api/users/logout`
  - `POST /api/users/device-token` (Đăng ký FCM token)
  - `GET /api/households/me`
- **Quản lý Camera**:
  - `GET /api/cameras`
  - `POST /api/cameras`
  - `DELETE /api/cameras/{camera_id}`
- **Sự kiện & Video**:
  - `POST /api/events/upload-video` (Tải lên video .mp4 để phân tích và đánh giá sự kiện an ninh).
- **Imou Cloud API**:
  - Lấy access token, kiểm tra trạng thái thiết bị và lấy địa chỉ stream.

## 10. Những thứ đang ổn

- Startup và xử lý auth mượt mà, không bị chớp màn hình nhờ cơ chế chặn hiển thị native splash đến khi trạng thái auth sẵn sàng.
- Khắc phục triệt để lỗi xung đột driver âm thanh / crash trên các thiết bị Android bằng giải pháp trì hoãn nạp thư viện `media_kit`.
- Luồng gửi video được tích hợp trực tiếp trên thanh điều hướng BottomNavBar, dễ dàng tương tác và tải lên.
- Thumbnail thẻ camera trên trang chủ được cập nhật trực quan bằng khung hình thực tế chụp từ luồng phát cuối cùng.
- Quản lý trạng thái bằng BLoC/Cubit rõ ràng, cấu trúc Clean Architecture chuẩn hóa.

## 11. Những chỗ còn vướng

- `AppConfig.backendAuthToken` đang là dead code (không được sử dụng trong các API Client hiện tại).
- Tính năng phục hồi mật khẩu (Forgot Password) trên giao diện Welcome chỉ là placeholder, chưa có xử lý logic thật.
- Các tab "Tự động" (Automation) và "Báo cáo" (Report) hiện tại là giao diện chờ (Coming Soon).

## 12. Những điểm cần xác nhận nếu làm tiếp

- Có nên loại bỏ hoàn toàn thuộc tính dead code `AppConfig.backendAuthToken` để làm sạch file cấu hình không?
- Yêu cầu nghiệp vụ cụ thể cho luồng Quên mật khẩu (Forgot Password) để tiến hành tích hợp Firebase Password Reset.
- Kịch bản hoạt động của các tab Tự động hoá và Báo cáo.

## 13. File nên đọc khi làm việc với các luồng này

- **Khởi tạo và Điều hướng**:
  - [app_initializer.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/core/bootstrap/app_initializer.dart)
  - [auth_notifier.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/core/router/auth_notifier.dart)
  - [app_router.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/core/router/app_router.dart)
- **Tải lên Video**:
  - [video_upload_bloc.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/features/video_upload/presentation/bloc/video_upload_bloc.dart)
  - [video_upload_remote_datasource.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/features/video_upload/data/datasources/video_upload_remote_datasource.dart)
- **Cấu hình Native Android**:
  - [MainActivity.kt](file:///d:/AI_TC/C2-App-128/mobile/android/app/src/main/kotlin/com/example/mobile/MainActivity.kt)
- **Phát Video và Giao diện Camera**:
  - [camera_video_player.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/features/home/presentation/widgets/camera_video_player.dart)
  - [camera_card.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/features/home/presentation/widgets/camera_card.dart)
  - [home_page.dart](file:///d:/AI_TC/C2-App-128/mobile/lib/features/home/presentation/pages/home_page.dart)

## 14. Tóm tắt một câu

Smartify là ứng dụng Flutter tối ưu luồng khởi động (gắn chặt native splash với trạng thái auth), sử dụng Firebase kết hợp đồng bộ session backend, hỗ trợ xem luồng camera live stream qua Imou Cloud bằng `media_kit` (đã sửa lỗi âm thanh Android), tự động chụp thumbnail cập nhật trang chủ, và tích hợp tính năng tải lên video để phân tích sự kiện bất thường.
