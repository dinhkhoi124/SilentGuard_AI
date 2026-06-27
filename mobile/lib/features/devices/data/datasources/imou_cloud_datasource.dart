import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/devices/data/models/imou_models.dart';

abstract interface class ImouCloudDataSource {
  Future<ImouAccessToken> getAccessToken();

  Future<String?> bindDeviceLive({
    required String accessToken,
    required String deviceSn,
    String channelId = '0',
    int streamId = 1,
  });

  Future<ImouLiveStreamInfo> getLiveStreamInfo({
    required String accessToken,
    required String deviceSn,
    String channelId = '0',
  });

  Future<void> unbindLive({
    required String accessToken,
    required String liveToken,
  });

  Future<List<ImouDevice>> getDeviceList({required String accessToken});

  Future<bool> isDeviceOnline({
    required String accessToken,
    required String deviceSn,
  });

  void clearAccessToken();
}

class ImouCloudDataSourceImpl implements ImouCloudDataSource {
  ImouCloudDataSourceImpl({
    required ApiClient apiClient,
    String? appId,
    String? appSecret,
  }) : _apiClient = apiClient,
       _appIdOverride = appId,
       _appSecretOverride = appSecret;

  final ApiClient _apiClient;
  final String? _appIdOverride;
  final String? _appSecretOverride;
  ImouAccessToken? _cachedToken;

  @override
  void clearAccessToken() {
    _cachedToken = null;
  }

  @override
  Future<ImouAccessToken> getAccessToken() async {
    final cached = _cachedToken;
    if (cached != null && cached.expireAt.isAfter(DateTime.now())) {
      return cached;
    }

    final response = await _post('/accessToken');
    final data = _dataObject(response);
    final token = _readString(data, ['accessToken', 'token']);
    final expireTime = _readInt(data, ['expireTime', 'expireAt', 'expires']);
    debugPrint(
      '[ImouCloud] accessToken result=${_resultLog(response)} '
      'expireTime=${expireTime ?? 'missing'} token=${_maskToken(token)}',
    );
    if (token == null || expireTime == null) {
      throw const ImouApiException(
        'INVALID_RESPONSE',
        'Imou Cloud không trả về accessToken hợp lệ.',
      );
    }

    final validSeconds = expireTime > 600 ? expireTime - 600 : expireTime;
    final accessToken = ImouAccessToken(
      token: token,
      expireAt: DateTime.now().add(Duration(seconds: validSeconds - 300)),
    );
    _cachedToken = accessToken;
    return accessToken;
  }

  @override
  Future<String?> bindDeviceLive({
    required String accessToken,
    required String deviceSn,
    String channelId = '0',
    int streamId = 1,
  }) async {
    final response = await _post(
      '/bindDeviceLive',
      token: accessToken,
      params: {
        'deviceId': deviceSn,
        'channelId': channelId,
        'streamId': streamId,
      },
      ignoredErrorCodes: const {'LV1001'},
    );
    final data = _dataObject(response);
    final liveToken = _readString(data, ['liveToken']);
    debugPrint(
      '[ImouCloud] bindDeviceLive deviceId=${_maskDeviceId(deviceSn)} '
      'channelId=$channelId streamId=$streamId result=${_resultLog(response)} '
      'liveStatus=${_readString(data, ['liveStatus', 'status']) ?? 'unknown'} '
      'liveToken=${_maskToken(liveToken)}',
    );
    return liveToken;
  }

