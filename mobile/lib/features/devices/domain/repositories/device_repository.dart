import 'package:dartz/dartz.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';

abstract interface class DeviceRepository {
  Future<Either<String, bool>> requestCameraPermission();
  Future<Either<String, bool>> requestPhotoLibraryPermission();
  Future<Either<String, void>> openAppSettings();
  Future<Either<String, String?>> pickQrImagePath();
  Future<Either<String, String>> decodeQrImageFile(String path);
  Future<Either<String, ResolvedDevice>> resolveDeviceQr(String qrRaw);
  Future<Either<String, PairedDevice>> savePairedDevice({
    required ResolvedDevice resolvedDevice,
    required String ipAddress,
    required String rtspUrl,
  });
  Future<Either<String, List<PairedDevice>>> getPairedDevices();
  Future<Either<String, void>> deletePairedDevice(String deviceId);
}
