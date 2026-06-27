# Mobile App Context

Tài liệu này tóm tắt trạng thái hiện tại của app Flutter trong thư mục `mobile/`.
Mục tiêu là giúp lần sau nhìn nhanh codebase, startup flow, auth flow, notification flow, và vị trí của từng feature.

## 1. App này là gì

App mobile hiện đang là một ứng dụng Flutter cho bài toán giám sát an toàn trong gia đình, tập trung vào camera, cảnh báo sự cố, và phản hồi nhanh.

Branding trong code hiện chưa thống nhất:

- `MaterialApp.title` đang là `WatchNest`
- Android/iOS/legal content vẫn dùng tên `SilentGuard`
- Một số text UI còn gõ sai `SlientGuard`

Nếu cần làm việc liên quan branding, cần check cả UI, manifest, markdown asset, và legal copy.

## 2. Stack và kiến trúc

- Flutter + Material 3
- `flutter_bloc` / `bloc`
- `go_router`
- `get_it`
- Firebase Core, Auth, Messaging, Crashlytics
- `flutter_local_notifications`
- `shared_preferences`
- `media_kit` & `media_kit_video`
- `mobile_scanner`, `image_picker`, `permission_handler`
- `http`
- Đã loại bỏ thư viện `xml` (do không còn dùng ONVIF)

Kiến trúc tổng quan:

- `lib/core/`: bootstrap, router, theme, network, services, widgets, utils
- `lib/features/`: chia theo feature/domain
- `lib/injection_container.dart`: DI registry (quản lý khởi tạo dependency)
- `lib/main.dart`: app bootstrap

Day la clean-ish feature architecture, nhung thuc te co pha tron giua domain/data/presentation tuy feature.

## 3. Runtime và config quan trọng

File chính:

- `lib/main.dart`
- `lib/core/bootstrap/app_initializer.dart`
- `lib/core/router/app_router.dart`
- `lib/core/router/auth_notifier.dart`
- `lib/core/config/app_config.dart`
- `lib/injection_container.dart`

Config runtime đang dùng:

- Backend base URL mặc định: `https://c2-app-128-production.up.railway.app`
- Imou base URL: `https://openapi-sg.easy4ip.com/openapi` (được cấu hình qua `AppConfig.imouBaseUrl` và đăng ký một `ApiClient` riêng có tên `imou` trong DI container)
- Network timeout mặc định: 15s

## 4. Startup flow hiện tại

Để tối ưu hóa thời gian hiển thị khảm hình đầu tiên (cold start) và tránh cảnh báo ANR, startup flow đã được tái cấu trúc triệt để bằng cách trì hoãn các tác vụ nặng ra sau first frame và thực hiện tuần tự để giảm nghẽn.

### 4.1 Trước `runApp()`

Trong `lib/main.dart`:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Thiết lập Splash screen: `FlutterNativeSplash.preserve(...)`
3. Gọi ngay `runApp(BootstrapApp(...))` để vẽ giao diện loading/splash ban đầu mà không đợi bất kỳ tác vụ I/O hay mạng nào.

### 4.2 Sau first frame (Post-Frame Initialization)

Trong `BootstrapApp` thông qua `AppInitializer.initializeAfterFirstFrame()`:
Các tác vụ khởi chạy được đo thời gian bằng stopwatch (`_logStartupAsync` và `_logStartupSync`) và nhường luồng xử lý (`_yieldToUi()`) để giao diện mượt mà:

