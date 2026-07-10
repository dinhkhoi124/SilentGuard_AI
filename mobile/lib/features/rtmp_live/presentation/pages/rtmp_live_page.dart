import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/injection_container.dart';

import 'package:collection/collection.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../../home/presentation/bloc/home_state.dart';
import '../bloc/rtmp_live_bloc.dart';
import '../bloc/rtmp_live_event.dart';
import '../bloc/rtmp_live_state.dart';
import '../widgets/rtmp_controls_overlay.dart';
import '../widgets/rtmp_error_panel.dart';
import '../widgets/rtmp_info_panel.dart';
import '../widgets/rtmp_live_badge.dart';
import '../widgets/rtmp_loading_panel.dart';
import '../widgets/rtmp_video_player.dart';

// Màn hình xem livestream RTMP — chỉ chịu trách nhiệm kết nối Bloc với UI.
// Không chứa business logic, không gọi API, không tự quản lý animation.
class RtmpLivePage extends StatefulWidget {
  const RtmpLivePage({super.key});

  @override
  State<RtmpLivePage> createState() => _RtmpLivePageState();
}

class _RtmpLivePageState extends State<RtmpLivePage> {
  RtmpLiveBloc? _bloc;
  String? _lastDeviceSn; // tránh tạo lại bloc khi rebuild cùng deviceSn

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        debugPrint('[RtmpLivePage] HomeBloc state: ${homeState.runtimeType}');

        if (homeState is! HomeLoaded) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),
          );
        }

        // Tên field cameras — dùng đúng tên thực tế trong HomeLoaded
        final cameras = homeState.devices;
        final camera = cameras.firstWhereOrNull(
          (c) => c.serialNumber != null && c.serialNumber!.isNotEmpty,
        );

        if (camera == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(
              child: Text(
                'Không tìm thấy camera hợp lệ.\nVui lòng thêm camera trước.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final deviceSn = camera.serialNumber!;

        // Chỉ tạo Bloc mới nếu deviceSn thay đổi
        if (_bloc == null || _lastDeviceSn != deviceSn) {
          debugPrint(
            '[RtmpLivePage] Creating new RtmpLiveBloc for deviceSn: $deviceSn',
          );
          _bloc?.close(); // đóng bloc cũ nếu có
          _bloc = sl<RtmpLiveBloc>()..add(RtmpLiveStarted(deviceSn: deviceSn));
          _lastDeviceSn = deviceSn;
        }

        return BlocProvider.value(
          value: _bloc!,
          child: _RtmpLiveView(cameraName: camera.name),
        );
      },
    );
  }
}

// View nội bộ — tách khỏi BlocProvider để rebuild độc lập
class _RtmpLiveView extends StatefulWidget {
  const _RtmpLiveView({required this.cameraName});
  final String cameraName;

  @override
  State<_RtmpLiveView> createState() => _RtmpLiveViewState();
}

class _RtmpLiveViewState extends State<_RtmpLiveView> {
  Player? _player;
  VideoController? _videoController;
  bool _showControls = false;

  void _onPlayerReady(Player player, VideoController controller) {
    _player = player;
    _videoController = controller;
  }

  void _enterFullscreen(bool isHd) {
    if (_player == null || _videoController == null) return;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => _FullscreenRtmpPage(
              player: _player!,
              videoController: _videoController!,
              cameraName: widget.cameraName,
              isHd: isHd,
            ),
          ),
        )
        .then((_) {
          // Restore orientation
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE RTMP',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2.0,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.cameraName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<RtmpLiveBloc, RtmpLiveState>(
            builder: (context, state) {
              final isLive = state is RtmpLiveLoaded;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: RtmpLiveBadge(isLive: isLive),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Iconsax.refresh, color: AppColors.mutedText),
            onPressed: () {
              context.read<RtmpLiveBloc>().add(
                const RtmpLiveRefreshRequested(),
              );
            },
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BlocBuilder<RtmpLiveBloc, RtmpLiveState>(
                builder: (context, state) {
                  return switch (state) {
                    RtmpLiveInitial() ||
                    RtmpLiveLoading() => const RtmpLoadingPanel(),
                    RtmpLiveFailure() => RtmpErrorPanel(
                      message: state.message,
                      onRetry: () => context.read<RtmpLiveBloc>().add(
                        const RtmpLiveRefreshRequested(),
                      ),
                    ),
                    RtmpLiveLoaded() => GestureDetector(
                      onTap: () {
                        setState(() {
                          _showControls = !_showControls;
                        });
                      },
                      child: Stack(
                        children: [
                          RtmpVideoPlayer(
                            streamUrl: state.stream.url,
                            isMuted: state.isMuted,
                            onPlaybackError: (error) {
                              context.read<RtmpLiveBloc>().add(
                                RtmpLivePlaybackFailed(error: error),
                              );
                            },
                            onPlayerReady: _onPlayerReady,
                          ),
                          AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: RtmpControlsOverlay(
                                isMuted: state.isMuted,
                                isHd: state.stream.isHd,
                                onMuteToggle: () {
                                  context.read<RtmpLiveBloc>().add(
                                    const RtmpLiveMuteToggled(),
                                  );
                                },
                                onFullscreen: () =>
                                    _enterFullscreen(state.stream.isHd),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  };
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<RtmpLiveBloc, RtmpLiveState>(
            builder: (context, state) {
              if (state is RtmpLiveLoaded) {
                return RtmpInfoPanel(stream: state.stream);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

// Widget màn hình Fullscreen không đổi
class _FullscreenRtmpPage extends StatefulWidget {
  const _FullscreenRtmpPage({
    required this.player,
    required this.videoController,
    required this.cameraName,
    required this.isHd,
  });

  final Player player;
  final VideoController videoController;
  final String cameraName;
  final bool isHd;

  @override
  State<_FullscreenRtmpPage> createState() => _FullscreenRtmpPageState();
}

class _FullscreenRtmpPageState extends State<_FullscreenRtmpPage> {
  bool _showControls = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _isMuted = widget.player.state.volume == 0;
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: Video(
                controller: widget.videoController,
                controls: NoVideoControls,
                fill: Colors.black,
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Iconsax.close_circle,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.cameraName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const RtmpLiveBadge(isLive: true),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isMuted
                                  ? Iconsax.volume_slash
                                  : Iconsax.volume_high,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() => _isMuted = !_isMuted);
                              widget.player.setVolume(_isMuted ? 0 : 100);
                            },
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF333333),
                              ),
                            ),
                            child: Text(
                              widget.isHd ? 'HD RTMP' : 'SD RTMP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Iconsax.size, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
