# Mobile App Context

Tai lieu nay tom tat trang thai hien tai cua app Flutter trong thu muc `mobile/`.
Muc tieu la giup lan sau nhin nhanh codebase, startup flow, auth flow, notification flow, va vi tri cua tung feature.

## 1. App nay la gi

App mobile hien dang la mot ung dung Flutter cho bai toan giam sat an toan trong gia dinh, tap trung vao camera, canh bao su co, va phan hoi nhanh.

Branding trong code hien chua thong nhat:

- `MaterialApp.title` dang la `WatchNest`
- Android/iOS/legal content van dung ten `SilentGuard`
- Mot so text UI con go sai `SlientGuard`

Neu can lam viec lien quan branding, can check ca UI, manifest, markdown asset, va legal copy.

## 2. Stack va kien truc

- Flutter + Material 3
- `flutter_bloc` / `bloc`
- `go_router`
- `get_it`
- Firebase Core, Auth, Messaging, Crashlytics
- `flutter_local_notifications`
- `shared_preferences`
- `media_kit`
- `mobile_scanner`, `image_picker`, `permission_handler`
- `http`

Kien truc tong quan:

- `lib/core/`: bootstrap, router, theme, network, services
- `lib/features/`: chia theo feature/domain
- `lib/injection_container.dart`: DI registry
- `lib/main.dart`: app bootstrap

Day la clean-ish feature architecture, nhung thuc te co pha tron giua domain/data/presentation tuy feature.

## 3. Runtime va config quan trong

File chinh:

- `lib/main.dart`
- `lib/core/bootstrap/app_initializer.dart`
- `lib/core/router/app_router.dart`
- `lib/core/router/auth_notifier.dart`
- `lib/core/config/app_config.dart`
- `lib/injection_container.dart`

Config runtime dang dung:

- Backend base URL mac dinh: `https://c2-app-128-production.up.railway.app`
- Imou base URL: `https://openapi-sg.easy4ip.com/openapi`
- Network timeout mac dinh: 15s
- ONVIF discovery timeout: 6s

## 4. Startup flow hien tai

### 4.1 Truoc `runApp()`

Trong `lib/main.dart`:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `FlutterNativeSplash.preserve(...)`
3. `Firebase.initializeApp(...)`
4. dang ky `FirebaseMessaging.onBackgroundMessage(...)`
5. `di.init()`
6. `ThemeController.load()`
7. tao `AppRouter`
8. `runApp(BootstrapApp(...))`

### 4.2 Sau first frame

`BootstrapApp` goi `AppInitializer.initializeAfterFirstFrame()` de day cac viec plugin/platform-channel sang sau first frame:

- bat Crashlytics hooks
- resolve lai DI neu can
- init local notifications
- doc initial FCM alert neu app mo tu terminated state
- xu ly tap vao local notification neu app duoc mo bang notification local
- load pending household invites va dua vao notification list local

Sau do `scheduleMessagingSetup(...)` moi setup FCM listeners chinh thuc.

### 4.3 Splash va auth readiness

`AuthNotifier` chi release router khi du 3 dieu kien:

- auth state da resolve
- onboarding flag da load
- minimum splash delay 900ms da qua

Khi du dieu kien, `FlutterNativeSplash.remove()` moi duoc goi.

## 5. Auth va session flow

### 5.1 Firebase auth

Auth layer nam o:

- `features/auth/data/datasources/firebase_auth_datasource.dart`
- `features/auth/data/repositories/auth_repository_impl.dart`
- `features/auth/presentation/bloc/auth_bloc.dart`

UI auth chinh:

- `/welcome`
- `/signup`

Code hien co ho tro:

- email/password
- Google sign-in
- sign-out

### 5.2 Router auth logic

`AuthNotifier` lang nghe `authStateChanges()` va quyet dinh 3 pha:

- `checkingSession`
- `unauthenticated`
- `authenticated`

Luu y quan trong: code hien tai KHONG con doi backend session provisioning xong moi cho vao app.
Ngay khi Firebase user ton tai, router co the roi `/loading` de vao `/home`.
Phan backend/session se do cac bloc/repository xu ly tiep.

Day la khac biet quan trong so voi mot so tai lieu cu.

### 5.3 Backend session

Session layer nam o:

- `features/session/data/datasources/session_remote_datasource.dart`
- `features/session/data/repositories/session_repository_impl.dart`
- `features/session/domain/repositories/session_repository.dart`

