import 'package:dartz/dartz.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:mobile/features/home/data/mock_devices.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/entities/device.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._deviceRepository);

  final DeviceRepository _deviceRepository;

  @override
  Future<Either<String, List<Device>>> getDevices() async {
    return const Right([]);
  }

  @override
  Future<Either<String, List<CameraDevice>>> getCameraDevices() async {
    if (AppConfig.useMockData) {
      return const Right(mockCameraDevices);
    }

    final result = await _deviceRepository.getPairedDevices();
    return result.map(
      (devices) => devices
          .map((device) => device.toCameraDevice())
          .toList(growable: false),
    );
  }

  @override
  Future<Either<String, void>> deleteCameraDevice(String deviceId) async {
    if (AppConfig.useMockData) {
      return const Right(null);
    }
    return _deviceRepository.deletePairedDevice(deviceId);
  }

  @override
  Future<Either<String, WeatherInfo>> getWeather() async {
    return const Right(
      WeatherInfo(
        temperature: 20,
        city: 'New York City, USA',
        condition: 'Today Cloudy',
        aqi: 92,
        humidity: 78.2,
        windSpeed: 2,
      ),
    );
  }
}