1. Khởi tạo Firebase: `Firebase.initializeApp(...)` (giới hạn thời gian chờ tối đa 8 giây để tránh treo máy).
2. Thiết lập Crashlytics xử lý lỗi fatal lỗi Flutter.
3. Khởi tạo Dependency Injection: Gọi `di.init()`. Để tránh lỗi deadlock với Firebase callbacks, `SharedPreferences` được lấy bất đồng bộ (`await SharedPreferences.getInstance()`) trước khi truyền vào container và đăng ký dưới dạng lazy singleton. Không còn sử dụng `di.sl.allReady()`.
4. Tải theme: `ThemeController.load()`.
5. Dọn dẹp trạng thái tạm dừng giám sát camera đã hết hạn: `MonitoringSuppressService.pruneExpired()`.
6. Xử lý thông báo FCM khi app được mở từ trạng thái bị tắt hoàn toàn (terminated): `_handleInitialFcmAlert`.
7. Khởi tạo dịch vụ local notifications: `_initializeLocalNotificationsStep` để lắng nghe người dùng chạm vào thông báo.
8. Tải danh sách lời mời gia đình đang chờ xử lý: `_loadPendingInvites`.
9. Trả về kết quả khởi tạo và đăng ký setup FCM listeners chính thức: `scheduleMessagingSetup(...)` chạy ngầm.

### 4.3 Splash và auth readiness

`AuthNotifier` chỉ giải phóng màn hình splash khi đủ các điều kiện:

- Auth state đã resolve (đã kiểm tra session của Firebase).
- Onboarding flag đã được tải xong.
- Thời gian trễ splash tối thiểu 900ms đã trôi qua.

Khi đủ điều kiện, màn hình splash sẽ bị gỡ bỏ (`FlutterNativeSplash.remove()`). Nếu khởi động lỗi, app sẽ hiển thị giao diện báo lỗi trực quan (`_BootstrapShell`) thay vì bị crash đen màn hình.

## 5. Auth và session flow

### 5.1 Firebase auth

Auth layer nằm ở:

- `features/auth/data/datasources/firebase_auth_datasource.dart`
- `features/auth/data/repositories/auth_repository_impl.dart`
- `features/auth/presentation/bloc/auth_bloc.dart`

UI auth chính:

- `/welcome`
- `/signup`

Code hiện có hỗ trợ:

- email/password
- Google sign-in
- sign-out

### 5.2 Router auth logic

`AuthNotifier` lắng nghe `authStateChanges()` và quyết định 3 pha:

- `checkingSession`
- `unauthenticated`
- `authenticated`

Lưu ý quan trọng: code hiện tại KHÔNG còn đợi backend session provisioning xong mới cho vào app.
Ngay khi Firebase user tồn tại, router có thể rời `/loading` để vào `/home`.
Phần backend/session sẽ do các bloc/repository xử lý tiếp.

Đây là khác biệt quan trọng so với một số tài liệu cũ.

### 5.3 Backend session & Switch Household

Session layer nằm ở:

- `features/session/data/datasources/session_remote_datasource.dart`
- `features/session/data/repositories/session_repository_impl.dart`
- `features/session/domain/repositories/session_repository.dart`

Session repository được sử dụng bởi:

- `AuthBloc`
- `HomeBloc`
- `VideoUploadBloc`
- `EventHistoryCubit`
- các data source cần `household_id`

Cung cấp các API:
- `login`, `logout`
- `provisionSession`: Lấy config session hiện tại từ backend.
- `switchHousehold(String householdId)` (MỚI): Gửi yêu cầu đổi hộ gia đình lên backend (`POST /api/users/switch-household`), xóa cache session cũ và provision lại. Tích hợp trực tiếp khi chấp nhận lời mời gia đình mà không cần logout/login lại.

## 6. Notification flow

Thành phần chính:

- `core/services/fcm_service.dart`
- `core/services/local_notification_service.dart`
- `core/services/monitoring_suppress_service.dart`
- `features/notifications/data/datasources/notification_local_data_source.dart`
- `features/notifications/presentation/cubit/notifications_cubit.dart`
- `features/notifications/presentation/pages/notifications_page.dart`
- `features/notifications/presentation/widgets/notification_segmented_tab_bar.dart`

Flow hiện tại:

- Foreground FCM: kiểm tra suppress locally trước. Nếu không bị suppress: ghi nhận tin nhắn + hiển thị local notification qua `LocalNotificationService`.
- Background FCM: `firebaseMessagingBackgroundHandler` lưu trữ tin nhắn bằng `NotificationLocalDataSource.saveBackgroundMessage(...)`. Sử dụng `SharedPreferences.getInstance()` đồng bộ để lọc các tin nhắn bị suppress trước khi hiển thị.
- Open from terminated: `AppInitializer` kiểm tra suppress, đọc tin nhắn và điều hướng.
- Open from local notification: điều hướng đến camera detail hoặc trang chủ.

