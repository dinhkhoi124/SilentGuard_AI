// Thực thể đại diện cho một phiên stream RTMP từ camera Imou.
// Là pure Dart — không phụ thuộc vào Flutter hay bất kỳ thư viện nào.
class RtmpStream {
  const RtmpStream({
    required this.deviceSn,
    required this.url,
    required this.isHd,
  });

  // Serial number của camera nguồn
  final String deviceSn;

  // URL RTMP để phát video (rtmpHD ưu tiên hơn rtmp)
  final String url;

  // true nếu đang dùng luồng HD (rtmpHD), false nếu SD (rtmp)
  final bool isHd;
}
