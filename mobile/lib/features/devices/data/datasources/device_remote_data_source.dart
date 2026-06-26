import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/devices/data/models/device_models.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

abstract interface class DeviceRemoteDataSource {
  Future<List<PairedDevice>> getPairedDevices();

  Future<PairedDevice> savePairedDevice({
    required ResolvedDevice resolvedDevice,
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
  }) async {
    final householdId = _currentHouseholdId();
    try {
      final requestBody = {
        'household_id': householdId,
        ...PairedDeviceModel.toPairingJson(resolvedDevice: resolvedDevice),
      };
      debugPrint('POST /api/cameras householdId: $householdId');
      debugPrint('POST /api/cameras body: ${jsonEncode(requestBody)}');

      final response = await _apiClient.postObject('/api/cameras', requestBody);
      return PairedDeviceModel.fromJson({
        ..._payload(response),
        'household_id': householdId,
        'ip_address': 'imou-cloud',
        'rtsp_url': '',
        'status': 'unknown',
        'serial_number': resolvedDevice.serialNumber,
      }).toEntity();
    } on ApiException catch (e) {
      debugPrint('POST /api/cameras response ${e.statusCode}: ${e.message}');
      if (e.statusCode == 409 || e.message.contains('DUPLICATE_SERIAL')) {
        throw const ApiException(
          'Camera này đã được đăng ký. Kiểm tra lại thiết bị.',
          kind: ApiExceptionKind.badRequest,
        );
      }
      rethrow;
    }
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
}