Session repository duoc su dung boi:

- `AuthBloc`
- `HomeBloc`
- `VideoUploadBloc`
- `EventHistoryCubit`
- cac data source can `household_id`

## 6. Notification flow

Thanh phan chinh:

- `core/services/fcm_service.dart`
- `core/services/local_notification_service.dart`
- `core/services/monitoring_suppress_service.dart`
- `features/notifications/data/datasources/notification_local_data_source.dart`
- `features/notifications/presentation/cubit/notifications_cubit.dart`
- `features/notifications/presentation/pages/notifications_page.dart`
- `features/notifications/presentation/widgets/notification_segmented_tab_bar.dart`

Flow hien tai:

- Foreground FCM: kiem tra suppress locally truoc. Neu khong bi suppress: ghi nhan tin nhan + hien thi local notification qua `LocalNotificationService`.
- Background FCM: `firebaseMessagingBackgroundHandler` luu tru tin nhan bang `NotificationLocalDataSource.saveBackgroundMessage(...)`.
- Open from terminated: `AppInitializer` kiem tra suppress, doc tin nhan va dieu huong.
- Open from local notification: dieu huong den camera detail hoac trang chu.

Local persistence:

- key: `app_notifications`
- toi da: 100 item

Navigation tu notification:

- neu co `cameraId` -> `go('/camera/:id')`
- neu khong -> `go('/home')`

Ngoai FCM, startup con inject pending household invites vao notification list de user thay loi moi.

Tich hop Suppression:
- `FcmService` tich hop `MonitoringSuppressService` de loc bo cac canh bao `fall_alert` tu camera dang trong thoi gian tam dung giam sat (suppressed).

## 7. Navigation va app shell

Router top-level nam trong `lib/core/router/app_router.dart`.

Route hien co:

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

Luu y:

- `/faq` dang duoc khai bao 2 lan trong router, can cleanup neu sua router
- khong co nested shell route; `HomePage` tu quan ly 4 tab bang `IndexedStack`

4 tab trong `HomePage`:

1. Home
2. Automation
3. Reports
4. Account

## 8. Feature map theo code hien tai

### 8.1 `features/home`

Day la feature trung tam cho camera dashboard.

Thanh phan chinh:

- `HomeBloc`
- `HomePage`
- `CameraDetailPage`
- `SuppressCubit`
- `MonitoringSuppressService`
- widgets cho safety_weather_card, camera grid, room filter, camera card, camera_action_buttons

`HomeBloc` quan ly it nhat cac viec sau:

- load weather
- load danh sach camera
- room filter
- delete camera
- thumbnail capture cache
- stream URL loading cho camera detail
- backend warm-up state
- unauthorized state

`SuppressCubit` & `MonitoringSuppressService`:
- Quan ly viec tam dung giam sat/gui canh bao tu camera theo thoi gian duoc chon (30 phut, 2 gio, 12 gio, 24 gio).
- Luu tru thoi gian tam dung vao `SharedPreferencesAsync`.
- Cap nhat bo dem nguoc realtime va cap nhat trang thai UI cua nut bam trong `CameraDetailPage`.

### 8.2 `features/devices`

Tap trung vao pairing va camera connectivity:

- `DevicePairingBloc`
- `DevicePairingPage`
- QR parsing
- permission handling
- gallery image import
- Imou cloud datasource
- ONVIF-related entities/utils
- backend camera persistence

Route pairing:

- `/add-device`

### 8.3 `features/reports`

Bao cao va lich su su kien:

- `ReportsPage`
- `EventHistoryCubit`
- `EventHistoryRemoteDataSource`
- `WeeklyEventTrendAggregator`
- `WeeklyTrendChartCard`
- `AnimatedWeeklyBarChart`
- mapper de bien event history thanh display model

API dang dung:

- `GET /api/events/history`

Query params hien co:

- `household_id`
- `page`
- `page_size`
- `severity`
- `room`
- `from_date`
- `to_date`

Bieu do xu huong tuan (Weekly Trend Chart):
- Lay du lieu that tu backend thong qua `EventHistoryCubit` voi bo loc thoi gian 7 ngay gan nhat.
- Su dung `WeeklyEventTrendAggregator` de nhom cac su kien theo tung thu trong tuan va theo muc do nghiem trong (severity).
- Hien thi bieu do cot dong `AnimatedWeeklyBarChart` phan chia theo mau sac cua muc do su co.

