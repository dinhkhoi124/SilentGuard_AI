# SilentGuard App Context

Tai lieu nay tom tat trang thai hien tai cua ung dung Flutter trong thu muc `mobile/`.
Muc tieu la giup nhung lan tiep theo doc nhanh codebase, hieu startup flow, auth flow, notification flow, va xac dinh nhanh feature nam o dau.

## 1. Muc tieu cua app

SilentGuard/AnNha la ung dung Flutter danh cho caregiver va gia dinh:

- Dang nhap bang Firebase Auth.
- Dong bo session nguoi dung voi backend FastAPI.
- Theo doi danh sach camera, xem chi tiet camera, xem luong live stream.
- Nhan fall alert qua FCM va luu lich su thong bao trong app.
- Them/ghep noi camera qua QR va Imou Cloud.
- Tai video tu thu vien len backend de phan tich su kien.
- Quan ly tai khoan, giao dien ung dung, onboarding, va mot so cai dat co ban.

Ngon ngu hien thi chinh la tieng Viet.

## 2. Stack va kien truc

- Flutter + Material 3
- BLoC/Cubit cho state management
- GoRouter cho routing
- GetIt cho dependency injection
- Clean Architecture theo tung feature
- Firebase Auth, Firebase Messaging, Firebase Core
- `shared_preferences` / `SharedPreferencesAsync` cho local persistence nhe
- `flutter_local_notifications` cho local notification foreground / tap handling
- `media_kit` cho live stream

Kien truc tong quan:

- `core/`: bootstrap, router, theme, network, service dung chung
- `features/`: moi domain nghiep vu tach rieng theo clean architecture
- `injection_container.dart`: dang ky dependency cho toan app
- `main.dart`: khoi tao Firebase, DI, theme, router, background FCM handler

## 3. Cau truc thu muc app

### 3.1 Thu muc goc trong `mobile/lib`

- `core/`
- `features/`
- `firebase_options.dart`
- `injection_container.dart`
- `main.dart`

### 3.2 `core/`

- `bootstrap/`
  - `app_initializer.dart`: khoi dong sau first frame, local notification init, initial FCM handling
- `config/`
  - `app_config.dart`: base URL, timeout, cac config runtime
- `network/`
  - `api_client.dart`: HTTP client dung chung cho backend FastAPI
  - `auth_interceptor.dart`: gan Firebase ID token vao request backend
- `router/`
  - `app_router.dart`: route list va redirect logic
  - `auth_notifier.dart`: source of truth cho startup/auth routing
- `services/`
  - `fcm_service.dart`: foreground/opened FCM handling, token register
  - `local_notification_service.dart`: local notification channel, show, tap
  - `onboarding_service.dart`: luu co onboarding da xem
- `theme/`
  - `app_theme.dart`: light theme, dark theme
  - `theme_controller.dart`: doc/ghi `ThemeMode`
- `utils/`
  - `app_colors.dart`
- `widgets/`
  - widget dung chung nhu `WaveTextLoader`

### 3.3 `features/`

- `account/`
  - trang tai khoan (`AccountPage`)
  - trang giao dien ung dung / dark mode (`AppAppearancePage`)
  - trang ho tro, FAQ, va Privacy Policy (`HelpSupportPage`, `FaqPage`, `PrivacyPolicyPage`)
- `auth/`
  - Firebase auth datasource/repository
  - `AuthBloc`
  - `WelcomePage`, `SignUpPage`
- `devices/`
  - pairing flow (`DevicePairingPage`, `DevicePairingBloc`)
  - permission, gallery image, va QR decode datasources (`DevicePermissionDataSource`, `GalleryImageDataSource`, `QrCodeDataSource`)
  - Imou Cloud datasource va repository (`ImouCloudDataSource`, `ImouStreamRepository`)
  - backend camera datasource/repository (`DeviceRemoteDataSource`, `DeviceRepository`)
- `home/`
  - `HomeBloc`
  - home page, weather card, camera card, camera detail
  - alert review repository/use case
- `notifications/`
  - local notification entity
  - local datasource luu danh sach thong bao
  - `NotificationsCubit`
  - `NotificationsPage`
- `onboarding/`
  - onboarding UI va paging flow
- `session/`
  - backend session provisioning sau Firebase auth
  - household/session entity
  - session repository
- `video_upload/`
  - upload video tu gallery
  - remote datasource + repository + usecase + bloc

## 4. Startup flow hien tai

Startup hien tai theo huong giam block main thread va giu route on dinh:

1. Truoc `runApp()`
- `WidgetsFlutterBinding.ensureInitialized()`
- `FlutterNativeSplash.preserve(...)`
- `Firebase.initializeApp(...)`
- dang ky `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`
- `di.init()`
- `ThemeController.load()`

2. `runApp()`
- app dung `MaterialApp.router`
- theme mode lay tu `ThemeController`
- locale dang set `vi_VN`
- `AuthBloc`, `VideoUploadBloc`, `NotificationsCubit` duoc provide o root