Local persistence:

- key: `app_notifications`
- tối đa: 100 item

Navigation từ notification:

- nếu có `cameraId` -> `go('/camera/:id')`
- nếu không -> `go('/home')`

Ngoài FCM, startup còn inject pending household invites vào notification list để user thấy lời mời.

Tích hợp Suppression:
- `FcmService` tích hợp `MonitoringSuppressService` để lọc bỏ các cảnh báo `fall_alert` từ camera đang trong thời gian tạm dừng giám sát (suppressed).

Tích hợp lời mời:
- Khi đồng ý lời mời gia đình thành công từ tab Lời mời, `NotificationsPage` lắng nghe sự kiện `RespondSuccess` của `PendingInvitesCubit`, hiển thị SnackBar thành công và tự động điều hướng về `/home` để tải lại dữ liệu của hộ gia đình mới.

## 7. Navigation và app shell

Router top-level nằm trong `lib/core/router/app_router.dart`.

Route hiện có:

- `/loading`
- `/onboarding`
- `/welcome`
- `/signup`
- `/home`
- `/add-device`
- `/emergency-contacts`
- `/app-appearance`
- `/help-support`
- `/faq`
- `/privacy-policy`
- `/notifications`
- `/notification-settings`
- `/camera/:id`

Lưu ý:

- Không có nested shell route; `HomePage` tự quản lý 4 tab bằng `IndexedStack`

4 tab trong `HomePage`:

1. Home
2. Automation
3. Reports
4. Account

## 8. Feature map theo code hiện tại

### 8.1 `features/home`

Đây là feature trung tâm cho camera dashboard.

Thành phần chính:

- `HomeBloc`
- `HomePage`
- `CameraDetailPage`
- `SuppressCubit`
- `MonitoringSuppressService`
- widgets cho safety_weather_card, camera grid, room filter, camera card, camera_action_buttons

`HomeBloc` quản lý ít nhất các việc sau:

- load weather
- load danh sách camera
- room filter
- delete camera
- thumbnail capture cache
- stream URL loading cho camera detail
- backend warm-up state
- unauthorized state
- `CameraDetailClosed` (giải phóng phiên stream)

`SuppressCubit` & `MonitoringSuppressService`:
- Quản lý việc tạm dừng giám sát/gửi cảnh báo từ camera theo thời gian được chọn (30 phút, 2 giờ, 12 giờ, 24 giờ).
- Lưu trữ thời gian tạm dừng vào `SharedPreferences` đồng bộ.
- Có xử lý an toàn (try-catch & timeout 1-2s) để tránh lỗi Keystore làm treo ứng dụng.
- Cập nhật bộ đếm ngược realtime và cập nhật trạng thái UI của nút bấm trong `CameraDetailPage`.

**Tải Live Stream tối ưu (MỚI):**
- Để tránh việc re-initialize trình phát video `media_kit` gây giật và nhấp nháy màn hình đen khi có cập nhật URL stream từ Bloc, `CameraDetailPage` giữ nguyên thực thể `CameraVideoPlayer` và cập nhật trực tiếp URL/Loading state thông qua `CameraVideoPlayerController` và GlobalKey `CameraVideoPlayerState.updateUrl(...)` / `updateDisplayState(...)`.

### 8.2 `features/devices` (TÁI CẤU TRÚC ĐƠN GIẢN HÓA)

