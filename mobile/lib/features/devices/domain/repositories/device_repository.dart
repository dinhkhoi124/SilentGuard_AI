import 'package:dartz/dartz.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';

abstract interface class DeviceRepository {
  Future<Either<String, bool>> requestCameraPermission();
  Future<Either<String, PairedDevice>> savePairedDevice({
    required ResolvedDevice resolvedDevice,
  });
  Future<Either<String, List<PairedDevice>>> getPairedDevices();
  Future<Either<String, void>> deletePairedDevice(String deviceId);
}