3. Sau first frame
- `AppInitializer.initializeAfterFirstFrame()`
- init local notifications
- xu ly initial FCM message neu app mo tu terminated state
- xu ly local notification launch payload neu app mo tu local notification

4. Auth routing
- `AuthNotifier` lang nghe `authStateChanges()`
- neu co Firebase user, app provisioning session voi backend truoc khi roi `/loading`
- neu backend chua san sang, `AuthNotifier` giu app o `/loading` va retry silently
- router chi roi `/loading` khi auth/session da xac dinh du

## 5. Auth va session flow

### 5.1 Firebase auth

- Email/password sign-in va sign-up
- Google sign-in
- `AuthBloc` la UI-facing bloc cho login/logout

### 5.2 Backend session

- `SessionRepository.provisionSession()` dong bo Firebase auth voi backend
- backend login endpoint: `POST /api/users/login`
- household endpoint: `GET /api/households/me`
- session cache duoc giu trong `SessionRepository`

### 5.3 Cold start backend handling

Backend Render free tier co the warm-up cham, nen:

- login backend co timeout rieng dai hon
- session provisioning retry voi exponential backoff
- auth routing khong nhay vao `/home` neu backend chua san sang
- `HomeBloc` phan biet:
  - backend unavailable
  - unauthorized
  - generic error

## 6. Notification va alert flow

### 6.1 FCM lifecycle dang co

- Foreground:
  - `FirebaseMessaging.onMessage`
  - parse thanh `NotificationAlert`
  - persist vao `NotificationsCubit`
  - show local notification qua `LocalNotificationService`

- Background:
  - `firebaseMessagingBackgroundHandler`
  - init Firebase neu can
  - persist minimal alert vao local store

- Opened from background:
  - `FirebaseMessaging.onMessageOpenedApp`
  - persist vao `NotificationsCubit`
  - navigate den camera neu co `cameraId`

- Opened from terminated:
  - `getInitialMessage()`
  - persist vao `NotificationsCubit`
  - navigate an toan sau init

- Local notification tap:
  - parse payload
  - persist vao `NotificationsCubit`
  - navigate den camera neu co `cameraId`

### 6.2 Local notification persistence

- `NotificationLocalDataSource`
- key luu: `app_notifications`
- gioi han: 100 items
- dedupe uu tien:
  - `event_id`
  - sau do `messageId`
  - sau do fallback stable id

### 6.3 Notifications UI

- `NotificationsPage`
- danh sach doc tu `NotificationsCubit`
- mo page se reload local store
- app resume cung reload local store
- backend pending-alert sync hien chua co endpoint that, dang de TODO-friendly hook

## 7. Home flow

`HomeBloc` hien quan ly:

- weather
- camera device list
- room filter
- delete device
- thumbnail capture
- warm-up state khi backend chua san sang
- unauthorized state khi session that bai thuc su
- yeu cau lay duong dan luong phat truc tiep (`CameraStreamUrlRequested` event, cac trang thai: `CameraStreamUrlLoading`, `CameraStreamUrlLoaded`, `CameraStreamUrlFailure`) qua `ImouStreamRepository`

Home UI gom:

- weather card
- room filter chips
- camera grid
- bottom navigation
- floating action buttons

## 8. Camera / device flow

### 8.1 Pairing

- quet QR live hoac tu image gallery
- resolve serial/device info
- goi Imou Cloud datasource
- save paired device len backend

### 8.2 Camera detail

- mo route `/camera/:id` (yeu cau `BlocProvider` cho `HomeBloc` duoc cung cap trong `app_router.dart` de gui nhan event)
- gui event `CameraStreamUrlRequested` den `HomeBloc` de lay luong phat dynamic tu Imou Cloud qua repository
- lang nghe URL stream qua `BlocListener`/`BlocBuilder` cua `HomeBloc` de cap nhat giao dien loading/error/success dynamic
- live stream qua `media_kit` (su dung widget `CameraVideoPlayer` / `CameraLivePreview` ho tro loading indicator, hien thi thong bao loi va nut "Tai lai" khi ket noi stream that bai)
- co callback chup thumbnail tra ve `HomeBloc` va tu dong dispose controller/player subscriptions
- **Lich su su kien**: Hien tai Camera Detail tam thoi hien thi toan bo lich su su kien cua ho gia dinh (giong Reports tab) do backend chua ho tro loc theo `camera_id`. Se chuyen sang loc theo `camera_id` khi backend ho tro query param nay.

### 8.3 Device CRUD

- list camera: `GET /api/cameras`
- create camera: `POST /api/cameras`
- delete camera: `DELETE /api/cameras/{camera_id}`

## 9. Weather flow

- hien tai lay weather truc tiep tu Open-Meteo cho Ha Noi
- weather logic nam trong home data layer
- `WeatherCard` chi la UI, logic fetch khong nam trong widget

## 10. Video upload flow

Feature upload video:

- nut "Gui video" trong bottom navigation
- mo gallery bang `image_picker`
- lay `household_id` tu `SessionRepository`
- upload qua `POST /api/events/upload-video`
- app chi thong bao success/failure
- khong poll, khong call detect endpoint, khong xu ly AI result trong app

