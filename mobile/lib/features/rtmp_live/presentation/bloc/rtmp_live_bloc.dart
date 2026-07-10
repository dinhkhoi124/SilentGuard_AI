import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_rtmp_stream_url.dart';
import '../../domain/repositories/rtmp_stream_repository.dart';
import 'rtmp_live_event.dart';
import 'rtmp_live_state.dart';

// Bloc quản lý toàn bộ business logic cho màn hình Live RTMP.
// Chịu trách nhiệm: điều phối use case, map lỗi sang message tiếng Việt,
// và duy trì trạng thái mute giữa các lần refresh.
// KHÔNG chứa bất kỳ logic UI hay animation nào.
class RtmpLiveBloc extends Bloc<RtmpLiveEvent, RtmpLiveState> {
  RtmpLiveBloc({required GetRtmpStreamUrl getRtmpStreamUrl})
    : _getRtmpStreamUrl = getRtmpStreamUrl,
      super(const RtmpLiveInitial()) {
    on<RtmpLiveStarted>(_onStarted);
    on<RtmpLiveRefreshRequested>(_onRefreshRequested);
    on<RtmpLiveMuteToggled>(_onMuteToggled);
    on<RtmpLivePlaybackFailed>(_onPlaybackFailed);
  }

  final GetRtmpStreamUrl _getRtmpStreamUrl;

  // Lưu trạng thái mute giữa các lần refresh để không reset về unmuted
  bool _isMuted = false;

  // Lưu deviceSn để dùng lại khi refresh mà không cần truyền lại từ UI
  String? _deviceSn;

  // Xử lý sự kiện khởi động — lấy serial number và bắt đầu tải stream
  Future<void> _onStarted(
    RtmpLiveStarted event,
    Emitter<RtmpLiveState> emit,
  ) async {
    _deviceSn = event.deviceSn;
    await _loadStream(emit);
  }

  // Xử lý yêu cầu làm mới — dùng lại deviceSn đã lưu
  Future<void> _onRefreshRequested(
    RtmpLiveRefreshRequested event,
    Emitter<RtmpLiveState> emit,
  ) async {
    if (_deviceSn == null) return;
    await _loadStream(emit);
  }

  // Xử lý bật/tắt âm thanh — chỉ cập nhật state nếu đang loaded
  void _onMuteToggled(RtmpLiveMuteToggled event, Emitter<RtmpLiveState> emit) {
    final current = state;
    if (current is! RtmpLiveLoaded) return;

    // Đảo ngược trạng thái mute hiện tại
    _isMuted = !_isMuted;
    emit(RtmpLiveLoaded(stream: current.stream, isMuted: _isMuted));
  }

  // Xử lý lỗi phát video giữa chừng (camera bị rút, mất mạng)
  void _onPlaybackFailed(
    RtmpLivePlaybackFailed event,
    Emitter<RtmpLiveState> emit,
  ) {
    emit(
      const RtmpLiveFailure(
        message: 'Mất kết nối với camera. Vui lòng thử lại.',
      ),
    );
  }

  // Hàm nội bộ: thực thi use case và emit state tương ứng.
  // Tách ra để dùng chung cho _onStarted và _onRefreshRequested.
  Future<void> _loadStream(Emitter<RtmpLiveState> emit) async {
    emit(const RtmpLiveLoading());
    try {
      // Gọi use case — toàn bộ logic xác thực và gọi API nằm ở đây
      final stream = await _getRtmpStreamUrl(_deviceSn!);
      emit(RtmpLiveLoaded(stream: stream, isMuted: _isMuted));
    } on RtmpStreamException catch (e) {
      // Map mã lỗi domain sang message tiếng Việt thân thiện
      emit(RtmpLiveFailure(message: _mapError(e.code)));
    } catch (e) {
      // Lỗi không xác định — log và hiển thị message chung
      debugPrint('[RtmpLiveBloc] Unexpected error: $e');
      emit(
        const RtmpLiveFailure(message: 'Không thể kết nối. Vui lòng thử lại.'),
      );
    }
  }

  // Chuyển đổi mã lỗi từ domain sang message tiếng Việt hiển thị cho người dùng.
  // Không bao giờ hiển thị raw exception hay mã lỗi kỹ thuật ra UI.
  String _mapError(String code) => switch (code) {
    'DEVICE_OFFLINE' =>
      'Camera đang offline. Vui lòng kiểm tra nguồn điện và kết nối mạng.',
    'NO_RTMP_URL' =>
      'Không lấy được luồng video. Vui lòng thử lại sau vài giây.',
    _ => 'Kết nối thất bại. Vui lòng thử lại.',
  };
}
