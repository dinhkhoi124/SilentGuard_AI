# App Core Guide

Nguồn doc này được tổng hợp từ branch `origin/feature/app-improvements`.

## Kết luận nhanh

App chính nằm trong `mobile/`. Đây là app Flutter cho iOS/Android, dùng Material 3, BLoC, go_router, get_it, Firebase Auth/FCM/Crashlytics, Imou Cloud livestream, local notifications, video upload và reports.

Branch có `mobile/APP_CONTEXT.md` là tài liệu nội bộ rất chi tiết. Guide này rút gọn những điểm cần biết để setup và tiếp tục phát triển.

## Thư mục chính

```text
mobile/
  pubspec.yaml
  lib/
    main.dart
    firebase_options.dart
    injection_container.dart
    core/
      bootstrap/
      config/
      connectivity/
      network/
      router/
      services/
      theme/
      utils/
      widgets/
    features/
      account/
      auth/
      automation/
      devices/
      home/
      household_invite/
      notifications/
      onboarding/
      reports/
      rtmp_live/
      session/
      video_upload/
  android/
  ios/
  assets/images/
  faq.md
  privacy-policy.md
```

## Cách chạy

```powershell
cd mobile
flutter pub get
flutter run
```

Build Android:

```powershell
flutter build apk --release
```

Build iOS cần môi trường macOS/Xcode:

```bash
flutter build ipa --release
```

## Dependencies chính

Theo `mobile/pubspec.yaml`:

```text
flutter_bloc, bloc, equatable
go_router
get_it
dartz
http
firebase_core, firebase_auth, firebase_messaging, firebase_crashlytics
google_sign_in
flutter_local_notifications
shared_preferences
media_kit, media_kit_video, media_kit_libs_android_video, media_kit_libs_ios_video
mobile_scanner, image_picker, permission_handler
connectivity_plus, internet_connection_checker_plus
flutter_native_splash
url_launcher
intl
```

## Compile-time config

`mobile/lib/core/config/app_config.dart` dùng `String.fromEnvironment`.

Mặc định branch app:

```text
API_BASE_URL=https://c2-app-128-production-b968.up.railway.app
IMOU_API_BASE_URL=https://openapi-sg.easy4ip.com/openapi
GOOGLE_SIGN_IN_SERVER_CLIENT_ID=...
IMOU_APP_ID=...
IMOU_APP_SECRET=...
networkTimeout=15s
```

Override khi chạy:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=IMOU_API_BASE_URL=https://openapi-sg.easy4ip.com/openapi
```

Cần lưu ý: branch hiện tại có default Imou app id/secret trong source. Nếu đưa vào production, nên chuyển sang secret/runtime config phù hợp.

## Startup flow

Theo `mobile/main.dart` và `mobile/APP_CONTEXT.md`:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `FlutterNativeSplash.preserve(...)`.
3. Gọi `runApp(BootstrapApp(...))` sớm để vẽ first frame.
4. Sau first frame, `AppInitializer.initializeAfterFirstFrame()` mới khởi tạo Firebase, Crashlytics, DI, theme, suppress service, local notifications, pending invites và FCM setup.
5. `AuthNotifier` chỉ gỡ splash khi auth state, onboarding flag và minimum splash delay đã sẵn sàng.

Mục tiêu của flow này là tránh ANR/cold-start chậm trên mobile.

## Router và màn hình

Router nằm ở `mobile/lib/core/router/app_router.dart`.

Routes:

```text
/loading
/onboarding
/welcome
/signup
/home
/add-device
/emergency-contacts
/app-appearance
/help-support
/faq
/privacy-policy
/notifications
/notification-settings
/camera/:id
```

`HomePage` là app shell thực tế sau login và quản lý 5 tab bằng `IndexedStack`:

```text
1. Home
2. Automation
3. Live RTMP
4. Reports
5. Account
```

## Dependency Injection

`mobile/lib/injection_container.dart` dùng `GetIt`.

Core singleton/factory gồm:

- FirebaseAuth, FirebaseMessaging;
- HTTP client và `ApiClient`;
- một `ApiClient` riêng instanceName `imou` cho Imou Cloud;
- SharedPreferences;
- MonitoringSuppressService, OnboardingService, PhoneDialerService;
- AuthNotifier, AuthBloc;
- FcmService, LocalNotificationService, DailyReportNotificationService;
- HomeBloc, DevicePairingBloc, VideoUploadBloc, RtmpLiveBloc;
- EventHistoryCubit, DailySummaryCubit, CameraEventHistoryCubit;
- PendingInvitesCubit, InviteManagementCubit;
- ImouCloudDataSource, ImouStreamRepository;
- DeviceRepository, SessionRepository, HomeRepository.

## Feature map

```text
features/auth
  Firebase auth, email/password, Google sign-in, sign-out.

features/session
  Backend session, household, switch household.

features/home
  Camera dashboard, camera detail, event history, feedback/review,
  weather, suppress monitoring, stream URL loading.

features/devices
  QR pairing, serial extraction, save paired device len backend.

features/notifications
  FCM/local notification list, pending household invites.

features/reports
  Event history, daily summary, weekly trend.

features/automation
  Automation UI, emergency contacts local data, status/rules/timeline.

features/rtmp_live
  RTMP livestream tab dùng media_kit.

features/video_upload
  Pick video, upload lên backend, trigger analysis flow.

features/account
  Account, appearance, help, FAQ, privacy, notification settings.
```

## Backend API app đang dùng

Theo `mobile/api_endpoints.md` và source:

```text
POST /api/users/login
POST /api/users/logout
POST /api/users/device-token
POST /api/users/switch-household

GET  /api/households/me
GET  /api/households/{householdId}/members
POST /api/households/invite-by-email
GET  /api/households/invite-requests/pending
POST /api/households/invite-requests/{inviteRequestId}/respond

GET    /api/cameras
POST   /api/cameras
DELETE /api/cameras/{deviceId}

GET   /api/events/history
GET   /api/reports/daily
POST  /api/events/upload-video
PATCH /api/alerts/{eventId}/review
POST  /api/events/{eventId}/feedback
```

Ngoài backend SilentGuard, app dùng:

- Open-Meteo cho weather;
- Imou Cloud API: `/accessToken`, `/bindDeviceLive`, `/getLiveStreamInfo`, `/unbindLive`, `/deviceList`.

## Notification flow

- Foreground FCM: filter suppress local, lưu message, hiện local notification.
- Background FCM: background handler lưu message vào `SharedPreferences`, filter suppress nếu type `fall_alert`.
- Open from notification: nếu có `cameraId` thì vào `/camera/:id`, nếu không thì `/home`.
- Local persistence key: `app_notifications`, tối đa 100 item.
- Pending household invites cũng được inject vào notification list lúc startup.

## Lưu ý khi tiếp tục

- Branding trong branch có nơi chưa thống nhất: `WatchNest`, `SilentGuard`, và typo `SlientGuard`.
- Một số UI trong Automation/Account là scaffold/coming-soon.
- Auth routing release sớm theo Firebase user, không đợi backend session provisioning xong mới vào app.
- Khi đóng camera detail, app cần release Imou stream session để tránh leak/live session limit.
- `mobile/APP_CONTEXT.md` có review chỉ ra race condition tiềm ẩn trong `ImouStreamRepositoryImpl` khi thoát camera detail trong lúc request stream đang pending. Nên đọc kỹ trước khi sửa livestream.