## 11. Theme va dark mode

- `ThemeController` luu `ThemeMode`
- `AppTheme.light` va `AppTheme.dark` da ton tai
- `MaterialApp.router` da wire:
  - `theme`
  - `darkTheme`
  - `themeMode`
- dark mode da duoc polish lai cho:
  - Home
  - Account
  - bottom nav
  - chip/card chinh

## 12. Cac route quan trong

- `/loading`
- `/onboarding`
- `/welcome`
- `/signup`
- `/home`
- `/add-device`
- `/app-appearance`
- `/help-support`
- `/faq`
- `/privacy-policy`
- `/notifications`
- `/camera/:id`

## 13. Dependency dang ky trong DI

Nhung khoi quan trong dang duoc dang ky trong `injection_container.dart`:

- Firebase services
- `ApiClient`
- `ThemeController`
- `AuthNotifier`
- `FcmService`
- `LocalNotificationService`
- `NotificationsCubit`
- `AuthBloc`
- `HomeBloc` (lay getWeather, getCameraDevices, deleteCameraDevice, imouStreamRepository, sessionRepository)
- `VideoUploadBloc`
- `DevicePairingBloc`
- session, home (bao gom `AlertReviewRepository`), device (bao gom `ImouStreamRepository`), upload repositories va use cases
- `EventHistoryCubit` (doc `SessionRepository.currentHouseholdId` noi bo; khong yeu cau truyen householdId tu ngoai)
- `EventHistoryRepository`, `EventHistoryRemoteDataSource`, `GetEventHistory` use case

## 14. Backend/API dang dung

Nhom API chinh:

- Auth/session
  - `POST /api/users/login`
  - `POST /api/users/logout`
  - `GET /api/households/me`
  - `POST /api/users/device-token`

- Cameras
  - `GET /api/cameras`
  - `POST /api/cameras`
  - `DELETE /api/cameras/{camera_id}`

- Alerts/events
  - `PATCH /api/alerts/{event_id}/review`
  - `POST /api/events/{event_id}/feedback` — (Camera Detail) Submit AI accuracy feedback (`label`, `note`).
  - `POST /api/events/upload-video`
  - `GET /api/events/history` — toan bo lich su su kien (Reports tab, `EventHistoryRemoteDataSource`)
    - Query params: `household_id` (bat buoc), `severity`, `room`, `from_date`, `to_date`, `page`, `page_size`
    - URI duoc xay dung qua `ApiClient.getObjectWithQuery` (su dung `Uri.replace(queryParameters: ...)` de tu dong percent-encode)
    - Response: `{ items: [...], total, page, page_size }`
    - Khong co truong `llm_message`; title/subtitle tu dong sinh tu severity + room + status + duration_sec

- Weather
  - Open-Meteo direct mobile call

## 15. Nhung diem dang can luu y

- Codebase con mot so file cu bi loi encoding text tieng Viet; khi sua nen can than voi UTF-8.
- Notification pending-alert sync tu backend chua co endpoint list ro rang trong app, moi co local persistence + TODO hook.
- Nhiu screen van dang la placeholder cho feature sau nay.
- Worktree co the dang dirty; can doc ky truoc khi sua cac file da bi thay doi o turn truoc.

## 16. File nen doc dau tien khi vao task

Neu lam startup/auth:

- `lib/main.dart`
- `lib/core/bootstrap/app_initializer.dart`
- `lib/core/router/auth_notifier.dart`
- `lib/core/router/app_router.dart`
- `lib/features/session/**`

Neu lam thong bao:

- `lib/core/services/fcm_service.dart`
- `lib/core/services/local_notification_service.dart`
- `lib/features/notifications/**`

Neu lam home/camera:

- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/home/presentation/widgets/camera_card.dart`
- `lib/features/home/presentation/pages/camera_detail_page.dart`
- `lib/features/home/presentation/widgets/camera_video_player.dart`
- `lib/features/devices/**`

Neu lam giao dien/toi uu theme:

- `lib/core/theme/app_theme.dart`
- `lib/core/theme/theme_controller.dart`
- `lib/core/utils/app_colors.dart`
- `lib/features/account/presentation/pages/account_page.dart`

Neu lam Reports tab / event history:

- `lib/features/reports/presentation/pages/reports_page.dart`
- `lib/features/reports/presentation/cubit/event_history_cubit.dart`
- `lib/features/reports/presentation/cubit/event_history_state.dart`
- `lib/features/reports/presentation/mappers/event_history_display_mapper.dart`
- `lib/features/reports/domain/entities/event_history_item.dart`
- `lib/features/reports/data/datasources/event_history_remote_datasource.dart`

## 17. Tom tat mot cau

SilentGuard la mot Flutter app theo Clean Architecture, dung Firebase Auth + FastAPI backend + FCM/local notifications + media live stream, trong do startup/auth/notification flow da duoc tach kha ro rang va toan bo code hien tai xoay quanh cac feature `auth`, `session`, `home`, `devices`, `notifications`, `account`, `video_upload`, va `reports` (da ket noi real API cho event history).
