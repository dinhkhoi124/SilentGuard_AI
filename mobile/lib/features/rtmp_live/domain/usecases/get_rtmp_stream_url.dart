import '../entities/rtmp_stream.dart';
import '../repositories/rtmp_stream_repository.dart';

// UseCase: Lấy thông tin stream RTMP cho một camera cụ thể.
// Đóng gói business rule: kiểm tra serial number hợp lệ trước khi gọi repository.
class GetRtmpStreamUrl {
  const GetRtmpStreamUrl(this._repository);

  final RtmpStreamRepository _repository;

  // Thực thi use case với serial number của camera.
  // Trả về RtmpStream nếu thành công.
  // Ném ArgumentError nếu deviceSn rỗng.
  Future<RtmpStream> call(String deviceSn) {
    // Kiểm tra đầu vào — serial number không được rỗng
    if (deviceSn.trim().isEmpty) {
      throw ArgumentError('deviceSn không được rỗng');
    }
    return _repository.getStream(deviceSn.trim());
  }
}