### 8.4 `features/automation`

Day la tab giao dien cho automation/emergency response.

Hien co:

- `AutomationPage`
- status card
- rules section
- severity timeline
- emergency contacts preview
- quiet window card
- AI config card

Tinh trang hien tai:

- mot phan la UI scaffold / coming-soon interaction
- emergency contacts co feature data local rieng

### 8.5 `features/automation` - emergency contacts

Data va state:

- `EmergencyContactsLocalDataSource`
- `EmergencyContactsRepositoryImpl`
- `EmergencyContactsCubit`
- `EmergencyContactsPage`

Route:

- `/emergency-contacts`

### 8.6 `features/household_invite`

Feature nay da co trong codebase du chua duoc surfacing manh o router:

- remote datasource
- `InviteManagementCubit`
- `PendingInvitesCubit`
- widgets `invite_dialog.dart`, `invite_management_sheet.dart`

Startup hien co fetch pending invites va dua vao notifications list.

### 8.7 `features/account`

Trang account nam trong tab thu 4 cua `HomePage`.

Hien co:

- `AccountPage`
- `AppAppearancePage`
- `HelpSupportPage`
- `FaqPage`
- `PrivacyPolicyPage`
- `NotificationSettingsPage`
- `AccountPageHeader` (Header thong nhat cho cac trang con thuoc Account)

Asset markdown:

- `faq.md`
- `privacy-policy.md`

### 8.8 `features/video_upload`

Feature upload video phan tich su kien:

- `VideoUploadBloc`
- `UploadVideoUseCase`
- `VideoUploadRemoteDatasource`

Trigger:

- nut upload o bottom navigation

Flow tong quat:

1. user chon upload
2. bloc lay video tu gallery
3. doc `household_id` tu session
4. upload len backend
5. show success/failure snackbar

### 8.9 `features/onboarding`

- `OnboardingPage`
- onboarding completion duoc luu qua `OnboardingService`
- auth router dung flag nay de quyet dinh vao `/onboarding` hay `/welcome`

## 9. Home tab va camera detail

### 9.1 Home tab

`HomePage` la app shell thuc te sau login.

No chua:

- app bar + unread notification badge
- 4-tab `IndexedStack`
- upload progress line
- FAB them device
- notification snackbar foreground

### 9.2 Camera detail

Route:

- `/camera/:id`

Neu route co `extra` la `CameraDevice` hoac `CameraDetailArgs` thi vao thang detail.
Neu chi co `id`, router dung `_CameraRouteLoader` de fetch danh sach camera roi tim device.

Camera detail hien tai phu thuoc vao:

- `HomeBloc` cho stream URL request
- `ImouStreamRepository`
- `media_kit`
- event history cubit cho lich su su kien
- event feedback / alert review cubit cho phan hoi nguoi dung

## 10. Dependency Injection snapshot

`lib/injection_container.dart` dang dang ky cac khoi chinh sau:

- FirebaseAuth
- FirebaseMessaging
- `ApiClient`
- `ThemeController`
- `OnboardingService`
- `PhoneDialerService`
- `AuthNotifier`
- `LocalNotificationService`
- `FcmService`
- `MonitoringSuppressService`
- `NotificationsCubit`
- `AuthBloc`
- `HomeBloc`
- `VideoUploadBloc`
- `SuppressCubit`
- `DevicePairingBloc`
- `EmergencyContactsCubit`
- `InviteManagementCubit`
- `PendingInvitesCubit`
- `AlertReviewCubit`
- `EventFeedbackCubit`
- `EventHistoryCubit`
- `CameraEventHistoryCubit`

Neu can theo dau luong du lieu, bat dau tu DI rat nhanh vi phan lon dependency da wire tai day.

## 11. Backend/API nhin nhanh

Tu code hien tai co the thay app dang goi nhom API sau:

### 11.1 Auth/session

- `POST /api/users/login`
- `POST /api/users/logout`
- `GET /api/households/me`
- `POST /api/users/device-token`

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
- Imou OpenAPI cho stream/device integration

## 12. Giao dien (UI/UX) va Design System

Gan day app da co nhieu dieu chinh de nang cao trai nghiem nguoi dung va tinh dong nhat (premium UI):

