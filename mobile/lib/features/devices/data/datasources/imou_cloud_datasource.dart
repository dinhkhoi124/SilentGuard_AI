import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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
  static const bindDeviceLiveMethod = 'bindDeviceLive';
  static const getLiveStreamInfoMethod = 'getLiveStreamInfo';
  static const unsupportedStreamFormatCode = 'unsupported_stream_format';

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

    String? liveToken;
    String? streamId;
    try {
      final bindResponse = await _request(bindDeviceLiveMethod, params);
      liveToken = _readString(bindResponse, const ['liveToken']);
      streamId = _readString(bindResponse, const ['streamId']);
      debugPrint(
        '[Imou] bindDeviceLive session: '
        'liveToken=${liveToken == null ? 'missing' : 'present'}, '
        'streamId=${streamId == null ? 'missing' : 'present'}',
      );
    } on ImouCloudException catch (error) {
      if (_isAuthError(error)) _cachedToken = null;
      // bindDeviceLive is best-effort: ignore all errors and attempt
      // getLiveStreamInfo regardless. Imou may already have an active
      // session (LV1001) or the device may not require explicit binding.
    }

    final infoParams = <String, dynamic>{
      'token': token,
      'deviceId': deviceId,
      'channelId': channel,
      'liveToken': ?liveToken,
      'streamId': ?streamId,
    };

    Map<String, dynamic>? lastData;
    for (var attempt = 1; attempt <= 3; attempt++) {
      Map<String, dynamic> data;
      try {
        data = await _request(getLiveStreamInfoMethod, infoParams);
      } on ImouCloudException catch (error) {
        if (_isAuthError(error)) _cachedToken = null;
        rethrow;
      }

      _logSafeLiveStreamInfo(data);
      lastData = data;

      final selected = _selectPlayableStreamUrl(data, requireReady: true);
      if (selected != null) return selected;

      if (attempt < 3) {
        debugPrint('[Imou] stream not ready, retrying ($attempt/3) in 1s...');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    if (lastData != null) {
      final selected = _selectPlayableStreamUrl(lastData);
      if (selected != null) return selected;
    }

    throw const ImouCloudException(
      'Imou Cloud did not return a playable HLS stream.',
      code: 'device_no_response',
    );
  }

  void _logSafeLiveStreamInfo(Map<String, dynamic> data) {
    debugPrint('[Imou] live status: ${data['status']}');
    debugPrint('[Imou] live job: ${data['job']}');
    debugPrint('[Imou] liveType: ${data['liveType']}');
    debugPrint(
      '[Imou] streamId: ${data['streamId'] == null ? 'missing' : 'present'}',
    );
    final hasHls = data.keys.any((k) => k.toLowerCase().contains('hls'));
    debugPrint('[Imou] hls exists in root: $hasHls');

    final streams = data['streams'];
    if (streams is List) {
      debugPrint('[Imou] streams length: ${streams.length}');
      for (var i = 0; i < streams.length; i++) {
        final stream = streams[i];
        if (stream is Map) {
          final sType = stream['type'] ?? stream['format'];
          final sStatus = stream['status'];
          debugPrint(
            '[Imou] streams[$i] streamId: '
            '${stream['streamId'] == null ? 'missing' : 'present'}, '
            'type: $sType, status: $sStatus',
          );
        }
      }
    } else {
      debugPrint('[Imou] streams length: 0');
    }
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
    if (_isLiveMethod(method)) {
      debugPrint('[Imou] live endpoint called: $method');
    }
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

  String? _selectPlayableStreamUrl(
    Map<String, dynamic> data, {
    bool requireReady = false,
  }) {
    final streamMaps = <Map<String, dynamic>>[data];
    final streams = data['streams'];
    if (streams is List) {
      for (final stream in streams) {
        if (stream is Map) {
          streamMaps.add(Map<String, dynamic>.from(stream));
        }
      }
    }

    final availableKeys =
        streamMaps.expand((stream) => stream.keys).toSet().toList()..sort();
    debugPrint('[Imou] available response keys: $availableKeys');

    final candidates = <_StreamCandidate>[];
    final rootStatus = data['status']?.toString();
    for (var index = 0; index < streamMaps.length; index++) {
      final stream = streamMaps[index];
      final status = stream['status']?.toString() ?? rootStatus;
      _addUrlCandidates(candidates, stream, index, status, const [
        'hls',
        'httpsHls',
        'hlsUrl',
        'm3u8',
        'url',
      ]);
      _addUrlCandidates(candidates, stream, index, status, const [
        'rtmp',
        'rtmps',
        'rtmpHD',
        'rtmpHd',
        'rtmp_hd',
      ]);
    }

    for (final candidate in candidates) {
      _logStreamCandidate(candidate);
    }

    final playable =
        candidates
            .where(
              (candidate) =>
                  _isHlsUrl(candidate.url) &&
                  (!requireReady || _isReadyStatus(candidate.status)),
            )
            .toList()
          ..sort(_compareCandidates);
    if (playable.isNotEmpty) {
      final selected = playable.first;
      _logSelectedStream(
        selected.uri.scheme == 'https' ? 'httpsHls' : 'hls',
        selected.url,
      );
      return selected.url;
    }

    if (requireReady) return null;

    final unsupportedRtmp = candidates.where(
      (candidate) => _isRtmpUrl(candidate.url),
    );
    if (unsupportedRtmp.isNotEmpty) {
      _logSelectedStream('unsupportedRtmp', unsupportedRtmp.first.url);
      throw const ImouCloudException(
        'Imou Cloud returned only an unsupported RTMP stream.',
        code: unsupportedStreamFormatCode,
      );
    }

    debugPrint('[Imou] selected stream format: unavailable');
    return null;
  }

  void _addUrlCandidates(
    List<_StreamCandidate> target,
    Map<String, dynamic> stream,
    int sourceIndex,
    String? status,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = stream[key]?.toString().trim() ?? '';
      if (value.isEmpty || target.any((candidate) => candidate.url == value)) {
        continue;
      }
      target.add(
        _StreamCandidate(
          url: value,
          key: key,
          status: status,
          sourceIndex: sourceIndex,
        ),
      );
    }
  }

  bool _isHlsUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (uri.port == 8890) return false;
    return (scheme == 'http' || scheme == 'https') &&
        uri.path.toLowerCase().endsWith('.m3u8');
  }

  bool _isRtmpUrl(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    return scheme == 'rtmp' || scheme == 'rtmps';
  }

  void _logSelectedStream(String format, String url) {
    debugPrint('[Imou] selected stream format: $format');
    debugPrint('[Imou] selected stream URL: ${_redactedUrl(url)}');
  }

  void _logStreamCandidate(_StreamCandidate candidate) {
    final valid = _isHlsUrl(candidate.url);
    debugPrint(
      '[Imou] candidate source=${candidate.sourceIndex}, key=${candidate.key}, '
      'status=${candidate.status ?? 'missing'}, validHls=$valid, '
      'url=${_redactedUrl(candidate.url)}',
    );
  }

  int _compareCandidates(_StreamCandidate left, _StreamCandidate right) {
    final statusComparison =
        (_isReadyStatus(right.status) ? 1 : 0) -
        (_isReadyStatus(left.status) ? 1 : 0);
    if (statusComparison != 0) return statusComparison;
    final httpsComparison =
        (right.uri.scheme == 'https' ? 1 : 0) -
        (left.uri.scheme == 'https' ? 1 : 0);
    if (httpsComparison != 0) return httpsComparison;
    return left.sourceIndex.compareTo(right.sourceIndex);
  }

  bool _isReadyStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'ready' ||
        normalized == 'normal' ||
        normalized == 'active' ||
        normalized == 'success' ||
        normalized == '1';
  }

  String _redactedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return 'invalid';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  bool _isLiveMethod(String method) {
    return method == bindDeviceLiveMethod ||
        method == getLiveStreamInfoMethod ||
        method == 'createDeviceRtmpLive' ||
        method == 'queryDeviceRtmpLive';
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

class _StreamCandidate {
  const _StreamCandidate({
    required this.url,
    required this.key,
    required this.status,
    required this.sourceIndex,
  });

  final String url;
  final String key;
  final String? status;
  final int sourceIndex;

  Uri get uri => Uri.parse(url);
}
