import '../../domain/entities/rtmp_stream.dart';

// Trạng thái của màn hình Live RTMP.
sealed class RtmpLiveState {
  const RtmpLiveState();
}

// Trạng thái ban đầu — chưa bắt đầu tải.
final class RtmpLiveInitial extends RtmpLiveState {
  const RtmpLiveInitial();
}

// Đang tải URL stream từ Imou Cloud.
final class RtmpLiveLoading extends RtmpLiveState {
  const RtmpLiveLoading();
}

// Stream đã sẵn sàng — trả về entity để widget tạo player.
final class RtmpLiveLoaded extends RtmpLiveState {
  const RtmpLiveLoaded({required this.stream, required this.isMuted});
  final RtmpStream stream;
  final bool isMuted;
}

// Đã xảy ra lỗi — cung cấp message tiếng Việt để hiển thị.
final class RtmpLiveFailure extends RtmpLiveState {
  const RtmpLiveFailure({required this.message});
  final String message;
}
