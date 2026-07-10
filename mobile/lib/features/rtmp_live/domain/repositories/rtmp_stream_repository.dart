import '../entities/rtmp_stream.dart';

// Interface định nghĩa hợp đồng cho việc lấy stream RTMP.
// Presentation và Domain chỉ phụ thuộc vào interface này,
// không biết gì về ImouCloudDataSource hay HTTP.
abstract class RtmpStreamRepository {
  // Lấy URL RTMP tốt nhất cho camera với serial number cho trước.
  // Ném RtmpStreamException nếu camera offline hoặc không lấy được URL.
  Future<RtmpStream> getStream(String deviceSn);
}

// Exception thuộc domain — không lộ chi tiết HTTP hay Imou API ra ngoài.
class RtmpStreamException implements Exception {
  const RtmpStreamException({required this.code, required this.message});
  final String code;
  final String message;
}
