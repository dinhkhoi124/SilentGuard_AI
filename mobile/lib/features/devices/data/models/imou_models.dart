class ImouAccessToken {
  const ImouAccessToken({required this.token, required this.expireAt});

  final String token;
  final DateTime expireAt;
}

class ImouLiveStreamInfo {
  const ImouLiveStreamInfo({
    required this.liveToken,
    required this.status,
    this.hlsUrl,
    this.flvUrl,
  });

  final String liveToken;
  final String? hlsUrl;
  final String? flvUrl;
  final String status;
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
