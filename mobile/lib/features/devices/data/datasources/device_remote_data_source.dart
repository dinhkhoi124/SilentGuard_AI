import 'dart:convert';
import 'dart:developer' as developer;

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/devices/data/models/device_models.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

abstract interface class DeviceRemoteDataSource {
  Future<ResolvedDevice> resolveDeviceQr(String qrRaw);
  Future<List<PairedDevice>> getPairedDevices();
  Future<PairedDevice> savePairedDevice({
    required ResolvedDevice resolvedDevice,
    required String ipAddress,
    required String rtspUrl,
  });
  Future<void> deletePairedDevice(String deviceId);
}

class DeviceRemoteDataSourceImpl implements DeviceRemoteDataSource {
  DeviceRemoteDataSourceImpl({
    required ApiClient apiClient,
    required SessionRepository sessionRepository,
  }) : _apiClient = apiClient,
       _sessionRepository = sessionRepository;

  final ApiClient _apiClient;
  final SessionRepository _sessionRepository;

  @override
  Future<ResolvedDevice> resolveDeviceQr(String qrRaw) async {
    final trimmedQr = qrRaw.trim();
    if (trimmedQr.isEmpty) {
      throw const ApiException(
        'Mã QR không hợp lệ.',
        kind: ApiExceptionKind.badRequest,
      );
    }

    try {
      final decoded = jsonDecode(trimmedQr);
      if (decoded is Map<String, dynamic>) {
        return ResolvedDeviceModel.fromJson(decoded).toEntity();
      }
      if (decoded is Map) {
        return ResolvedDeviceModel.fromJson(
          Map<String, dynamic>.from(decoded),
        ).toEntity();
      }
    } on FormatException {
      // Fallback below supports simple QR payloads containing only a serial.
    }

    final serialNumber = _extractSerialNumberFromQrPayload(trimmedQr);
    if (serialNumber != null) {
      return ResolvedDevice(
        deviceId: serialNumber,
        displayName: 'Camera $serialNumber',
        serialNumber: serialNumber,
      );
    }

    return ResolvedDevice(
      deviceId: trimmedQr,
      displayName: 'Camera $trimmedQr',
      serialNumber: trimmedQr,
    );
  }

  @override
  Future<List<PairedDevice>> getPairedDevices() async {
    final householdId = Uri.encodeQueryComponent(_currentHouseholdId());
    final response = await _apiClient.getList(
      '/api/cameras?household_id=$householdId',
    );
    return response
        .whereType<Map>()
        .map(
          (item) => PairedDeviceModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .map((model) => model.toEntity())
        .toList(growable: false);
  }

  @override
  Future<PairedDevice> savePairedDevice({
    required ResolvedDevice resolvedDevice,
    required String ipAddress,
    required String rtspUrl,
  }) async {
    final householdId = _currentHouseholdId();
    final response = await _apiClient.postObject('/api/cameras', {
      'household_id': householdId,
      ...PairedDeviceModel.toPairingJson(resolvedDevice: resolvedDevice),
    });
    return PairedDeviceModel.fromJson({
      ..._payload(response),
      'household_id': householdId,
      'ip_address': ipAddress,
      'rtsp_url': rtspUrl,
      'status': 'unknown',
      'serial_number': resolvedDevice.serialNumber.trim(),
    }).toEntity();
  }

  @override
  Future<void> deletePairedDevice(String deviceId) async {
    final status = await _apiClient.delete('/api/cameras/$deviceId');
    developer.log(
      'DELETE /api/cameras status=$status.',
      name: 'CameraRemoteDataSource',
    );
  }

  String _currentHouseholdId() {
    final householdId = _sessionRepository.currentHouseholdId?.trim() ?? '';
    if (householdId.isNotEmpty) return householdId;

    throw const ApiException(
      'Phiên tài khoản chưa được thiết lập. Vui lòng đăng nhập lại.',
      kind: ApiExceptionKind.unauthorized,
    );
  }

  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    for (final key in const ['device', 'data', 'result']) {
      final value = response[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return response;
  }

  String? _extractSerialNumberFromQrPayload(String payload) {
    final match = RegExp(
      r'''(?:^|[{\s,])SN\s*[:=]\s*["']?([^,"'}\s]+)''',
      caseSensitive: false,
    ).firstMatch(payload);
    final serialNumber = match?.group(1)?.trim();
    if (serialNumber == null || serialNumber.isEmpty) return null;
    return serialNumber;
  }
}
