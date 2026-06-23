// lib/features/home/presentation/widgets/camera_video_player.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:mobile/core/utils/app_colors.dart';

class CameraVideoPlayer extends StatelessWidget {
  const CameraVideoPlayer({
    super.key,
    required this.currentTime,
    this.rtspUrl,
    this.onFrameCaptured,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final String currentTime;
  final String? rtspUrl;
  final ValueChanged<Uint8List>? onFrameCaptured;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraLivePreview(
                rtspUrl: rtspUrl,
                onFrameCaptured: onFrameCaptured,
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRetry: onRetry,
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    _OverlayPill(
                      color: Colors.white,
                      children: const [
                        _StatusDot(),
                        SizedBox(width: 5),
                        Text(
                          'TRỰC TIẾP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const _RoundOverlayButton(
                      icon: Icons.volume_up_outlined,
                      backgroundColor: Colors.white,
                      iconColor: AppColors.darkText,
                    ),
                  ],
                ),
              ),
              const Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    _OverlayPill(
                      color: Colors.black54,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          '1 người',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(width: 8),
                    _RoundOverlayButton(
                      icon: Icons.fullscreen,
                      backgroundColor: Colors.black54,
                      iconColor: Colors.white,
                    ),
                  ],
                ),
              ),
              const Positioned(
                bottom: 10,
                left: 10,
                child: _VideoLabel(
                  child: Text(
                    'HD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: _VideoLabel(
                  child: Text(
                    currentTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraLivePreview extends StatefulWidget {
  const CameraLivePreview({
    super.key,
    this.rtspUrl,
    this.onFrameCaptured,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final String? rtspUrl;
  final ValueChanged<Uint8List>? onFrameCaptured;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<CameraLivePreview> createState() => _CameraLivePreviewState();
}

class _CameraLivePreviewState extends State<CameraLivePreview> {
  static const _mediaKitChannel = MethodChannel('SlientGuard/media_kit');
  static bool _mediaKitInitialized = false;
  static bool _nativeMediaKitRegistered = false;

  Player? _player;
  media_kit_video.VideoController? _videoController;
  final List<StreamSubscription<Object?>> _playerSubscriptions = [];
  bool _isOpening = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant CameraLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.errorMessage?.trim().isNotEmpty ?? false) || widget.isLoading) {
      unawaited(_disposeControllers(captureFrame: false, notify: true));
      return;
    }
    if (oldWidget.rtspUrl != widget.rtspUrl) {
      unawaited(_disposeControllers(captureFrame: false, notify: true));
      _initController();
    }
  }

  @override
  void dispose() {
    unawaited(_disposeControllers(captureFrame: true, notify: false));
    super.dispose();
  }

  void _initController() {
    final streamUrl = widget.rtspUrl?.trim();
    if (streamUrl == null || streamUrl.isEmpty) {
      setState(() {
        _isOpening = false;
        _errorMessage = 'Chưa có đường dẫn phát trực tiếp cho camera này.';
      });
      return;
    }
    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });
    unawaited(
      _openStreamWhenReady(streamUrl).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        developer.log(
          'Không thể mở luồng camera bằng media_kit.',
          name: 'CameraLivePreview',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted || widget.rtspUrl?.trim() != streamUrl) return;
        setState(() {
          _isOpening = false;
          _errorMessage =
              'Không thể mở luồng camera. Vui lòng kiểm tra kết nối và thử lại.';
        });
      }),
    );
  }

  void _ensureMediaKitInitialized() {
    if (_mediaKitInitialized) return;
    MediaKit.ensureInitialized();
    _mediaKitInitialized = true;
  }

  Future<void> _ensureNativeMediaKitRegistered() async {
    if (!Platform.isAndroid || _nativeMediaKitRegistered) return;
    await _mediaKitChannel.invokeMethod<void>('registerMediaKit');
    _nativeMediaKitRegistered = true;
  }

