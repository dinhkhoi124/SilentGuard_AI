// Các sự kiện người dùng hoặc hệ thống gửi vào RtmpLiveBloc.
sealed class RtmpLiveEvent {
  const RtmpLiveEvent();
}

// Sự kiện khởi động: tải stream khi màn hình được mở lần đầu.
final class RtmpLiveStarted extends RtmpLiveEvent {
  const RtmpLiveStarted({required this.deviceSn});
  final String deviceSn;
}

// Sự kiện làm mới: người dùng bấm nút "Làm mới luồng".
final class RtmpLiveRefreshRequested extends RtmpLiveEvent {
  const RtmpLiveRefreshRequested();
}

// Sự kiện bật/tắt âm thanh.
final class RtmpLiveMuteToggled extends RtmpLiveEvent {
  const RtmpLiveMuteToggled();
}

// Sự kiện khi player báo lỗi phát video giữa chừng (camera mất kết nối khi đang xem).
final class RtmpLivePlaybackFailed extends RtmpLiveEvent {
  const RtmpLivePlaybackFailed({required this.error});
  final String error;
}
