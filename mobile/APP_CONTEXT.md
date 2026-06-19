# Smartify App Context

Tai lieu nay tom tat trang thai hien tai cua app Flutter `mobile/` de dung nhu handover note cho cac lan lam tiep theo.

## 1. App dang lam gi

Smartify la ung dung Flutter cho gia dinh/caregiver dung de:

- Dang nhap bang Firebase Auth
- Dong bo phien nguoi dung voi backend FastAPI SilentGuard
- Hien splash startup, onboarding 3 trang, welcome/login, sign up, home, account
- Xem danh sach camera, chi tiet camera va luong video truc tiep
- Quet QR de ghep camera moi qua Imou cloud
- Nhan thong bao FCM va mo man hinh lien quan
- Quan ly tai khoan, logout, va cac luong lien quan den household

Ngon ngu hien thi cho nguoi dung la tieng Viet.

## 2. Stack va kien truc hien tai

- Flutter 3.x
- BLoC cho state management
- GoRouter cho dieu huong
- GetIt cho DI
- Clean Architecture theo feature
- `shared_preferences` de persist `onboarding_completed`

Nhung diem dang giu vai tro trung tam:

- `AuthNotifier` la source of truth cho router startup/auth state
- `SessionRepository` la cau noi giua Firebase login va backend session
- `OnboardingService` giu flag first-run onboarding
- `HomeBloc` dang giu state cua home va danh sach device hien thi
- `DevicePairingBloc` xu ly luong quet QR va ghep camera
- `FcmService` xu ly dang ky token FCM va notification

## 3. Startup flow hien tai

Cold start hien tai di theo thu tu:

1. App luon vao `/splash`
2. `AuthNotifier` dong thoi:
   - nghe event dau tien tu `authStateChanges()`
   - doc `onboarding_completed`
   - giu splash toi thieu mot nhip ngan de tranh flash
3. Neu Firebase restore duoc user:
   - app goi `SessionRepository.provisionSession()`
   - sau do dang ky FCM token
   - router di den destination sau auth (`/home` hoac route camera tu notification)
4. Neu khong co session:
   - onboarding chua xong -> vao `/onboarding`
   - onboarding da xong -> vao `/welcome`

Muc tieu cua flow nay la tranh bug cu: welcome/login bi flash trong luc Firebase dang restore session roi tu redirect vao home.

## 4. Luong auth hien tai

Luot auth dang chia thanh 2 nhanh:

- Email/password:
  - form login nam truc tiep trong `WelcomePage`
  - UI dispatch `AuthSignInRequested`
  - `AuthBloc` goi `AuthRepository.signInWithEmail()`
  - thanh cong -> `SessionRepository.provisionSession()` -> `AuthSuccess`

- Google:
  - chi con duy nhat Google social sign-in
  - UI dispatch `AuthGoogleSignInRequested`
  - thanh cong -> backend provisioning -> dang ky FCM token

Khong con route/man hinh `signin_page.dart` rieng nua.
Apple, Facebook, X/Twitter da bi bo khoi UI va hien tai khong co auth logic rieng trong data/domain layer.

## 5. Man hinh auth/onboarding hien tai

- `SplashPage`
  - nen primary blue
  - badge Smartify mau trang + wordmark
  - loader trong luc startup auth/onboarding check chay

- `OnboardingPage`
  - 3 trang PageView
  - mockup screenshot tĩnh de thay bang asset that sau nay
  - Skip va Continue o trang 1-2
  - `Let's Get Started` o trang 3
  - finish/skip se set `onboarding_completed=true` roi vao `/welcome`

- `WelcomePage`
  - chua truc tiep email field, password field, forgot password, primary login button
  - co Google sign-in ben duoi divider `hoac`
  - van giu entry point sang `SignUpPage`

- `SignUpPage`
  - van tach rieng
  - co email/password sign-up va Google sign-in

## 6. Router va redirect logic

`AppRouter` hien tai co cac route chinh:

- `/splash`
- `/onboarding`
- `/welcome`
- `/signup`
- `/home`
- `/add-device`
- `/camera/:id`

Auth flow redirect da dua tren 3 du lieu tu `AuthNotifier`:

- `isReady`
- `isAuthenticated`
- `onboardingCompleted`

Y nghia:

- chua `isReady` -> o lai splash
- authenticated -> vao post-auth destination
- unauthenticated + onboarding chua xong -> onboarding
- unauthenticated + onboarding xong -> welcome

## 7. Logout hien tai

Logout hien tai di theo thu tu:

