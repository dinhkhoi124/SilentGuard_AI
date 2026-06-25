// lib/injection_container.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/auth_interceptor.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/services/phone_dialer_service.dart';
import 'package:mobile/features/household_invite/data/datasources/household_invite_remote_data_source.dart';
import 'package:mobile/features/household_invite/presentation/cubit/invite_management_cubit.dart';
import 'package:mobile/features/household_invite/presentation/cubit/pending_invites_cubit.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:mobile/core/services/onboarding_service.dart';
import 'package:mobile/core/theme/theme_controller.dart';
import 'package:mobile/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/automation/data/datasources/emergency_contacts_local_data_source.dart';
import 'package:mobile/features/automation/data/repositories/emergency_contacts_repository_impl.dart';
import 'package:mobile/features/automation/domain/repositories/emergency_contacts_repository.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_cubit.dart';
import 'package:mobile/features/devices/data/datasources/device_permission_data_source.dart';
import 'package:mobile/features/devices/data/datasources/device_remote_data_source.dart';
import 'package:mobile/features/devices/data/datasources/gallery_image_data_source.dart';
import 'package:mobile/features/devices/data/datasources/imou_cloud_datasource.dart';
import 'package:mobile/features/devices/data/datasources/qr_code_data_source.dart';
import 'package:mobile/features/devices/data/repositories/device_repository_impl.dart';
import 'package:mobile/features/devices/data/repositories/imou_stream_repository_impl.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:mobile/features/devices/domain/repositories/imou_stream_repository.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_bloc.dart';
import 'package:mobile/features/home/data/repositories/home_repository_impl.dart';
import 'package:mobile/features/home/data/datasources/alert_review_remote_data_source.dart';
import 'package:mobile/features/home/data/datasources/weather_remote_data_source.dart';
import 'package:mobile/features/home/data/repositories/alert_review_repository_impl.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';
import 'package:mobile/features/home/domain/repositories/alert_review_repository.dart';
import 'package:mobile/features/home/domain/usecases/delete_camera_device.dart';
import 'package:mobile/features/home/domain/usecases/get_camera_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/domain/usecases/review_alert.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/cubit/alert_review_cubit.dart';
import 'package:mobile/features/home/presentation/cubit/camera_event_history_cubit.dart';
import 'package:mobile/features/home/data/datasources/event_feedback_remote_data_source.dart';
import 'package:mobile/features/home/data/repositories/event_feedback_repository_impl.dart';
import 'package:mobile/features/home/domain/repositories/event_feedback_repository.dart';
import 'package:mobile/features/home/domain/usecases/submit_event_feedback.dart';
import 'package:mobile/features/home/presentation/cubit/event_feedback_cubit.dart';
import 'package:mobile/features/home/presentation/cubit/suppress_cubit.dart';
import 'package:mobile/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/features/session/data/datasources/session_remote_datasource.dart';
import 'package:mobile/features/session/data/repositories/session_repository_impl.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';
import 'package:mobile/features/video_upload/data/datasources/video_upload_remote_datasource.dart';
import 'package:mobile/features/video_upload/data/repositories/video_upload_repository_impl.dart';
import 'package:mobile/features/video_upload/domain/repositories/video_upload_repository.dart';
import 'package:mobile/features/video_upload/domain/usecases/upload_video_usecase.dart';
import 'package:mobile/features/reports/data/datasources/event_history_remote_datasource.dart';
import 'package:mobile/features/reports/data/repositories/event_history_repository_impl.dart';
import 'package:mobile/features/reports/domain/repositories/event_history_repository.dart';
import 'package:mobile/features/reports/domain/usecases/get_event_history.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_cubit.dart';
import 'package:mobile/features/video_upload/presentation/bloc/video_upload_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> init() async {
  if (sl.isRegistered<HomeBloc>()) return;

  sl
    ..registerLazySingleton(() => FirebaseAuth.instance)
    ..registerLazySingleton(() => FirebaseMessaging.instance)
    ..registerLazySingleton<http.Client>(
      () => FirebaseAuthHttpClient(firebaseAuth: sl()),
    )
    ..registerLazySingleton(() => ApiClient(client: sl()))
    ..registerLazySingleton(SharedPreferencesAsync.new)
    ..registerLazySingleton(
      () => MonitoringSuppressService(sharedPreferences: sl()),
    )
    ..registerLazySingleton(() => OnboardingService(sl()))
    ..registerLazySingleton(() => PhoneDialerService())
    ..registerLazySingleton<HouseholdInviteRemoteDataSource>(
      () => HouseholdInviteRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton(() => ThemeController(sl()))
    ..registerLazySingleton(() => GoogleSignIn.instance)
    ..registerLazySingleton<FirebaseAuthDataSource>(
      () => FirebaseAuthDataSourceImpl(firebaseAuth: sl(), googleSignIn: sl()),
    )
    ..registerLazySingleton<SessionRemoteDataSource>(
      () => SessionRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<SessionRepository>(
      () => SessionRepositoryImpl(sl()),
    )
    ..registerLazySingleton<VideoUploadRemoteDatasource>(
      () => VideoUploadRemoteDatasourceImpl(firebaseAuth: sl()),
    )
    ..registerLazySingleton<VideoUploadRepository>(
      () => VideoUploadRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => UploadVideoUseCase(sl()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(dataSource: sl(), sessionRepository: sl()),
    )
    ..registerLazySingleton(() => AuthNotifier(sl(), sl(), sl(), sl()))
    ..registerLazySingleton(LocalNotificationService.new)
    ..registerLazySingleton(
      () => FcmService(
        apiClient: sl(),
        firebaseAuth: sl(),
        localNotificationService: sl(),
        monitoringSuppressService: sl(),
        messaging: sl(),
      ),
    )
    ..registerLazySingleton(() => NotificationLocalDataSource(sl()))
    ..registerLazySingleton(() => NotificationsCubit(sl()))
    ..registerFactory(
      () => AuthBloc(
        authRepository: sl(),
        sessionRepository: sl(),
        fcmService: sl(),
        monitoringSuppressService: sl(),
      ),
    )
    ..registerFactory(
      () => HomeBloc(
        getWeather: sl(),
        getCameraDevices: sl(),
        deleteCameraDevice: sl(),
        imouStreamRepository: sl(),
        sessionRepository:
            sl(), // FIX: HomeBloc reads cached startup session instead of refetching blindly.
      ),
    )
    ..registerFactory(
      () => VideoUploadBloc(uploadVideoUseCase: sl(), sessionRepository: sl()),
    )
    ..registerFactory(() => SuppressCubit(sl()))
    ..registerFactory(
      () =>
          DevicePairingBloc(deviceRepository: sl(), imouStreamRepository: sl()),
    )
    ..registerLazySingleton<DevicePermissionDataSource>(
      DevicePermissionDataSourceImpl.new,
    )
    ..registerLazySingleton<GalleryImageDataSource>(
      () => GalleryImageDataSourceImpl(),
    )
    ..registerLazySingleton<QrCodeDataSource>(MobileScannerQrCodeDataSource.new)
    ..registerLazySingleton<ImouCloudDataSource>(
      () => ImouCloudDataSourceImpl(),
    )
    ..registerLazySingleton<ImouStreamRepository>(
      () => ImouStreamRepositoryImpl(sl()),
    )
    ..registerLazySingleton<EmergencyContactsLocalDataSource>(
      () => EmergencyContactsLocalDataSourceImpl(sl()),
    )
    ..registerLazySingleton<EmergencyContactsRepository>(
      () => EmergencyContactsRepositoryImpl(sl()),
    )
    ..registerFactory(() => EmergencyContactsCubit(sl()))
    ..registerFactory(() => InviteManagementCubit(sl()))
    ..registerFactory(() => PendingInvitesCubit(sl()))
    ..registerLazySingleton<DeviceRemoteDataSource>(
      () =>
          DeviceRemoteDataSourceImpl(apiClient: sl(), sessionRepository: sl()),
    )
    ..registerLazySingleton<DeviceRepository>(
      () => DeviceRepositoryImpl(
        remoteDataSource: sl(),
        qrCodeDataSource: sl(),
        galleryImageDataSource: sl(),
        permissionDataSource: sl(),
      ),
    )
    ..registerLazySingleton(() => GetDevices(sl()))
    ..registerLazySingleton(() => GetCameraDevices(sl()))
    ..registerLazySingleton(() => DeleteCameraDevice(sl()))
    ..registerLazySingleton(() => GetWeather(sl()))
    ..registerLazySingleton<WeatherRemoteDataSource>(
      OpenMeteoWeatherRemoteDataSource.new,
    )
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(
        deviceRepository: sl(),
        weatherRemoteDataSource: sl(),
      ),
    );
  sl
    ..registerLazySingleton<AlertReviewRemoteDataSource>(
      () => AlertReviewRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AlertReviewRepository>(
      () => AlertReviewRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => ReviewAlert(sl()))
    ..registerFactory(() => AlertReviewCubit(sl()))
    ..registerLazySingleton<EventFeedbackRemoteDataSource>(
      () => EventFeedbackRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<EventFeedbackRepository>(
      () => EventFeedbackRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => SubmitEventFeedback(sl()))
    ..registerFactoryParam<EventFeedbackCubit, String, dynamic>(
      (eventId, _) => EventFeedbackCubit(sl(), eventId: eventId),
    )
    ..registerLazySingleton<EventHistoryRemoteDataSource>(
      () => EventHistoryRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<EventHistoryRepository>(
      () => EventHistoryRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetEventHistory(sl()))
    ..registerFactory(
      () => EventHistoryCubit(getEventHistory: sl(), sessionRepository: sl()),
    )
    ..registerFactory(
      () => CameraEventHistoryCubit(
        getEventHistory: sl(),
        sessionRepository: sl(),
      ),
    );
}
