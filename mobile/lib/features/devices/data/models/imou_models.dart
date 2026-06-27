class ImouAccessToken {
  const ImouAccessToken({required this.token, required this.expireAt});

  final String token;
  final DateTime expireAt;
}

class ImouLiveStreamInfo {
  const ImouLiveStreamInfo({
    required this.streams,
    required this.status,
    this.bindLiveToken,
  });

  final List<ImouLiveStream> streams;
  final String status;
  final String? bindLiveToken;

  ImouLiveStream? get selectedStream {
    for (final preferredStreamId in const [1, 0]) {
      for (final preferHttp in const [true, false]) {
        for (final stream in streams) {
          if (stream.streamId != preferredStreamId) continue;
          final url = stream.playbackUrl;
          if (url == null || url.isEmpty) continue;
          final isHttps = url.toLowerCase().startsWith('https://');
          final isHttp = url.toLowerCase().startsWith('http://');
          if (preferHttp && isHttp && !isHttps) return stream;
          if (!preferHttp && isHttps) return stream;
        }
      }
    }
    return null;
  }

  String? get hlsUrl => selectedStream?.hls;

  String? get flvUrl => selectedStream?.flv;

  String? get playbackUrl => selectedStream?.playbackUrl;

  String get liveToken {
    final streamToken = selectedStream?.liveToken?.trim();
    if (streamToken != null && streamToken.isNotEmpty) return streamToken;
    return bindLiveToken?.trim() ?? '';
  }
}

class ImouLiveStream {
  const ImouLiveStream({
    required this.streamId,
    required this.status,
    this.hls,
    this.flv,
    this.liveToken,
  });

  final int? streamId;
  final String status;
  final String? hls;
  final String? flv;
  final String? liveToken;

  String? get playbackUrl {
    final hlsUrl = hls?.trim();
    if (hlsUrl != null && hlsUrl.isNotEmpty) return hlsUrl;
    final flvUrl = flv?.trim();
    if (flvUrl != null && flvUrl.isNotEmpty) return flvUrl;
    return null;
  }

  String get protocol =>
      Uri.tryParse(playbackUrl ?? '')?.scheme.toLowerCase() ?? '';
}

class ImouDevice {
  const ImouDevice({
    required this.deviceSn,
    required this.deviceName,
    required this.status,
    this.channelId,
  });

  final String deviceSn;
  final String deviceName;
  final String status;
  final String? channelId;
}

class ImouApiException implements Exception {
  const ImouApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ImouApiException($code): $message';
}

class LiveStartCancelledException implements Exception {
  const LiveStartCancelledException(this.deviceId);

  final String deviceId;

  @override
  String toString() => 'LiveStartCancelledException($deviceId)';
}
