import 'package:dartz/dartz.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
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
    return const Right(null);
  }
}
