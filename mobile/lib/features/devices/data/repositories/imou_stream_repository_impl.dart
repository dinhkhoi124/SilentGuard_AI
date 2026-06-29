import 'package:flutter/foundation.dart';
import 'package:mobile/features/devices/data/datasources/imou_cloud_datasource.dart';
import 'package:mobile/features/devices/data/models/imou_models.dart';
import 'package:mobile/features/devices/domain/repositories/imou_stream_repository.dart';

class ImouStreamRepositoryImpl implements ImouStreamRepository {
  ImouStreamRepositoryImpl(this._dataSource);

  static const _defaultChannelId = '0';
  static const _defaultStreamId = 1;

  final ImouCloudDataSource _dataSource;
  final Map<String, _StartLiveRequest> _pendingStarts = {};
  final Map<String, _ImouStreamSession> _activeSessions = {};
  var _requestSequence = 0;

  @visibleForTesting
  bool hasActiveSession(String deviceSn) {
    return _activeSessions.containsKey(deviceSn.trim());
  }

  @visibleForTesting
  String? activeSessionLiveToken(String deviceSn) {
    return _activeSessions[deviceSn.trim()]?.liveToken;
  }

  @visibleForTesting
  String? activeSessionStreamUrl(String deviceSn) {
    return _activeSessions[deviceSn.trim()]?.streamUrl;
  }

  @override
  Future<String> getStreamUrl(String deviceSn) {
    return _getStreamUrl(deviceSn, retriedAfterTokenRefresh: false);
  }

