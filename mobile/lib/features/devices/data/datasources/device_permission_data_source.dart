import 'package:permission_handler/permission_handler.dart';

abstract interface class DevicePermissionDataSource {
  Future<bool> requestCamera();
  Future<bool> requestPhotoLibrary();
  Future<void> openSettings();
}

class DevicePermissionDataSourceImpl implements DevicePermissionDataSource {
  const DevicePermissionDataSourceImpl();

  @override
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
  }

  @override
  Future<bool> requestPhotoLibrary() async {
    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;

    final storage = await Permission.storage.request();
    return storage.isGranted || storage.isLimited;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}
