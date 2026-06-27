import 'package:dartz/dartz.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:mobile/features/home/data/datasources/weather_remote_data_source.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/entities/device.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({
    required DeviceRepository deviceRepository,
    required WeatherRemoteDataSource weatherRemoteDataSource,
  }) : _deviceRepository = deviceRepository,
       _weatherRemoteDataSource = weatherRemoteDataSource;

  final DeviceRepository _deviceRepository;
  final WeatherRemoteDataSource _weatherRemoteDataSource;

  @override
  Future<Either<String, List<Device>>> getDevices() async {
    return const Right([]);
  }

  @override
  Future<Either<String, List<CameraDevice>>> getCameraDevices() async {
    final result = await _deviceRepository.getPairedDevices();
    return result.map(
      (devices) => devices
          .map((device) => device.toCameraDevice())
          .toList(growable: false),
    );
  }

  @override
  Future<Either<String, void>> deleteCameraDevice(String deviceId) async {
    return _deviceRepository.deletePairedDevice(deviceId);
  }

  @override
  Future<Either<String, WeatherInfo?>> getWeather() async {
    final weather = await _weatherRemoteDataSource.getCurrentWeather();
    return Right(weather);
  }
}