  Future<String> _getStreamUrl(
    String deviceSn, {
    required bool retriedAfterTokenRefresh,
  }) async {
    final normalizedSn = deviceSn.trim();
    if (normalizedSn.isEmpty) {
      throw const ImouApiException(
        'INVALID_DEVICE_SN',
        'Khong tim thay ma serial cua camera.',
      );
    }

    final request = _StartLiveRequest(_newSessionId(normalizedSn));
    _pendingStarts[normalizedSn] = request;
    debugPrint(
      '[ImouStreamRepository] startLive requestId=${request.id} '
      'deviceId=${_maskDeviceId(normalizedSn)}',
    );

    String? accessTokenValue;
    String? bindLiveToken;
    String? selectedStreamLiveToken;
    String? selectedLiveToken;
    var cleanupHandled = false;

    try {
      final accessToken = await _dataSource.getAccessToken();
      accessTokenValue = accessToken.token;
      _throwIfCancelledOrStale(normalizedSn, request);

      final isOnline = await _dataSource.isDeviceOnline(
        accessToken: accessToken.token,
        deviceSn: normalizedSn,
      );
      if (!isOnline) {
        throw const ImouApiException(
          'DEVICE_OFFLINE',
          'Camera is offline or disconnected',
        );
      }
      _throwIfCancelledOrStale(normalizedSn, request);

      bindLiveToken = await _dataSource.bindDeviceLive(
        accessToken: accessToken.token,
        deviceSn: normalizedSn,
        channelId: _defaultChannelId,
        streamId: _defaultStreamId,
      );
      if (_isCancelledOrStale(normalizedSn, request)) {
        debugPrint(
          '[ImouStreamRepository] bindDeviceLive returned after cancellation '
          'requestId=${request.id} deviceId=${_maskDeviceId(normalizedSn)}',
        );
        cleanupHandled = true;
        await _cleanupLiveTokens(
          accessToken: accessToken.token,
          deviceId: normalizedSn,
          requestId: request.id,
          liveTokens: [bindLiveToken],
          reason: 'cancelled after bindDeviceLive',
        );
        throw LiveStartCancelledException(normalizedSn);
      }

      final streamInfo = await _dataSource.getLiveStreamInfo(
        accessToken: accessToken.token,
        deviceSn: normalizedSn,
        channelId: _defaultChannelId,
      );

      final selectedStream = streamInfo.selectedStream;
      selectedStreamLiveToken = selectedStream?.liveToken?.trim();
      final streamUrl = selectedStream?.playbackUrl?.trim();
      if (streamUrl == null || streamUrl.isEmpty) {
        throw const ImouApiException(
          'NO_STREAM_URL',
          'No playable live stream found',
        );
      }

      final streamToken = selectedStreamLiveToken;
      selectedLiveToken = streamToken != null && streamToken.isNotEmpty
          ? streamToken
          : bindLiveToken?.trim();
      if (selectedLiveToken == null || selectedLiveToken.isEmpty) {
        throw const ImouApiException(
          'NO_LIVE_TOKEN',
          'Imou Cloud did not return a live token.',
        );
      }

      if (_isCancelledOrStale(normalizedSn, request)) {
        cleanupHandled = true;
        await _cleanupLiveTokens(
          accessToken: accessToken.token,
          deviceId: normalizedSn,
          requestId: request.id,
          liveTokens: [
            bindLiveToken,
            selectedStreamLiveToken,
            selectedLiveToken,
          ],
          reason: 'cancelled after getLiveStreamInfo',
        );
        throw LiveStartCancelledException(normalizedSn);
      }

      final session = _ImouStreamSession(
        sessionId: request.id,
        deviceId: normalizedSn,
        channelId: _defaultChannelId,
        streamId: selectedStream?.streamId ?? _defaultStreamId,
        streamUrl: streamUrl,
        liveToken: selectedLiveToken,
        createdAt: DateTime.now(),
      );
      _activeSessions[normalizedSn] = session;
      _removePendingIfCurrent(normalizedSn, request);
      debugPrint(
        '[ImouStreamRepository] active session saved '
        'deviceId=${_maskDeviceId(normalizedSn)} sessionId=${session.sessionId} '
        'streamId=${session.streamId} protocol=${Uri.tryParse(streamUrl)?.scheme ?? 'unknown'} '
        'liveToken=${_maskToken(selectedLiveToken)}',
      );
      return streamUrl;
    } on ImouApiException catch (error) {
      final shouldRetryToken =
          !retriedAfterTokenRefresh &&
          !_isCancelledOrStale(normalizedSn, request) &&
          _isTokenExpired(error);
      await _cleanupFailedStart(
        deviceId: normalizedSn,
        request: request,
        accessToken: accessTokenValue,
        liveTokens: [bindLiveToken, selectedStreamLiveToken, selectedLiveToken],
        cleanupHandled: cleanupHandled,
        reason: 'startLive failed before active session was saved',
      );
      _removePendingIfCurrent(normalizedSn, request);
      if (shouldRetryToken) {
        debugPrint('[ImouStreamRepository] token expired, refreshing once');
        _dataSource.clearAccessToken();
        return _getStreamUrl(normalizedSn, retriedAfterTokenRefresh: true);
      }
      rethrow;
    } catch (error) {
      await _cleanupFailedStart(
        deviceId: normalizedSn,
        request: request,
        accessToken: accessTokenValue,
        liveTokens: [bindLiveToken, selectedStreamLiveToken, selectedLiveToken],
        cleanupHandled: cleanupHandled,
        reason: 'startLive failed before active session was saved',
      );
      _removePendingIfCurrent(normalizedSn, request);
      rethrow;
    }
  }

  @override
  Future<void> releaseStreamSession(String deviceSn) async {
    final normalizedSn = deviceSn.trim();
    if (normalizedSn.isEmpty) return;

    final pending = _pendingStarts[normalizedSn];
    if (pending != null) {
      pending.isCancelled = true;
      debugPrint(
        '[ImouStreamRepository] startLive cancelled while pending '
        'deviceId=${_maskDeviceId(normalizedSn)} requestId=${pending.id}',
      );
    }

    final session = _activeSessions.remove(normalizedSn);
    debugPrint(
      '[ImouStreamRepository] stopLive called '
      'deviceId=${_maskDeviceId(normalizedSn)} active=${session != null} '
      'pending=${pending != null}',
    );
    if (session == null) return;

    try {
      final accessToken = await _dataSource.getAccessToken();
      await _cleanupLiveTokens(
        accessToken: accessToken.token,
        deviceId: normalizedSn,
        requestId: session.sessionId,
        liveTokens: [session.liveToken],
        reason: 'screen_closed',
      );
    } on Object catch (error) {
      debugPrint('[ImouStreamRepository] unbind failed: $error');
    }
  }