  @override
  Future<ImouLiveStreamInfo> getLiveStreamInfo({
    required String accessToken,
    required String deviceSn,
    String channelId = '0',
  }) async {
    final response = await _post(
      '/getLiveStreamInfo',
      token: accessToken,
      params: {'deviceId': deviceSn, 'channelId': channelId},
    );
    final data = _dataObject(response);
    final streams = _parseLiveStreams(data);
    final info = ImouLiveStreamInfo(
      streams: streams,
      status: _readString(data, ['status']) ?? 'unknown',
      bindLiveToken: _readString(data, ['liveToken', 'token']),
    );
    debugPrint(
      '[ImouCloud] getLiveStreamInfo result=${_resultLog(response)} '
      'streams=${streams.length}',
    );
    for (final stream in streams) {
      debugPrint(
        '[ImouCloud] stream streamId=${stream.streamId ?? 'unknown'} '
        'status=${stream.status} protocol=${stream.protocol} '
        'liveToken=${stream.liveToken?.trim().isNotEmpty == true}',
      );
    }
    final selected = info.selectedStream;
    debugPrint(
      '[ImouCloud] selected streamId=${selected?.streamId ?? 'none'} '
      'protocol=${selected?.protocol ?? 'none'} '
      'url=${_maskUrl(selected?.playbackUrl)}',
    );
    return info;
  }

  @override
  Future<void> unbindLive({
    required String accessToken,
    required String liveToken,
  }) async {
    if (liveToken.trim().isEmpty) return;
    final response = await _post(
      '/unbindLive',
      token: accessToken,
      params: {'liveToken': liveToken},
    );
    debugPrint(
      '[ImouCloud] unbindLive liveToken=${_maskToken(liveToken)} '
      'result=${_resultLog(response)}',
    );
  }

  @override
  Future<List<ImouDevice>> getDeviceList({required String accessToken}) async {
    final response = await _post('/deviceList', token: accessToken);
    final data = _dataValue(response);
    final rawItems = switch (data) {
      final List<dynamic> items => items,
      final Map<String, dynamic> map when map['devices'] is List =>
        map['devices'] as List<dynamic>,
      final Map<String, dynamic> map when map['deviceList'] is List =>
        map['deviceList'] as List<dynamic>,
      _ => const <dynamic>[],
    };
    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ImouDevice(
            deviceSn: _readString(item, ['deviceSn', 'deviceId', 'sn']) ?? '',
            deviceName: _readString(item, ['deviceName', 'name']) ?? '',
            status: _readString(item, ['status', 'online']) ?? 'unknown',
            channelId: _readString(item, ['channelId']),
          ),
        )
        .where((device) => device.deviceSn.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<bool> isDeviceOnline({
    required String accessToken,
    required String deviceSn,
  }) async {
    final response = await _post(
      '/deviceOnline',
      token: accessToken,
      params: {'deviceId': deviceSn},
    );
    final data = _dataObject(response);
    final online = _readString(data, ['onLine', 'online', 'isOnline']);
    debugPrint(
      '[ImouCloud] deviceOnline deviceId=${_maskDeviceId(deviceSn)} '
      'result=${_resultLog(response)} onLine=${online ?? 'missing'}',
    );
    return online == '1' || online?.toLowerCase() == 'true';
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    String? token,
    Map<String, dynamic> params = const {},
    Set<String> ignoredErrorCodes = const {},
  }) async {
    try {
      final body = _buildRequestBody(token: token, params: params);
      if (path == '/accessToken') {
        final system = Map<String, dynamic>.from(body['system'] as Map);
        debugPrint(
          '[ImouCloud] accessToken call — time=${system['time']} '
          'nonce=${system['nonce']} sign=${system['sign']}',
        );
      }
      final response = await _apiClient.postObject(path, body);
      _throwIfImouError(response, ignoredErrorCodes: ignoredErrorCodes);
      return response;
    } on ImouApiException {
      rethrow;
    } on ApiException catch (error) {
      throw ImouApiException(
        'HTTP_${error.statusCode ?? 'ERROR'}',
        error.message,
      );
    }
  }

  void _throwIfImouError(
    Map<String, dynamic> response, {
    Set<String> ignoredErrorCodes = const {},
  }) {
    final result = response['result'];
    if (result is! Map) return;

    final map = Map<String, dynamic>.from(result);
    final code = map['code']?.toString() ?? '';
    if (code.isEmpty || code == '0' || code == '200') return;
    if (ignoredErrorCodes.contains(code)) return;

    final message = map['msg']?.toString().trim();
    debugPrint(
      '[ImouCloud] API error code=$code msg=${message?.isNotEmpty == true ? message : 'missing'}',
    );
    throw ImouApiException(
      code,
      message?.isNotEmpty == true ? message! : 'Imou Cloud trả về lỗi $code.',
    );
  }