Tính năng quét QR và ghép nối camera đã được đơn giản hóa tối đa nhằm loại bỏ các thành phần phức tạp không cần thiết (đã xóa ONVIF discovery, RTSP/ONVIF configuration, gallery QR import, và thư viện `xml`):
- `DevicePairingBloc`: Chỉ còn quản lý flow quét mã QR trực tiếp từ camera. Khi quét thành công, trích xuất serial number của thiết bị thông qua hàm `parseSerialNumber(rawQr)`.
- Giao diện `DevicePairingPage` được làm gọn lại theo luồng: Chuẩn bị quét -> Quét QR -> Đang kết nối (`DevicePairingLoading`) -> Thành công (`DevicePairingSuccess`) hoặc Lỗi (`DevicePairingError`).
- Thiết bị sau khi quét sẽ tự động được gán tên mặc định là `Camera $serialNumber` và gọi API `savePairedDevice` lên backend AI mà không cần bước nhập tên hay cấu hình IP thủ công.

Route pairing:

- `/add-device`

### 8.3 `features/reports`

Báo cáo và lịch sử sự kiện:

- `ReportsPage`
- `EventHistoryCubit`
- `EventHistoryRemoteDataSource`
- `WeeklyEventTrendAggregator`
- `WeeklyTrendChartCard`
- `AnimatedWeeklyBarChart`
- mapper để biến event history thành display model

API đang dùng:

- `GET /api/events/history`

Query params hiện có:

- `household_id`
- `page`
- `page_size`
- `severity`
- `room`
- `from_date`
- `to_date`

Biểu đồ xu hướng tuần (Weekly Trend Chart):
- Lấy dữ liệu thật từ backend thông qua `EventHistoryCubit` với bộ lọc thời gian 7 ngày gần nhất.
- Sử dụng `WeeklyEventTrendAggregator` để nhóm các sự kiện theo từng thứ trong tuần và theo mức độ nghiêm trọng (severity).
- Hiển thị biểu đồ cột động `AnimatedWeeklyBarChart` phân chia theo màu sắc của mức độ sự cố.

### 8.4 `features/automation`

Đây là tab giao diện cho automation/emergency response.

Hiện có:

- `AutomationPage`
- status card
- rules section
- severity timeline
- emergency contacts preview
- quiet window card
- AI config card

Tình trạng hiện tại:

- một phần là UI scaffold / coming-soon interaction
- emergency contacts có feature data local riêng

### 8.5 `features/automation` - emergency contacts

Data và state:

- `EmergencyContactsLocalDataSource`
- `EmergencyContactsRepositoryImpl`
- `EmergencyContactsCubit`
- `EmergencyContactsPage`

Route:

- `/emergency-contacts`

### 8.6 `features/household_invite`

Quản lý lời mời tham gia hộ gia đình:
- `PendingInvitesCubit` đã được cập nhật: Khi chấp nhận lời mời (`respondToInvite(..., true)`), cubit sẽ gọi API `switchHousehold` đổi hộ gia đình trực tiếp trên backend, sau đó phát sự kiện `HomeStarted` cho `HomeBloc` để làm mới danh sách camera dashboard ngay lập tức mà không cần logout/login.

### 8.7 `features/account`

Trang account nằm trong tab thứ 4 của `HomePage`.

Hiện có:

- `AccountPage`
- `AppAppearancePage`
- `HelpSupportPage`
- `FaqPage`
- `PrivacyPolicyPage`
- `NotificationSettingsPage`
- `AccountPageHeader` (Header thống nhất cho các trang con thuộc Account)

Asset markdown:

- `faq.md`
- `privacy-policy.md`

### 8.8 `features/video_upload`

Feature upload video phân tích sự kiện:

- `VideoUploadBloc`
- `UploadVideoUseCase`
- `VideoUploadRemoteDatasource`

Trigger:

- nút upload ở bottom navigation

Flow tổng quát:

1. user chọn upload
2. bloc lấy video từ gallery
3. đọc `household_id` từ session
4. upload lên backend
5. show success/failure snackbar

### 8.9 `features/onboarding`

- `OnboardingPage`
- onboarding completion được lưu qua `OnboardingService`
- auth router dùng flag này để quyết định vào `/onboarding` hay `/welcome`

## 9. Home tab và camera detail

### 9.1 Home tab

`HomePage` là app shell thực tế sau login.

Nó chứa:

- app bar + unread notification badge
- 4-tab `IndexedStack`
- upload progress line
- FAB thêm device
- notification snackbar foreground

### 9.2 Camera detail

Route:

