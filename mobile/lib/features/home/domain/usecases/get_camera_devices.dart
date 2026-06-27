import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

class GetCameraDevices {
  const GetCameraDevices(this.repository);

  final HomeRepository repository;

  Future<Either<String, List<CameraDevice>>> call() {
    return repository.getCameraDevices();
  }
}