1. `AccountPage` dispatch `AuthSignOutRequested`
2. `AuthRepositoryImpl.signOut()` co gang goi backend logout truoc
3. `SessionRepository.clearCachedSession()`
4. Firebase sign-out
5. Router quay ve flow unauthenticated

UI logout tren `AccountPage` da doi:

- khong con spinner inline ngay icon logout
- trong luc logout se hien dialog progress rieng

## 8. Luong camera / device hien tai

Luot ghep camera hien tai:

1. Quet QR live hoac chon QR tu gallery
2. Resolve QR sang `ResolvedDevice`
3. Parse duoc QR dang `{SN:...,SC:...,PID:...}` va lay `SN`
4. Goi Imou cloud de kiem tra/truy stream
5. Lay RTMP URL
6. Dang ky camera vao backend qua `POST /api/cameras`
7. Sau pairing, home duoc cap nhat bang object vua pair de giu stream URL trong session hien tai

Video live hien tai:

- dung `media_kit`
- player da co debug listeners cho `error`, `log`, `playing`, `buffering`
- RTMP duoc pass as-is vao player
- backend camera list hien tai chua ro co persist stream URL hay khong, nen behavior sau reload app van la diem can theo doi

Xoa camera hien tai:

- co goi `DELETE /api/cameras/{camera_id}`
- datasource co log status delete

## 9. Backend integration da co

Theo code hien tai, app dang phu thuoc cac nhom API sau:

- Auth/session
  - `POST /api/users/login`
  - `POST /api/users/logout`
  - `POST /api/users/device-token`
  - `GET /api/households/me`
- Cameras/devices
  - `GET /api/cameras`
  - `POST /api/cameras`
  - `DELETE /api/cameras/{camera_id}`
- Imou cloud
  - access token + device status + stream URL qua datasource Imou

FCM token registration dang duoc goi sau khi backend provisioning thanh cong.

## 10. Nhung thu dang on

- Startup race condition da duoc chan bang splash + first auth event gating
- Onboarding da co persistence va duoc wire vao router
- Welcome da gom thang login form, khong con man hinh login trung gian
- Google sign-in va email/password login van dung chung AuthBloc/SessionRepository
- Logout da co UX ro hon bang dialog progress
- Device pairing da co bloc/repository/datasource ro rang
- `media_kit` da co them logging de debug player tot hon

## 11. Nhung cho con vuong

- Trong worktree hien tai con nhieu thay doi chua commit:
  - splash/onboarding/shared_preferences
  - welcome merge login
  - account logout dialog
- `HomeBloc` van con debug token print `[DEBUG_TOKEN]`
- co the `FcmService` van con debug FCM token print neu chua duoc go bo sau test
- `AppConfig.backendAuthToken` da tung bi nghi la dead code, can tiep tuc giu/bo cho ro rang
- RTMP playback tren Android phu thuoc native media support cua `media_kit`; neu den luc can stream on dinh hon co the phai xem lai protocol/backend contract

## 12. Nhung diem can xac nhan neu lam tiep

- Sign Up co can duoc merge vao Welcome hay van giu rieng
- Backend co nen persist stream URL/serial number day du de camera detail sau relaunch khong bi mat thong tin
- Cac debug log/token print da den luc xoa chua
- Forgot password hien tai chi la UI placeholder, chua co flow that
- Response contract cuoi cung cua camera APIs va auth/session APIs co on dinh chua

## 13. File nen doc khi dung vao cac flow nay

- `lib/core/router/auth_notifier.dart`
- `lib/core/router/app_router.dart`
- `lib/core/services/onboarding_service.dart`
- `lib/features/onboarding/presentation/pages/splash_page.dart`
- `lib/features/onboarding/presentation/pages/onboarding_page.dart`
- `lib/features/auth/presentation/pages/welcome_page.dart`
- `lib/features/auth/presentation/pages/signup_page.dart`
- `lib/features/session/data/datasources/session_remote_datasource.dart`
- `lib/features/session/data/repositories/session_repository_impl.dart`
- `lib/core/services/fcm_service.dart`
- `lib/features/account/presentation/pages/account_page.dart`
- `lib/features/devices/presentation/bloc/device_pairing_bloc.dart`
- `lib/features/devices/data/datasources/imou_cloud_datasource.dart`
- `lib/features/home/presentation/widgets/camera_video_player.dart`

## 14. Tom tat mot cau

Smartify hien la app Flutter dang dung splash-auth gate + persisted onboarding, login bang Firebase (email/password va Google), dong bo session voi SilentGuard backend, dang ky FCM token sau provisioning, va dung Imou cloud + media_kit cho luong pairing/live camera.