- `/camera/:id`

Nếu route có `extra` là `CameraDevice` hoặc `CameraDetailArgs` thì vào thẳng detail.
Nếu chỉ có `id`, router dùng `_CameraRouteLoader` để fetch danh sách camera rồi tìm device.

Camera detail hiện tại phụ thuộc vào:

- `HomeBloc` cho stream URL request
- `ImouStreamRepository`
- `media_kit` & `media_kit_video`
- event history cubit cho lịch sử sự kiện
- event feedback / alert review cubit cho phản hồi người dùng

Tối ưu hóa chi tiết camera:
- Khung video được fix cứng tỷ lệ 16:9 để tránh lỗi layout chiếm toàn màn hình trên iOS, giúp nội dung phía dưới cuộn (scrollable) bình thường, kèm loading/error states rõ ràng.
- Sự kiện gần đây được làm mới card layout: loại bỏ mock image thumbnail do thực tế backend không cung cấp ảnh thumbnail, hiển thị thông tin thực tế từ backend gồm Duration, Confidence, Room, Status và Severity Badge thống nhất. Xóa bỏ các số liệu test cứng (`999s` / `95%` confidence) do đây là mock data.
- Cho phép tạm dừng thông báo cảnh báo của camera bằng cách chạm vào nút "Tạm dừng giám sát" với lựa chọn khoảng thời gian giám sát (30m, 2h, 12h, 24h) cùng hiệu ứng countdown chu kỳ giây tuyệt đẹp.
- **Giải phóng tài nguyên (MỚI):** Khi thoát màn hình chi tiết camera, trang phát ra sự kiện `CameraDetailClosed(serialNumber: ...)` giúp `HomeBloc` gọi `imouStreamRepository.releaseStreamSession(deviceSn)` để hủy liên kết luồng trực tiếp (`unbindLive`) trên Imou Cloud, giải phóng băng thông và phiên kết nối.

## 10. Dependency Injection snapshot

`lib/injection_container.dart` quản lý khởi tạo tuần tự và ghi lại thời gian chạy (`_logDiStep`):
- Đăng ký Client HTTP chuẩn và đăng ký một `ApiClient` riêng có tên instance là `'imou'` dành riêng cho các API của Imou Cloud.
- Khởi tạo `SharedPreferences` trước khi gọi đăng ký DI để tránh deadlock, sau đó đăng ký bằng `registerLazySingleton`.
- Loại bỏ toàn bộ các đăng ký liên quan đến ONVIF và các data source QR/ảnh cũ bị xóa.
- Đăng ký đầy đủ các Bloc/Cubit: `AuthBloc`, `HomeBloc`, `VideoUploadBloc`, `SuppressCubit`, `DevicePairingBloc` (chỉ phụ thuộc vào `DeviceRepository`), `EmergencyContactsCubit`, `PendingInvitesCubit` (phụ thuộc vào `SessionRepository` để chuyển đổi household), và các Cubit báo cáo/feedback sự kiện.

## 11. Backend/API nhìn nhanh

Từ code hiện tại có thể thấy app đang gọi nhóm API sau:

### 11.1 Auth/session

- `POST /api/users/login`
- `POST /api/users/logout`
- `GET /api/households/me`
- `POST /api/users/device-token`
- `POST /api/users/switch-household` (MỚI)

### 11.2 Camera/device

- `GET /api/cameras`
- `POST /api/cameras`
- `DELETE /api/cameras/{camera_id}`

### 11.3 Event/alert

- `GET /api/events/history`
- `POST /api/events/upload-video`
- `PATCH /api/alerts/{event_id}/review`
- `POST /api/events/{event_id}/feedback`

### 11.4 External services

- Open-Meteo cho weather
- Imou Cloud API: Đăng nhập lấy access token `/accessToken`, kích hoạt live stream `/bindDeviceLive`, lấy thông tin luồng trực tiếp `/getLiveStreamInfo`, tắt live stream `/unbindLive`, lấy danh sách thiết bị `/deviceList`.

## 12. Giao diện (UI/UX) và Design System

