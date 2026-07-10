import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Đóng gói logic khởi tạo và dọn dẹp trình phát video `media_kit`.
// KHÔNG quản lý logic nghiệp vụ hay kết nối mạng.
class RtmpVideoPlayer extends StatefulWidget {
  const RtmpVideoPlayer({
    super.key,
    required this.streamUrl,
    required this.isMuted,
    required this.onPlaybackError,
    required this.onPlayerReady,
  });

  final String streamUrl;
  final bool isMuted;
  final void Function(String) onPlaybackError;

  // Callback để truyền VideoController ra ngoài cho Fullscreen hoặc Overlay
  final void Function(Player, VideoController) onPlayerReady;

  @override
  State<RtmpVideoPlayer> createState() => _RtmpVideoPlayerState();
}

class _RtmpVideoPlayerState extends State<RtmpVideoPlayer> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<void>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant RtmpVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cập nhật âm lượng ngay khi prop isMuted thay đổi từ Bloc state
    if (widget.isMuted != oldWidget.isMuted) {
      _player?.setVolume(widget.isMuted ? 0 : 100);
    }

    // Nếu URL thay đổi (rất hiếm khi xảy ra), ta phải khởi tạo lại
    if (widget.streamUrl != oldWidget.streamUrl) {
      _disposePlayer().then((_) => _initializePlayer());
    }
  }

  // Khởi tạo trình phát và lắng nghe lỗi
  void _initializePlayer() {
    final player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.debug),
    );
    final controller = VideoController(player);

    setState(() {
      _player = player;
      _videoController = controller;
    });

    _errorSubscription = player.stream.error.listen((error) {
      debugPrint('[RtmpVideoPlayer] Lỗi playback: $error');
      widget.onPlaybackError(error.toString());
    });

    // Thêm listener log tạm để xem lỗi nội bộ
    player.stream.log.listen((event) {
      debugPrint('[MPV LOG] ${event.prefix}: ${event.text}');
    });

    player.setVolume(widget.isMuted ? 0 : 100);
    player.open(Media(widget.streamUrl));

    widget.onPlayerReady(player, controller);
  }

  // Dọn dẹp trình phát và bộ lắng nghe sự kiện
  Future<void> _disposePlayer() async {
    await _errorSubscription?.cancel();
    final oldPlayer = _player;
    _player = null;
    _videoController = null;
    if (oldPlayer != null) {
      await oldPlayer.dispose();
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoController == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black,
      child: Video(
        controller: _videoController!,
        controls: NoVideoControls,
        fill: Colors.black,
      ),
    );
  }
}
