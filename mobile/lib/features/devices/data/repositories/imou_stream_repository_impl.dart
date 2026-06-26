import 'package:mobile/features/devices/data/datasources/imou_cloud_datasource.dart';
import 'package:mobile/features/devices/data/models/imou_models.dart';
import 'package:mobile/features/devices/domain/repositories/imou_stream_repository.dart';

class ImouStreamRepositoryImpl implements ImouStreamRepository {
  ImouStreamRepositoryImpl(this._dataSource);

  final ImouCloudDataSource _dataSource;
  final Map<String, String> _activeSessions = {};

  @override
  Future<String> getStreamUrl(String deviceSn) async {
    final normalizedSn = deviceSn.trim();
    if (normalizedSn.isEmpty) {
      throw const ImouApiException(
        'INVALID_DEVICE_SN',
        'Không tìm thấy mã serial của camera.',
      );
    }

    final accessToken = await _dataSource.getAccessToken();
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

    await _dataSource.bindDeviceLive(
      accessToken: accessToken.token,
      deviceSn: normalizedSn,
    );
    final streamInfo = await _dataSource.getLiveStreamInfo(
      accessToken: accessToken.token,
      deviceSn: normalizedSn,
    );

    final liveToken = streamInfo.liveToken.trim();
    if (liveToken.isNotEmpty) {
      _activeSessions[normalizedSn] = liveToken;
    }

    final streamUrl = _firstNonEmpty([streamInfo.hlsUrl, streamInfo.flvUrl]);
    if (streamUrl == null) {
      throw const ImouApiException(
        'NO_STREAM_URL',
        'No stream URL returned from Imou Cloud',
      );
    }
    return streamUrl;
  }

  @override
  Future<void> releaseStreamSession(String deviceSn) async {
    final normalizedSn = deviceSn.trim();
    final liveToken = _activeSessions.remove(normalizedSn);
    if (liveToken == null || liveToken.trim().isEmpty) return;

    final accessToken = await _dataSource.getAccessToken();
    await _dataSource.unbindLive(
      accessToken: accessToken.token,
      liveToken: liveToken,
    );
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
