import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/device.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

class GetDevices {
  const GetDevices(this.repository);

  final HomeRepository repository;

  Future<Either<String, List<Device>>> call() => repository.getDevices();
}
