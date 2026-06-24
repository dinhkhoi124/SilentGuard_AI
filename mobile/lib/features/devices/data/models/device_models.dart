import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';

class ResolvedDeviceModel {
  const ResolvedDeviceModel({
    required this.deviceId,
    required this.displayName,
    required this.serialNumber,
    this.model,
    this.productId,
    this.location,
    this.metadata = const {},
  });

  final String deviceId;
  final String displayName;
  final String serialNumber;
  final String? model;
  final String? productId;
  final String? location;
  final Map<String, dynamic> metadata;

  factory ResolvedDeviceModel.fromJson(Map<String, dynamic> json) {
    return ResolvedDeviceModel(
      deviceId: _readString(json, ['device_id', 'id']),
      displayName: _readString(json, ['display_name', 'name']),
      serialNumber: _readString(json, ['serial_number', 'serial', 'sn', 'SN']),
      model: _readNullableString(json, ['model', 'model_name']),
      productId: _readNullableString(json, ['product_id', 'pid', 'PID']),
      location: _readNullableString(json, ['location', 'room']),
      metadata: _readMap(json, ['metadata', 'meta']),
    );
  }

  ResolvedDevice toEntity() {
    return ResolvedDevice(
      deviceId: deviceId,
      displayName: displayName,
      serialNumber: serialNumber,
      model: model,
      productId: productId,
      location: location,
      metadata: metadata,
    );
  }
}

class PairedDeviceModel {
  const PairedDeviceModel({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.rtspUrl,
    required this.location,
    required this.status,
    required this.isArmed,
    required this.accessories,
    required this.accessoryStates,
    this.model,
    this.serialNumber,
    this.productId,
    this.room,
  });

  final String id;
  final String name;
  final String ipAddress;
  final String rtspUrl;
  final String location;
  final String status;
  final bool isArmed;
  final List<String> accessories;
  final List<bool> accessoryStates;
  final String? model;
  final String? serialNumber;
  final String? productId;

  /// Raw backend room key, preserved separately from [location] (display string).
  final String? room;

  factory PairedDeviceModel.fromJson(Map<String, dynamic> json) {
    final backendStatus = _readNullableString(json, ['status']);
    final rawRoom = _readNullableString(json, ['room']);
    return PairedDeviceModel(
      id: _readString(json, ['camera_id', 'device_id', 'id']),
      name: _readString(json, ['display_name', 'name']),
      ipAddress: _readString(json, ['ip_address', 'ip']),
      rtspUrl: _readString(json, ['rtsp_url', 'stream_url']),
      location: _readNullableString(json, ['room', 'location']) ?? 'Camera IP',
      status: _cameraStatusLabel(backendStatus),
      isArmed: _readBool(json, [
        'is_armed',
        'armed',
      ], fallback: _cameraIsActive(backendStatus)),
      accessories: _readStringList(json, ['accessories']),
      accessoryStates: _readBoolList(json, ['accessory_states']),
      model: _readNullableString(json, ['model', 'model_name']),
      serialNumber: _readNullableString(json, [
        'serial_number',
        'serial',
        'sn',
        'SN',
      ]),
      productId: _readNullableString(json, ['product_id', 'pid', 'PID']),
      room: rawRoom,
    );
  }

  PairedDevice toEntity() {
    return PairedDevice(
      id: id,
      name: name,
      ipAddress: ipAddress,
      rtspUrl: rtspUrl,
      location: location,
      status: status,
      isArmed: isArmed,
      accessories: accessories,
      accessoryStates: accessoryStates,
      model: model,
      serialNumber: serialNumber,
      productId: productId,
      room: room,
    );
  }

  static Map<String, dynamic> toPairingJson({
    required ResolvedDevice resolvedDevice,
  }) {
    return {
      'name': resolvedDevice.displayName,
      'fps': 15,
      'serial_number': resolvedDevice.serialNumber.trim(),
    };
  }
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value == null) return '';
  return value.toString();
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  required bool fallback,
}) {
  final value = _readValue(json, keys);
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

List<String> _readStringList(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

List<bool> _readBoolList(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is List) {
    return value
        .map((item) {
          if (item is bool) return item;
          if (item is num) return item != 0;
          return item.toString().toLowerCase() == 'true';
        })
        .toList(growable: false);
  }
  return const [];
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

Object? _readValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

String _cameraStatusLabel(String? status) {
  return switch (status?.trim().toLowerCase()) {
    'online' => 'Trực tuyến',
    'offline' => 'Ngoại tuyến',
    'unknown' => 'Chưa có heartbeat',
    final value? when value.isNotEmpty => value,
    _ => 'Chưa có heartbeat',
  };
}

bool _cameraIsActive(String? status) {
  return switch (status?.trim().toLowerCase()) {
    'offline' => false,
    _ => true,
  };
}