Gần đây app đã có nhiều điều chỉnh để nâng cao trải nghiệm người dùng và tính đồng nhất (premium UI):

- **Empty States**: Sử dụng `AppEmptyState` với minh họa và animation thay vì text trong rỗng.
- **Home Tab**: Weather card được nâng cấp thành "Safety + Weather Hybrid Card" (file `safety_weather_card.dart`) tập trung vào an toàn gia đình, kết hợp gradient và typography hiện đại. Bố trí 2 cột phần trên (Safety bên trái, Weather capsule bên phải) và hàng metric được bọc trong widget `Wrap` để tránh tràn nút (overflow clipping) trên các thiết bị màn hình nhỏ.
- **Reports (Biểu đồ & Sự kiện)**:
  - Chọn khoảng thời gian qua Bottom Sheet có chọn lọc thay vì Dropdown menu để tối ưu mobile UX.
  - Biểu đồ xu hướng tuần được thay thế bằng biểu đồ cột động (`AnimatedWeeklyBarChart`) tích hợp trực tiếp dữ liệu sự kiện từ thực tế, phân tách severity theo các tông màu thống nhất.
  - Fix lỗi layout bị co rút khi xảy ra lỗi tại sự kiện ở phần bottom screen bằng cách set layout full-width và dùng component `AppEmptyState` đồng bộ.
- **Video Upload**: Bổ sung Intro Bottom Sheet (`video_upload_intro_sheet.dart`) để giải thích chi tiết về tính năng gửi video phân tích AI trước khi mở thư viện.
- **Account Tab**: Đồng nhất header (`AccountPageHeader`) và padding cho các trang con (Thông báo, Giao diện, Trợ giúp). Các tính năng chưa hoàn thiện sẽ hiện thông báo "Coming soon". Thêm trang `/notification-settings` cho phép người dùng tùy chỉnh thiết lập cảnh báo.
- **Camera Detail & Video Player**:
  - Khung video được fix cứng tỷ lệ 16:9 để tránh lỗi layout chiếm toàn màn hình trên iPhone, giúp nội dung phía dưới cuộn (scrollable) bình thường, kèm loading/error states rõ ràng.
  - Sự kiện gần đây được làm mới card layout: loại bỏ mock image thumbnail do thực tế backend không cung cấp ảnh thumbnail, hiển thị thông tin thực tế từ backend gồm Duration, Confidence, Room, Status và Severity Badge thống nhất. Xóa bỏ các số liệu test cứng (`999s` / `95%` confidence) do đây là mock data.
  - Cho phép tạm dừng thông báo cảnh báo của camera bằng cách chạm vào nút "Tạm dừng giám sát" với lựa chọn khoảng thời gian giám sát (30m, 2h, 12h, 24h) cùng hiệu ứng countdown chu kỳ giây tuyệt đẹp.
  - **Ngăn ngừa nhấp nháy (Video Player):** Video player được lưu cache và cập nhật trạng thái luồng trực tiếp, giờ chạy, thông báo lỗi qua `CameraVideoPlayerController` thay vì reload widget.

## 13. Điểm cần lưu ý khi tiếp tục sửa code

- Branding đang lệch giữa `WatchNest`, `SilentGuard`, và `SlientGuard`
- Nhiều chuỗi tiếng Việt trong source đang bị lỗi encoding
- App shell đang nằm trong `HomePage`, không phải shell route của `go_router`
- **Gỡ rối (Debugging):** Hiện tượng "silent crash" khi boot thường do cáp kết nối USB không ổn định (mất kết nối ADB) thay vì ứng dụng thực sự bị lỗi. Cần check `flutter devices` khi nghi ngờ.
- **Khởi động ứng dụng (Startup Flow):** Luôn giữ cho khởi động trước `runApp()` ở mức tối thiểu. Các cấu hình bổ sung phải đặt trong `initializeAfterFirstFrame()` và nhường luồng vẽ giao diện (`_yieldToUi()`).
- Auth routing hiện release sớm theo Firebase auth, không đợi backend warm-up xong
- Notification list không chỉ đến từ FCM; startup còn bom thêm pending household invites
- Một số UI trong Automation/Account là placeholder hoặc chưa nối backend thật
- **Flow ghép đôi camera đã được tinh giản:** Chỉ còn quét và lấy Serial Number để đăng ký thẳng lên backend AI, không cần thực hiện bắt tay hay truy vấn SDK Imou/ONVIF trong quá trình ghép đôi.
- **Quản lý phiên Imou:** Bắt buộc phải giải phóng stream session qua `releaseStreamSession` khi đóng trang chi tiết camera để tránh bị khóa luồng hoặc quá giới hạn phiên kết nối trên tài khoản Imou.

