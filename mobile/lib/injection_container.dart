import 'package:get_it/get_it.dart';
import 'package:mobile/features/home/data/repositories/home_repository_impl.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';
import 'package:mobile/features/home/domain/usecases/get_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  if (sl.isRegistered<HomeBloc>()) return;

  sl
    ..registerFactory(() => HomeBloc(getDevices: sl(), getWeather: sl()))
    ..registerLazySingleton(() => GetDevices(sl()))
    ..registerLazySingleton(() => GetWeather(sl()))
    ..registerLazySingleton<HomeRepository>(HomeRepositoryImpl.new);
}