  Future<void> _cleanupFailedStart({
    required String deviceId,
    required _StartLiveRequest request,
    required String? accessToken,
    required List<String?> liveTokens,
    required bool cleanupHandled,
    required String reason,
  }) async {
    if (cleanupHandled || accessToken == null) return;
    final ownsActiveSession =
        _activeSessions[deviceId]?.sessionId == request.id;
    if (ownsActiveSession) return;

    await _cleanupLiveTokens(
      accessToken: accessToken,
      deviceId: deviceId,
      requestId: request.id,
      liveTokens: liveTokens,
      reason: reason,
    );
  }

  Future<void> _cleanupLiveTokens({
    required String accessToken,
    required String deviceId,
    required String requestId,
    required Iterable<String?> liveTokens,
    required String reason,
  }) async {
    final uniqueTokens = <String>{};
    for (final token in liveTokens) {
      final value = token?.trim();
      if (value != null && value.isNotEmpty) uniqueTokens.add(value);
    }

    for (final liveToken in uniqueTokens) {
      try {
        debugPrint(
          '[ImouStreamRepository] cleanup unbind reason=$reason '
          'deviceId=${_maskDeviceId(deviceId)} requestId=$requestId '
          'liveToken=${_maskToken(liveToken)}',
        );
        await _dataSource.unbindLive(
          accessToken: accessToken,
          liveToken: liveToken,
        );
      } on Object catch (error) {
        debugPrint(
          '[ImouStreamRepository] cleanup unbind failed reason=$reason '
          'deviceId=${_maskDeviceId(deviceId)} requestId=$requestId '
          'liveToken=${_maskToken(liveToken)} error=$error',
        );
      }
    }
  }

  void _throwIfCancelledOrStale(String deviceId, _StartLiveRequest request) {
    if (!_isCancelledOrStale(deviceId, request)) return;
    throw LiveStartCancelledException(deviceId);
  }

  bool _isCancelledOrStale(String deviceId, _StartLiveRequest request) {
    final current = _pendingStarts[deviceId];
    return request.isCancelled || current == null || current.id != request.id;
  }

  void _removePendingIfCurrent(String deviceId, _StartLiveRequest request) {
    if (_pendingStarts[deviceId]?.id == request.id) {
      _pendingStarts.remove(deviceId);
    }
  }

  bool _isTokenExpired(ImouApiException error) {
    final normalized = '${error.code} ${error.message}'.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('auth') ||
        normalized.contains('expired') ||
        normalized.contains('unauthorized');
  }

  String _newSessionId(String deviceId) {
    final sequence = ++_requestSequence;
    return '${deviceId.hashCode.abs()}-$sequence-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _maskDeviceId(String deviceId) {
    final value = deviceId.trim();
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }

  String _maskToken(String token) {
    final value = token.trim();
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
  }
}

class _StartLiveRequest {
  _StartLiveRequest(this.id);

  final String id;
  bool isCancelled = false;
}

class _ImouStreamSession {
  const _ImouStreamSession({
    required this.sessionId,
    required this.deviceId,
    required this.channelId,
    required this.streamId,
    required this.streamUrl,
    required this.liveToken,
    required this.createdAt,
  });

  final String sessionId;
  final String deviceId;
  final String channelId;
  final int streamId;
  final String streamUrl;
  final String liveToken;
  final DateTime createdAt;
}
