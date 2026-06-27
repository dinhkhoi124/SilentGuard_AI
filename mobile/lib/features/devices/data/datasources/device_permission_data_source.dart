import 'package:permission_handler/permission_handler.dart';

abstract interface class DevicePermissionDataSource {
  Future<bool> requestCamera();
}

class DevicePermissionDataSourceImpl implements DevicePermissionDataSource {
  const DevicePermissionDataSourceImpl();

  @override
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
  }
}
