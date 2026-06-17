import 'package:dartz/dartz.dart';
import 'package:mobile/features/devices/domain/entities/device_credentials.dart';
import 'package:mobile/features/devices/domain/entities/onvif_discovery_result.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';

abstract interface class DeviceRepository {
  DeviceCredentials? get defaultOnvifCredentials;

  Future<Either<String, bool>> requestCameraPermission();
  Future<Either<String, bool>> requestPhotoLibraryPermission();
  Future<Either<String, void>> openAppSettings();
  Future<Either<String, String?>> pickQrImagePath();
  Future<Either<String, String>> decodeQrImageFile(String path);
  Future<Either<String, ResolvedDevice>> resolveDeviceQr(String qrRaw);
  Future<Either<String, List<OnvifDiscoveryResult>>> discoverOnvifDevices();
  Future<Either<String, OnvifDiscoveryResult>> matchDiscoveredDevice({
    required List<OnvifDiscoveryResult> devices,
    required String serialNumber,
  });
  Future<Either<String, String>> getRtspStreamUri({
    required OnvifDiscoveryResult device,
    DeviceCredentials? credentials,
  });
  Future<Either<String, PairedDevice>> savePairedDevice({
    required ResolvedDevice resolvedDevice,
    required String ipAddress,
    required String rtspUrl,
  });
  Future<Either<String, List<PairedDevice>>> getPairedDevices();
  Future<Either<String, void>> deletePairedDevice(String deviceId);
}