- **Empty States**: Su dung `AppEmptyState` voi minh hoa va animation thay vi text trong rong.
- **Home Tab**: Weather card duoc nang cap thanh "Safety + Weather Hybrid Card" (file `safety_weather_card.dart`) tap trung vao an toan gia dinh, ket hop gradient va typography hien dai. Bo tri 2 cot phan tren (Safety ben trai, Weather capsule ben phai) va hang metric duoc boc trong widget `Wrap` de tranh tran nut (overflow clipping) tren cac thiet bi man hinh nho.
- **Reports (Bieu do & Su kien)**: 
  - Chon khoang thoi gian qua Bottom Sheet co chon loc thay vi Dropdown menu de toi uu mobile UX.
  - Bieu do xu huong tuan duoc thay the bang bieu do cot dong (`AnimatedWeeklyBarChart`) tich hop truc tiep du lieu su kien tu thuc te, phan tact severity theo cac tong mau thong nhat.
  - Fix loi layout bi co rut khi xay ra loi tai su kien o phan bottom screen bang cach set layout full-width va dung component `AppEmptyState` dong bo.
- **Video Upload**: Bo sung Intro Bottom Sheet (`video_upload_intro_sheet.dart`) de giai thich chi tiet ve tinh nang gui video phan tich AI truoc khi mo thu vien.
- **Account Tab**: Dong nhat header (`AccountPageHeader`) va padding cho cac trang con (Thong bao, Giao dien, Tro giup). Cac tinh nang chua hoan thien se hien thong bao "Coming soon". Them trang `/notification-settings` cho phep nguoi dung tuy chinh thiet lap canh bao.
- **Camera Detail**: 
  - Khung video duoc fix cung ty le 16:9 de tranh loi layout chiem toan man hinh tren iPhone, giup noi dung phia duoi cuon (scrollable) binh thuong, kem loading/error states ro rang.
  - Su kien gan day duoc lam moi card layout: loai bo mock image thumbnail do thuc te backend khong cung cap anh thumbnail, hien thi thong tin thuc te tu backend gom Duration, Confidence, Room, Status va Severity Badge thong nhat. Xoa bo cac so lieu test cung (`999s` / `95%` confidence) do day la mock data.
  - Cho phep tam dung thong bao canh bao cua camera bang cach cham vao nut "Tam dung giam sat" voi lua chon khoang thoi gian giam sat (30m, 2h, 12h, 24h) cung hieu ung countdown chu ky giay tuyet dep.

## 13. Diem can luu y khi tiep tuc sua code

- Branding dang lech giua `WatchNest`, `SilentGuard`, va `SlientGuard`
- Nhieu chuoi tieng Viet trong source dang bi loi encoding
- Router co duplicate route `/faq`
- App shell dang nam trong `HomePage`, khong phai shell route cua `go_router`
- Startup da duoc toi uu de khong block first frame; tranh dua them viec nang truoc `runApp()`
- Auth routing hien release som theo Firebase auth, khong doi backend warm-up xong
- Notification list khong chi den tu FCM; startup con bom them pending household invites
- Mot so UI trong Automation/Account la placeholder hoac chua noi backend that

## 14. File nen doc dau tien theo tung loai task

Neu sua startup/auth:

- `lib/main.dart`
- `lib/core/bootstrap/app_initializer.dart`
- `lib/core/router/auth_notifier.dart`
- `lib/core/router/app_router.dart`
- `lib/features/auth/**`
- `lib/features/session/**`

Neu sua notifications:

- `lib/core/services/fcm_service.dart`
- `lib/core/services/local_notification_service.dart`
- `lib/features/notifications/**`

Neu sua home/camera:

- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/home/presentation/pages/camera_detail_page.dart`
- `lib/features/home/presentation/bloc/home_bloc.dart`
- `lib/features/devices/**`

Neu sua reports:

- `lib/features/reports/presentation/pages/reports_page.dart`
- `lib/features/reports/presentation/cubit/event_history_cubit.dart`
- `lib/features/reports/data/datasources/event_history_remote_datasource.dart`
- `lib/features/reports/presentation/widgets/weekly_trend_chart_card.dart`
- `lib/features/reports/presentation/widgets/animated_weekly_bar_chart.dart`

Neu sua account/legal:

- `lib/features/account/**`
- `faq.md`
- `privacy-policy.md`

## 15. Tom tat 1 cau

App mobile hien la mot Flutter app cho giam sat an toan gia dinh, dung Firebase auth + Railway backend + FCM/local notifications + Imou/media streaming, trong do `HomePage` la app shell 4 tab va startup flow da duoc tach de first frame len nhanh hon.
