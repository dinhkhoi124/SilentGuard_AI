import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/devices/domain/entities/imou_device_status.dart';
import 'package:uuid/uuid.dart';

abstract interface class ImouCloudDataSource {
  Future<ImouDeviceStatus> checkDeviceStatus(String serialNumber);

  Future<String> getStreamUrl(String serialNumber, {int channel = 0});
}

class ImouCloudDataSourceImpl implements ImouCloudDataSource {
  ImouCloudDataSourceImpl({http.Client? client})
    : _client = client ?? http.Client();

  static const _uuid = Uuid();
  static const tokenMethod = 'accessToken';
  static const checkBindMethod = 'checkDeviceBindOrNot';
  static const deviceOnlineMethod = 'deviceOnline';
  static const createRtmpMethod = 'createDeviceRtmpLive';
  static const queryRtmpMethod = 'queryDeviceRtmpLive';

  final http.Client _client;

  _ImouToken? _cachedToken;

  @override
  Future<ImouDeviceStatus> checkDeviceStatus(String serialNumber) async {
    final deviceId = serialNumber.trim();
    final token = await _accessToken();
    final bindData = await _request(checkBindMethod, {
      'token': token,
      'deviceId': deviceId,
    });
    final onlineData = await _request(deviceOnlineMethod, {
      'token': token,
      'deviceId': deviceId,
    });

    return ImouDeviceStatus(
      serialNumber: deviceId,
      isBound: _readBool(bindData, const ['isBind', 'isBound', 'bind']),
      isMine: _readBool(bindData, const ['isMine', 'mine', 'owned']),
      isOnline: _readOnlineStatus(onlineData['onLine'] ?? onlineData['online']),
      deviceName: _readString(bindData, const ['deviceName', 'name']),
      channelCount: _readChannelCount(onlineData),
    );
  }

  @override
  Future<String> getStreamUrl(String serialNumber, {int channel = 0}) async {
    final deviceId = serialNumber.trim();
    final token = await _accessToken();
    final params = <String, dynamic>{
      'token': token,
      'deviceId': deviceId,
      'channelId': channel,
    };

    Map<String, dynamic> data;
    try {
      data = await _request(createRtmpMethod, params);
    } on ImouCloudException catch (error) {
      if (_isAuthError(error)) _cachedToken = null;
      if (error.code != 'LV1001') rethrow;
      try {
        data = await _request(queryRtmpMethod, params);
      } on ImouCloudException catch (queryError) {
        if (_isAuthError(queryError)) _cachedToken = null;
        rethrow;
      }
    }

    final url = _selectRtmpUrl(data);
    if (url == null || url.isEmpty) {
      throw const ImouCloudException('Imou Cloud did not return an RTMP URL.');
    }
    return url;
  }

  Future<String> _accessToken() async {
    final cached = _cachedToken;
    if (cached != null && cached.isValid) return cached.value;

    final data = await _request(tokenMethod, const <String, dynamic>{});
    final token = _readString(data, const [
      'accessToken',
      'access_token',
      'token',
    ]);
    if (token == null || token.isEmpty) {
      throw const ImouCloudException('Imou Cloud did not return accessToken.');
    }

    final expiresIn = _readInt(data, const [
      'expireTime',
      'expiresIn',
      'expires_in',
    ]);
    _cachedToken = _ImouToken(
      value: token,
      expiresAt: DateTime.now().add(
        Duration(seconds: expiresIn ?? const Duration(days: 3).inSeconds),
      ),
    );
    return token;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params,
  ) async {
    _ensureConfigured();
    final uri = _uri(method);
    final body = _openApiBody(params);

    final response = await _client
        .post(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(body),
        )
        .timeout(AppConfig.networkTimeout);

    if (response.statusCode != 200) {
      developer.log(
        'Imou method $method returned HTTP ${response.statusCode}.',
        name: 'ImouCloudDataSource',
      );
      throw ImouCloudException(
        'Imou Cloud returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const ImouCloudException('Invalid Imou Cloud response.');
    }
    final payload = Map<String, dynamic>.from(decoded);
    return _dataPayload(payload, method);
  }

  Map<String, dynamic> _openApiBody(Map<String, dynamic> params) {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final nonce = _uuid.v4();
    return {
      'system': {
        'ver': '1.0',
        'appId': AppConfig.imouAppId.trim(),
        'sign': _sign(time: timestamp, nonce: nonce),
        'time': timestamp,
        'nonce': nonce,
      },
      'id': _uuid.v4(),
      'params': params,
    };
  }

  String _sign({required int time, required String nonce}) {
    final raw = 'time:$time,nonce:$nonce,appSecret:${AppConfig.imouAppSecret}';
    return md5.convert(utf8.encode(raw)).toString();
  }

  Uri _uri(String method) => Uri.https(_openApiHost(), '/openapi/$method');

  String _openApiHost() {
    final configured = AppConfig.imouApiBaseUrl.trim();
    final withScheme = configured.startsWith(RegExp(r'https?://'))
        ? configured
        : 'https://$configured';
    final uri = Uri.parse(withScheme);
    return uri.host.isNotEmpty ? uri.host : configured;
  }

  Map<String, dynamic> _dataPayload(
    Map<String, dynamic> payload,
    String method,
  ) {
    final result = payload['result'];
    if (result is! Map) {
      throw const ImouCloudException('Invalid Imou Cloud result payload.');
    }

    final code = result['code']?.toString();
    if (code != '0') {
      developer.log(
        'Imou method $method returned code $code.',
        name: 'ImouCloudDataSource',
      );
      throw ImouCloudException(
        result['msg']?.toString() ??
            result['message']?.toString() ??
            'Imou Cloud method $method returned code $code.',
        code: code,
      );
    }

    final data = result['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  void _ensureConfigured() {
    if (AppConfig.imouAppId.trim().isEmpty) {
      throw const ImouCloudException(
        'Missing IMOU_APP_ID. Configure it with --dart-define.',
      );
    }
    if (AppConfig.imouAppSecret.trim().isEmpty) {
      throw const ImouCloudException(
        'Missing IMOU_APP_SECRET. Configure it with --dart-define.',
      );
    }
  }

  String? _selectRtmpUrl(Map<String, dynamic> data) {
    return _readString(data, const ['rtmp', 'rtmpUrl', 'url']) ??
        _readString(data, const ['rtmpHD', 'rtmpHd', 'rtmp_hd']);
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  bool _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().toLowerCase().trim();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return false;
  }

  bool _readOnlineStatus(Object? value) {
    final text = value?.toString().toLowerCase().trim();
    return text == '1' || text == 'online' || text == 'true';
  }

  int? _readChannelCount(Map<String, dynamic> json) {
    final channels = json['channels'];
    if (channels is List) return channels.length;
    return _readInt(json, const ['channelNum', 'channelCount']);
  }

  int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool _isAuthError(ImouCloudException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    return code.contains('auth') ||
        code.contains('token') ||
        code.contains('sign') ||
        code.contains('0002') ||
        message.contains('token') ||
        message.contains('sign');
  }
}

class ImouCloudException implements Exception {
  const ImouCloudException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

class _ImouToken {
  const _ImouToken({required this.value, required this.expiresAt});

  final String value;
  final DateTime expiresAt;

  bool get isValid {
    return DateTime.now().add(const Duration(minutes: 5)).isBefore(expiresAt);
  }
}
