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
  static const _playerConfiguration = PlayerConfiguration(
    bufferSize: 32 * 1024 * 1024,
    logLevel: MPVLogLevel.warn,
  );
  static const _unsupportedStreamMessage =
      'Camera đang trực tuyến nhưng luồng trực tiếp hiện chưa hỗ trợ trên Android. Vui lòng thử lại sau hoặc kiểm tra cấu hình camera.';
  static bool _nativeMediaKitRegistered = false;

  Player? _player;
  media_kit_video.VideoController? _videoController;
  final List<StreamSubscription<Object?>> _playerSubscriptions = [];
  bool _isOpening = false;
  String? _errorMessage;
  Timer? _blackScreenTimer;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _initController();
  }

  @override
  void didUpdateWidget(covariant CameraLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.rtspUrl != widget.rtspUrl) {
      final streamUrl = widget.rtspUrl?.trim();
      if (streamUrl == null || streamUrl.isEmpty) {
        unawaited(_player?.stop());
        setState(() {
          _isOpening = false;
          _errorMessage = 'Chưa có đường dẫn phát trực tiếp cho camera này.';
        });
      } else if (_player != null) {
        if (_rejectUnsupportedStream(streamUrl)) return;
        if (_isOpening) return;
        setState(() {
          _isOpening = true;
          _errorMessage = null;
        });
        unawaited(
          _player!
              .open(Media(streamUrl), play: true)
              .catchError((Object _) {
                debugPrint('[media_kit] stream open failed');
                if (mounted) {
                  setState(() {
                    _errorMessage =
                        'Không thể phát trực tiếp camera. Vui lòng thử tải lại.';
                  });
                }
              })
              .whenComplete(() {
                if (mounted && widget.rtspUrl?.trim() == streamUrl) {
                  setState(() => _isOpening = false);
                }
              }),
        );
      } else {
        _initController();
      }
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
    _validateAndOpen(streamUrl);
  }

  void _validateAndOpen(String url) {
    if (_rejectUnsupportedStream(url)) return;
    unawaited(_openStreamWhenReady(url));
  }

  bool _rejectUnsupportedStream(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'rtmp' && scheme != 'rtmps') return false;

    debugPrint('[media_kit] rejected unsupported stream format: $scheme');
    if (mounted) {
      setState(() {
        _isOpening = false;
        _errorMessage = _unsupportedStreamMessage;
      });
    }
    return true;
  }

  Future<void> _ensureNativeMediaKitRegistered() async {
    if (!Platform.isAndroid || _nativeMediaKitRegistered) return;
    await _mediaKitChannel.invokeMethod<void>('registerMediaKit');
    _nativeMediaKitRegistered = true;
  }

  Future<void> _openStreamWhenReady(String streamUrl) async {
    if (_isOpening) return;
    _isOpening = true;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || widget.rtspUrl?.trim() != streamUrl) {
      _isOpening = false;
      return;
    }

    await _ensureNativeMediaKitRegistered();
    final player = Player(configuration: _playerConfiguration);
    final videoController = media_kit_video.VideoController(player);

    if (!mounted || widget.rtspUrl?.trim() != streamUrl) {
      unawaited(player.dispose());
      _isOpening = false;
      return;
    }

    _player = player;
    _videoController = videoController;
    _listenToPlayerLogs(player);
    setState(() {
      _errorMessage = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await player.stop();
      if (!mounted || !identical(_player, player)) {
        _isOpening = false;
        return;
      }

      try {
        if (_rejectUnsupportedStream(streamUrl)) return;
        await player.open(Media(streamUrl), play: true);
      } catch (_) {
        debugPrint('[media_kit] stream open failed');
        if (mounted) {
          setState(
            () => _errorMessage =
                'Không thể phát trực tiếp camera. Vui lòng thử tải lại.',
          );
        }
      } finally {
        if (mounted) setState(() => _isOpening = false);
      }

      _blackScreenTimer?.cancel();
      _blackScreenTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && (_player?.state.width ?? 0) == 0) {
          setState(() {
            _errorMessage =
                'Không thể phát trực tiếp camera. Vui lòng thử tải lại.';
          });
        }
      });
    });
  }

  void _listenToPlayerLogs(Player player) {
    _playerSubscriptions.addAll([
      player.stream.error.listen((error) {
        debugPrint('[media_kit] stream playback error');
        developer.log('Stream playback failed.', name: 'CameraLivePreview');
        if (!mounted || !identical(_player, player)) return;
        setState(() {
          _isOpening = false;
          _errorMessage =
              'Không thể phát trực tiếp camera. Vui lòng thử tải lại.';
        });
      }),
      player.stream.width.listen((width) {
        if (width != null && width > 0) _blackScreenTimer?.cancel();
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
    final videoController = _videoController;
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

    _blackScreenTimer?.cancel();

    if (player == null) return;

    if (captureFrame) await _captureLastFrame(player);

    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}

    // Ensure controller is disposed after player as requested
    // ignore: undefined_method
    try {
      (videoController as dynamic)?.dispose();
    } catch (_) {}
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

    // Video widget not yet created — show loading
    if (videoController == null) {
      return const _VideoLoadingView();
    }

    // Video() stays mounted always once controller exists.
    // Loading and error states overlay on top — never replace Video().
    return Stack(
      fit: StackFit.expand,
      children: [
        media_kit_video.Video(controller: videoController, fit: BoxFit.cover),
        // Error from parent (stream URL fetch failed, etc.)
        if (widget.errorMessage != null &&
            widget.errorMessage!.trim().isNotEmpty)
          _VideoErrorView(message: widget.errorMessage!, onRetry: _retryStream)
        // Internal player error
        else if (_errorMessage != null)
          _VideoErrorView(message: _errorMessage!, onRetry: _retryStream)
        // Loading overlay — semi-transparent so surface stays alive
        else if (widget.isLoading || _isOpening)
          const _VideoLoadingView(),
      ],
    );
  }

  Future<void> _retryStream() async {
    await _disposeControllers(captureFrame: false, notify: false);

    final player = Player(configuration: _playerConfiguration);
    _player = player;
    _videoController = media_kit_video.VideoController(player);
    _listenToPlayerLogs(player);

    if (mounted) {
      setState(() {
        _errorMessage = null;
        _isOpening = false;
      });
    }
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