  Future<void> _openStreamWhenReady(String streamUrl) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || widget.rtspUrl?.trim() != streamUrl) return;

    await _ensureNativeMediaKitRegistered();
    _ensureMediaKitInitialized();
    final player = Player();
    final videoController = media_kit_video.VideoController(player);

    if (!mounted || widget.rtspUrl?.trim() != streamUrl) {
      unawaited(player.dispose());
      return;
    }

    _player = player;
    _videoController = videoController;
    _listenToPlayerLogs(player);
    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });

    await player.stop();
    // Imou currently returns RTMP URLs. media_kit receives the URL as-is;
    // RTMP playback on Android depends on the bundled native media support.
    if (!mounted || !identical(_player, player)) return;
    await player.open(Media(streamUrl), play: true);
    if (!mounted || !identical(_player, player)) return;
    setState(() => _isOpening = false);
  }

  void _listenToPlayerLogs(Player player) {
    _playerSubscriptions.addAll([
      player.stream.error.listen((error) {
        developer.log('media_kit error: $error', name: 'CameraLivePreview');
        if (!mounted || !identical(_player, player)) return;
        setState(() {
          _isOpening = false;
          _errorMessage =
              'Không thể phát trực tiếp camera. Vui lòng thử tải lại.';
        });
      }),
      player.stream.log.listen((record) {
        developer.log(record.toString(), name: 'CameraLivePreview.media_kit');
      }),
      player.stream.width.listen((width) {
        developer.log('video width: $width', name: 'CameraLivePreview');
      }),
      player.stream.height.listen((height) {
        developer.log('video height: $height', name: 'CameraLivePreview');
      }),
    ]);
  }

  Future<void> _disposeControllers({
    required bool captureFrame,
    required bool notify,
  }) async {
    final player = _player;
    final subscriptions = List<StreamSubscription<Object?>>.of(
      _playerSubscriptions,
    );
    _playerSubscriptions.clear();
    _player = null;
    _videoController = null;
    if (notify && mounted) {
      setState(() {});
    }

    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }

    if (player == null) return;

    if (captureFrame) await _captureLastFrame(player);
    await player.stop();
    await player.dispose();
  }

  Future<void> _captureLastFrame(Player player) async {
    final onFrameCaptured = widget.onFrameCaptured;
    if (onFrameCaptured == null) return;

    try {
      final bytes = await player.screenshot(format: 'image/png');
      if (bytes == null || bytes.isEmpty) return;
      onFrameCaptured(bytes);
    } catch (error, stackTrace) {
      developer.log(
        'Khong the chup khung hinh cuoi cua camera.',
        name: 'CameraLivePreview',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _videoController;
    final parentErrorMessage = widget.errorMessage?.trim();

    if (parentErrorMessage != null && parentErrorMessage.isNotEmpty) {
      return _VideoErrorView(
        message: parentErrorMessage,
        onRetry: _retryStream,
      );
    }

    if (widget.isLoading) {
      return const _VideoLoadingView();
    }

    if (videoController != null && _errorMessage == null) {
      return media_kit_video.Video(
        controller: videoController,
        fit: BoxFit.cover,
      );
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _VideoErrorView(message: errorMessage, onRetry: _retryStream);
    }

    if (_isOpening) {
      return const _VideoLoadingView();
    }

    return const _VideoLoadingView();
  }

  Future<void> _retryStream() async {
    await _disposeControllers(captureFrame: false, notify: true);
    if (!mounted) return;
    widget.onRetry?.call();
  }
}

class _VideoLoadingView extends StatelessWidget {
  const _VideoLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _VideoErrorView extends StatelessWidget {
  const _VideoErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Tải lại')),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.color, required this.children});
  final Color color;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _RoundOverlayButton extends StatelessWidget {
  const _RoundOverlayButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
    child: Icon(icon, size: 16, color: iconColor),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: AppColors.safe,
      shape: BoxShape.circle,
    ),
  );
}

class _VideoLabel extends StatelessWidget {
  const _VideoLabel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(6),
    ),
    child: child,
  );
}
