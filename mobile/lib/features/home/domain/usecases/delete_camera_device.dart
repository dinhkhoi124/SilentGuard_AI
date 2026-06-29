import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

class DeleteCameraDevice {
  const DeleteCameraDevice(this.repository);

  final HomeRepository repository;

  Future<Either<String, void>> call(String deviceId) {
    return repository.deleteCameraDevice(deviceId);
  }
}