  Map<String, dynamic> _dataObject(Map<String, dynamic> response) {
    final data = _dataValue(response);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  List<ImouLiveStream> _parseLiveStreams(Map<String, dynamic> data) {
    final streams = data['streams'];
    if (streams is! List) {
      final rootHls = _readString(data, ['hls', 'hlsUrl', 'url']);
      final rootFlv = _readString(data, ['flv', 'flvUrl', 'httpFlv']);
      if (rootHls == null && rootFlv == null) return const [];
      return [
        ImouLiveStream(
          streamId: _readInt(data, ['streamId']),
          status: _readString(data, ['status']) ?? 'unknown',
          hls: rootHls,
          flv: rootFlv,
          liveToken: _readString(data, ['liveToken', 'token']),
        ),
      ];
    }

    return streams
        .whereType<Map>()
        .map((stream) => Map<String, dynamic>.from(stream))
        .map(
          (stream) => ImouLiveStream(
            streamId: _readInt(stream, ['streamId']),
            status: _readString(stream, ['status']) ?? 'unknown',
            hls: _readString(stream, ['hls', 'hlsUrl', 'url']),
            flv: _readString(stream, ['flv', 'flvUrl', 'httpFlv']),
            liveToken: _readString(stream, ['liveToken', 'token']),
          ),
        )
        .toList(growable: false);
  }

  Object? _dataValue(Map<String, dynamic> response) {
    final topLevelData = response['data'];
    if (topLevelData != null) return topLevelData;

    final result = response['result'];
    if (result is Map<String, dynamic>) return result['data'];
    if (result is Map) return result['data'];

    return null;
  }

  Map<String, dynamic> _buildRequestBody({
    String? token,
    Map<String, dynamic> params = const {},
  }) {
    final appId = (_appIdOverride ?? AppConfig.imouAppId).trim();
    final appSecret = (_appSecretOverride ?? AppConfig.imouAppSecret).trim();
    if (appId.isEmpty) {
      throw const ImouApiException(
        'CONFIGURATION',
        'Thiếu IMOU_APP_ID. Vui lòng cấu hình trước khi lấy luồng Imou.',
      );
    }
    if (appSecret.isEmpty) {
      throw const ImouApiException(
        'CONFIGURATION',
        'Thiếu IMOU_APP_SECRET. Vui lòng cấu hình trước khi lấy luồng Imou.',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = base64Url
        .encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
    final sign = _computeSign(
      timestamp: timestamp,
      nonce: nonce,
      appSecret: appSecret,
    );
    final requestParams = <String, dynamic>{...params};
    if (token != null) requestParams['token'] = token;

    return {
      'system': {
        'ver': '1.0',
        'sign': sign,
        'appId': appId,
        'time': timestamp,
        'nonce': nonce,
      },
      'params': requestParams,
      'id': Random().nextInt(10000).toString(),
    };
  }

  String _computeSign({
    required int timestamp,
    required String nonce,
    required String appSecret,
  }) {
    final input = 'time:$timestamp,nonce:$nonce,appSecret:$appSecret';
    return md5.convert(utf8.encode(input)).toString();
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String _resultLog(Map<String, dynamic> response) {
    final result = response['result'];
    if (result is! Map) return 'missing_result';
    final code = result['code']?.toString() ?? 'missing_code';
    final msg = result['msg']?.toString() ?? result['message']?.toString();
    return '$code/${msg ?? 'missing_msg'}';
  }

  String _maskToken(String? token) {
    final value = token?.trim() ?? '';
    if (value.isEmpty) return 'missing';
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
  }

  String _maskDeviceId(String deviceId) {
    final value = deviceId.trim();
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }

  String _maskUrl(String? url) {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || uri.host.isEmpty) return 'missing';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }
}