## 14. File nên đọc đầu tiên theo từng loại task

Nếu sửa startup/auth/session:

- `lib/main.dart`
- `lib/core/bootstrap/app_initializer.dart`
- `lib/core/router/auth_notifier.dart`
- `lib/core/router/app_router.dart`
- `lib/features/auth/**`
- `lib/features/session/**`

Nếu sửa notifications/invites:

- `lib/core/services/fcm_service.dart`
- `lib/core/services/local_notification_service.dart`
- `lib/features/notifications/**`
- `lib/features/household_invite/presentation/cubit/pending_invites_cubit.dart`

Nếu sửa home/camera/live stream:

- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/home/presentation/pages/camera_detail_page.dart`
- `lib/features/home/presentation/bloc/home_bloc.dart`
- `lib/features/devices/data/datasources/imou_cloud_datasource.dart`
- `lib/features/devices/data/repositories/imou_stream_repository_impl.dart`

If sửa reports:

- `lib/features/reports/presentation/pages/reports_page.dart`
- `lib/features/reports/presentation/cubit/event_history_cubit.dart`
- `lib/features/reports/data/datasources/event_history_remote_datasource.dart`
- `lib/features/reports/presentation/widgets/weekly_trend_chart_card.dart`
- `lib/features/reports/presentation/widgets/animated_weekly_bar_chart.dart`

Nếu sửa account/legal:

- `lib/features/account/**`
- `faq.md`
- `privacy-policy.md`

## 15. Tóm tắt 1 câu

App mobile hiện là một ứng dụng Flutter cho giám sát an toàn gia đình được tối ưu hóa startup flow mượt mà, sử dụng luồng phát trực tiếp từ Imou Cloud với cơ chế tối ưu cập nhật video player không nhấp nháy, tự động giải phóng phiên kết nối khi đóng camera, và hỗ trợ quét QR ghép nối thiết bị cực kỳ đơn giản hóa cùng tính năng đổi hộ gia đình nhanh chóng khi nhận lời mời.

---

## 16. Báo cáo Review Imou Livestream Implementation
*(Thực hiện tự động dựa trên yêu cầu kiểm tra 15 tiêu chí)*

| Mục tiêu / Tiêu chí | File / Vị trí code | Mức độ | Nhận xét / Bằng chứng trong code | Đề xuất sửa |
|---|---|---|---|---|
| **1. Base URL & Request envelope** | `imou_cloud_datasource.dart` | OK | Code dùng đúng URL chuẩn `openapi-sg.easy4ip.com/openapi`, kèm đầy đủ các trường `system.ver`, `appId`, `time`, `nonce`, `sign` (MD5 lowercase). Không lộ `appSecret` trong log. | Giữ nguyên. |
| **2. `deviceSn` vs `deviceId`** | `imou_cloud_datasource.dart` | OK | Nội bộ truyền biến `deviceSn` nhưng params gửi lên API dùng đúng key `deviceId`. Không lẫn lộn. | Giữ nguyên. |
| **3. `bindDevice` và `code`** | `imou_cloud_datasource.dart` | OK | Flow xem live không gọi `bindDevice` (chỉ dùng lúc pairing). Quá trình lấy luồng đi chuẩn xác: `accessToken → bindDeviceLive → getLiveStreamInfo → player.open`. | Giữ nguyên. |
| **4. Default stream SD** | `imou_stream_repository_impl.dart` | OK | Có hằng số `_defaultStreamId = 1` và được truyền mặc định vào `bindDeviceLive` / `getLiveStreamInfo`. | Giữ nguyên. |
| **5. Response shape** | `imou_models.dart`, `imou_cloud_datasource.dart` | OK | Code tách biệt: `bindDeviceLive` đọc `liveToken` từ root, trong khi `getLiveStreamInfo` parse từ mảng `streams[]` bằng `_parseLiveStreams()`. | Giữ nguyên. |
| **6. Chọn stream priority** | `imou_models.dart` (getter `selectedStream`) | OK | Hàm duyệt bằng mảng `[1, 0]` kết hợp ưu tiên HTTPS trước HTTP đúng chuẩn ưu tiên luồng SD. | Giữ nguyên. |
| **7. Quản lý `liveToken`** | `imou_models.dart`, `imou_stream_repository_impl.dart` | OK | `liveToken` ưu tiên lấy từ selected stream, nếu thiếu thì fallback về `bindLiveToken`. Lưu trong đối tượng `_ImouStreamSession`. | Giữ nguyên. |
| **8. `unbindLive`** | `imou_stream_repository_impl.dart`, `home_bloc.dart` | **High** | Có **Race Condition**: Nếu user thoát màn hình *trong khi API getLiveStreamInfo đang pending*, event `CameraDetailClosed` kích hoạt hàm release nhưng không tìm thấy session (do chưa được lưu). Sau đó API trả về, session mới được lưu vào `_activeSessions` và kẹt lại vĩnh viễn không bao giờ được unbind. | Thêm cờ hủy (cancellation flag) hoặc danh sách các `deviceId` vừa bị đóng để block việc tạo session mới hoặc lập tức gọi unbind ngay khi API trả kết quả. |
| **9. `accessToken` cache** | `imou_cloud_datasource.dart` | OK | Tính đúng `DateTime.now().add(Duration(seconds: ...))` và trừ hao 600s (10 phút). Có cơ chế refresh token đúng 1 lần khi lỗi expired. | Giữ nguyên. |
| **10. Tách lỗi API vs Playback** | `home_bloc.dart`, `camera_detail_page.dart` | OK | Lỗi API emit `CameraStreamUrlFailure`, lỗi player emit `CameraPlaybackFailure`. Không báo "Camera offline" do lỗi trình phát. | Giữ nguyên. |
| **11. VideoPlayer lifecycle** | `camera_detail_page.dart` | OK | Không truyền URL giả (unavailable) vào trình phát nữa. Có Loading indicator rõ ràng khi pending. | Giữ nguyên. |
| **12. Retry playback bằng `media_kit`** | `camera_video_player.dart` | OK | Cấu hình `_retryDelays = [2, 4, 6]`. Có thử mở lại URL nếu lỗi mà không thoát ngay, không gọi unbind khi retry. | Giữ nguyên. |
| **13. Android HTTP cleartext** | `AndroidManifest.xml` | OK | Đã khai báo `android:usesCleartextTraffic="true"`. Sẵn sàng cho luồng fallback HTTP. | Giữ nguyên. |
| **14. Codec & Cue 2E** | `camera_video_player.dart` | OK | `media_kit` (FFmpeg) hỗ trợ cả H.264 và H.265, code không ép cứng codec nào. | Giữ nguyên. |
| **15. Tests** | Thư mục `test/` | **Medium** | Đã cover tốt cho `ImouCloudDataSourceImpl` (`imou_cloud_datasource_test.dart`). Tuy nhiên **thiếu test** cho `ImouStreamRepositoryImpl` và luồng mở stream của `HomeBloc` (đặc biệt là test race condition). | Viết bổ sung Unit test cho Repository và HomeBloc. |

### Đề xuất thứ tự sửa:
1. **(High) Sửa lỗi rò rỉ kết nối (Race Condition) trong `ImouStreamRepositoryImpl`:** Khắc phục ngay để đảm bảo account Imou không bị quá tải session ảo.
2. **(Medium) Bổ sung Unit Tests:** Cập nhật test suites để bao phủ các luồng fallback và cancelation mới thêm.
