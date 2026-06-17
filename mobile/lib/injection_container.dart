// lib/injection_container.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/devices/data/datasources/device_permission_data_source.dart';
import 'package:mobile/features/devices/data/datasources/device_remote_data_source.dart';
import 'package:mobile/features/devices/data/datasources/gallery_image_data_source.dart';
import 'package:mobile/features/devices/data/datasources/onvif_discovery_data_source.dart';
import 'package:mobile/features/devices/data/datasources/onvif_media_data_source.dart';
import 'package:mobile/features/devices/data/datasources/qr_code_data_source.dart';
import 'package:mobile/features/devices/data/repositories/device_repository_impl.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_bloc.dart';
import 'package:mobile/features/home/data/repositories/home_repository_impl.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';
import 'package:mobile/features/home/domain/usecases/delete_camera_device.dart';
import 'package:mobile/features/home/domain/usecases/get_camera_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  if (sl.isRegistered<HomeBloc>()) return;

  sl
    ..registerLazySingleton(ApiClient.new)
    ..registerLazySingleton(() => FirebaseAuth.instance)
    ..registerLazySingleton(() => GoogleSignIn.instance)
    ..registerLazySingleton<FirebaseAuthDataSource>(
      () => FirebaseAuthDataSourceImpl(firebaseAuth: sl(), googleSignIn: sl()),
    )
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    ..registerLazySingleton(() => AuthNotifier(sl()))
    ..registerLazySingleton(LocalNotificationService.new)
    ..registerFactory(() => AuthBloc(authRepository: sl()))
    ..registerFactory(
      () => HomeBloc(
        getWeather: sl(),
        getCameraDevices: sl(),
        deleteCameraDevice: sl(),
      ),
    )
    ..registerFactory(() => DevicePairingBloc(deviceRepository: sl()))
    ..registerLazySingleton<DevicePermissionDataSource>(
      DevicePermissionDataSourceImpl.new,
    )
    ..registerLazySingleton<GalleryImageDataSource>(
      () => GalleryImageDataSourceImpl(),
    )
    ..registerLazySingleton<QrCodeDataSource>(MobileScannerQrCodeDataSource.new)
    ..registerLazySingleton<OnvifDiscoveryDataSource>(
      WsDiscoveryOnvifDataSource.new,
    )
    ..registerLazySingleton<OnvifMediaDataSource>(
      () => OnvifMediaDataSourceImpl(),
    )
    ..registerLazySingleton<DeviceRemoteDataSource>(
      () => DeviceRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<DeviceRepository>(
      () => DeviceRepositoryImpl(
        remoteDataSource: sl(),
        discoveryDataSource: sl(),
        mediaDataSource: sl(),
        qrCodeDataSource: sl(),
        galleryImageDataSource: sl(),
        permissionDataSource: sl(),
      ),
    )
    ..registerLazySingleton(() => GetDevices(sl()))
    ..registerLazySingleton(() => GetCameraDevices(sl()))
    ..registerLazySingleton(() => DeleteCameraDevice(sl()))
    ..registerLazySingleton(() => GetWeather(sl()))
    ..registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(sl()));
}
