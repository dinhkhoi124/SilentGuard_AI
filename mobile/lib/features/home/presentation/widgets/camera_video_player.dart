// lib/features/home/presentation/widgets/camera_video_player.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:mobile/core/utils/app_colors.dart';

enum CameraStreamLoadingPhase { authenticating, connectingStream, loadingFrame }

extension CameraStreamLoadingPhaseLabel on CameraStreamLoadingPhase {
  String get label {
    return switch (this) {
      CameraStreamLoadingPhase.authenticating => 'Đang xác thực camera...',
      CameraStreamLoadingPhase.connectingStream => 'Đang kết nối luồng hình...',
      CameraStreamLoadingPhase.loadingFrame => 'Đang tải hình ảnh...',
    };
  }
}

class CameraVideoPlayerController extends ChangeNotifier {
  CameraVideoPlayerController({
    required String currentTime,
    bool isLoading = false,
    String? errorMessage,
  }) : _currentTime = currentTime,
       _isLoading = isLoading,
       _errorMessage = errorMessage;

  String _currentTime;
  bool _isLoading;
  String? _errorMessage;

  String get currentTime => _currentTime;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void update({
    String? currentTime,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    var changed = false;
    if (currentTime != null && currentTime != _currentTime) {
      _currentTime = currentTime;
      changed = true;
    }
    if (isLoading != null && isLoading != _isLoading) {
      _isLoading = isLoading;
      changed = true;
    }
    final nextError = clearError ? null : errorMessage ?? _errorMessage;
    if (nextError != _errorMessage) {
      _errorMessage = nextError;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}

class CameraVideoPlayer extends StatefulWidget {
  const CameraVideoPlayer({
    super.key,
    required this.controller,
    this.rtspUrl,
    this.placeholderImage,
    this.onFrameCaptured,
    this.onRetry,
    this.onPlaybackError,
    this.onFirstFrameRendered,
    this.loadingPhase = CameraStreamLoadingPhase.loadingFrame,
    this.showLoadingOverlay = true,
  });

  final CameraVideoPlayerController controller;
  final String? rtspUrl;
  final Uint8List? placeholderImage;
  final ValueChanged<Uint8List>? onFrameCaptured;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onPlaybackError;
  final VoidCallback? onFirstFrameRendered;
  final CameraStreamLoadingPhase loadingPhase;
  final bool showLoadingOverlay;

  @override
  State<CameraVideoPlayer> createState() => CameraVideoPlayerState();
}

class CameraVideoPlayerState extends State<CameraVideoPlayer> {
  final _previewKey = GlobalKey<CameraLivePreviewState>();
  Player? _player;
  media_kit_video.VideoController? _videoController;
  bool _isMuted = false;

  void updateUrl(String newUrl) {
    _previewKey.currentState?.updateUrl(newUrl);
  }

  void updateDisplayState({bool? isLoading, String? errorMessage}) {
    _previewKey.currentState?.updateDisplayState(
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 32;
        final height = width * 9 / 16;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraLivePreview(
                    key: _previewKey,
                    rtspUrl: widget.rtspUrl,
                    placeholderImage: widget.placeholderImage,
                    onFrameCaptured: widget.onFrameCaptured,
                    isLoading: widget.controller.isLoading,
                    errorMessage: widget.controller.errorMessage,
                    onRetry: widget.onRetry,
                    onPlaybackError: widget.onPlaybackError,
                    onFirstFrameRendered: widget.onFirstFrameRendered,
                    loadingPhase: widget.loadingPhase,
                    showLoadingOverlay: widget.showLoadingOverlay,
                    onPlayerReady: (player, controller) {
                      if (mounted) {
                        setState(() {
                          _player = player;
                          _videoController = controller;
                        });
                        player.setVolume(_isMuted ? 0 : 100);
                      }
                    },
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        const _OverlayPill(
                          color: Colors.white,
                          children: [
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
                        GestureDetector(
                          onTap: () {
                            if (_player != null) {
                              setState(() {
                                _isMuted = !_isMuted;
                              });
                              _player!.setVolume(_isMuted ? 0 : 100);
                            }
                          },
                          child: _RoundOverlayButton(
                            icon: _isMuted
                                ? Icons.volume_off_outlined
                                : Icons.volume_up_outlined,
                            backgroundColor: Colors.white,
                            iconColor: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        const _OverlayPill(
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
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (_player != null && _videoController != null) {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => _FullscreenCameraPage(
                                        player: _player!,
                                        videoController: _videoController!,
                                        isMuted: _isMuted,
                                        onMuteToggle: () {
                                          setState(() {
                                            _isMuted = !_isMuted;
                                          });
                                          _player!.setVolume(
                                            _isMuted ? 0 : 100,
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                  .then((_) {
                                    SystemChrome.setPreferredOrientations([
                                      DeviceOrientation.portraitUp,
                                    ]);
                                  });
                            }
                          },
                          child: const _RoundOverlayButton(
                            icon: Icons.fullscreen,
                            backgroundColor: Colors.black54,
                            iconColor: Colors.white,
                          ),
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
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        return _VideoLabel(
                          child: Text(
                            widget.controller.currentTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CameraLivePreview extends StatefulWidget {
  const CameraLivePreview({
    super.key,
    this.rtspUrl,
    this.placeholderImage,
    this.onFrameCaptured,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onPlaybackError,
    this.onFirstFrameRendered,
    this.loadingPhase = CameraStreamLoadingPhase.loadingFrame,
    this.showLoadingOverlay = true,
    this.onPlayerReady,
  });

  final String? rtspUrl;
  final Uint8List? placeholderImage;
  final ValueChanged<Uint8List>? onFrameCaptured;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onPlaybackError;
  final VoidCallback? onFirstFrameRendered;
  final CameraStreamLoadingPhase loadingPhase;
  final bool showLoadingOverlay;
  final void Function(Player, media_kit_video.VideoController)? onPlayerReady;

  @override
  State<CameraLivePreview> createState() => CameraLivePreviewState();
}

class CameraLivePreviewState extends State<CameraLivePreview> {
  static const _mediaKitChannel = MethodChannel('SilentGuard/media_kit');
  static const _playerConfiguration = PlayerConfiguration(
    bufferSize: 32 * 1024 * 1024,
    logLevel: MPVLogLevel.warn,
  );
  static const _unsupportedStreamMessage =
      'Camera đang trực tuyến nhưng luồng trực tiếp hiện chưa hỗ trợ trên Android. Vui lòng thử lại sau hoặc kiểm tra cấu hình camera.';
  static const _streamOpenFailedMessage =
      'Không thể phát trực tiếp camera. Vui lòng thử tải lại.';
  static const _noStreamUrlMessage =
      'Chưa có đường dẫn phát trực tiếp cho camera này.';
  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 6),
  ];
  static bool _nativeMediaKitRegistered = false;

  Player? _player;
  media_kit_video.VideoController? _videoController;
  Future<void>? _playerInitialization;
  final List<StreamSubscription<Object?>> _playerSubscriptions = [];
  bool _isOpening = false;
  bool _hasOpenedUrl = false;
  bool _hasRenderedFrame = false;
  late bool _externalIsLoading;
  String? _externalErrorMessage;
  String? _errorMessage;
  String? _currentUrl;
  String? _pendingUrl;
  bool _surfaceReady = false;
  bool _surfaceReadyScheduled = false;
  Timer? _blackScreenTimer;
  Timer? _surfaceOpenTimer;
  Timer? _playbackRetryTimer;
  int _playbackRetryAttempt = 0;
  bool _reportedPlaybackFailure = false;
  String? _retryMessage;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.rtspUrl?.trim();
    _externalIsLoading = widget.isLoading;
    _externalErrorMessage = widget.errorMessage;
    debugPrint(
      '[VideoPlayer] initState() at: ${DateTime.now().toIso8601String()}, '
      'url: ${_redactedStreamUrl(widget.rtspUrl)}',
    );
    final initialUrl = _currentUrl;
    if (initialUrl == null || initialUrl.isEmpty) {
      if (!widget.isLoading) _errorMessage = _noStreamUrlMessage;
    } else {
      updateUrl(initialUrl);
    }
  }

  void updateUrl(String newUrl) {
    final normalizedUrl = newUrl.trim();
    if (normalizedUrl.isEmpty || normalizedUrl == 'unavailable') return;
    if (normalizedUrl == _currentUrl && !_isOpening && _hasOpenedUrl) return;
    final changedUrl = normalizedUrl != _currentUrl;
    _currentUrl = normalizedUrl;
    if (changedUrl) {
      _hasOpenedUrl = false;
      _hasRenderedFrame = false;
      _playbackRetryAttempt = 0;
      _reportedPlaybackFailure = false;
      _retryMessage = null;
      _playbackRetryTimer?.cancel();
    }
    if (_rejectUnsupportedStream(normalizedUrl)) return;
    _pendingUrl = normalizedUrl;
    unawaited(_preparePlayerAndOpen(normalizedUrl));
  }

  void updateDisplayState({bool? isLoading, String? errorMessage}) {
    var changed = false;
    if (isLoading != null && isLoading != _externalIsLoading) {
      _externalIsLoading = isLoading;
      changed = true;
    }
    if (errorMessage != _externalErrorMessage) {
      _externalErrorMessage = errorMessage;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CameraLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rtspUrl == widget.rtspUrl) return;
    debugPrint(
      '[VideoPlayer] URL changed from: '
      '${_redactedStreamUrl(oldWidget.rtspUrl)} to: '
      '${_redactedStreamUrl(widget.rtspUrl)}',
    );
    final nextUrl = widget.rtspUrl?.trim();
    if (nextUrl == null || nextUrl.isEmpty) {
      _currentUrl = null;
      _pendingUrl = null;
      _hasOpenedUrl = false;
      _hasRenderedFrame = false;
      _playbackRetryAttempt = 0;
      _reportedPlaybackFailure = false;
      _retryMessage = null;
      _playbackRetryTimer?.cancel();
      final player = _player;
      if (player != null) unawaited(player.stop());
      if (mounted && _errorMessage != _noStreamUrlMessage) {
        setState(() {
          _isOpening = false;
          _errorMessage = _noStreamUrlMessage;
        });
      }
      return;
    }
    updateUrl(nextUrl);
  }

  @override
  void dispose() {
    debugPrint(
      '[VideoPlayer] dispose() called at: ${DateTime.now().toIso8601String()}',
    );
    unawaited(_disposePlayer(captureFrame: true));
    super.dispose();
  }

  void _scheduleOpenAfterSurfaceReady() {
    if (_surfaceReady) return;
    if (_surfaceReadyScheduled) return;
    _surfaceReadyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _surfaceOpenTimer?.cancel();
      _surfaceOpenTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _surfaceReady = true;
        _surfaceReadyScheduled = false;
        final pendingUrl = _pendingUrl;
        if (pendingUrl == null || pendingUrl.isEmpty) return;
        if (_currentUrl != pendingUrl) return;
        unawaited(_openMedia(pendingUrl));
      });
    });
  }

  bool _rejectUnsupportedStream(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'rtmp' && scheme != 'rtmps') return false;
    debugPrint('[media_kit] rejected unsupported stream format: $scheme');
    if (mounted && _errorMessage != _unsupportedStreamMessage) {
      setState(() {
        _isOpening = false;
        _errorMessage = _unsupportedStreamMessage;
      });
    }
    return true;
  }

  Future<void> _ensureNativeMediaKitRegistered() async {
    if (!Platform.isAndroid || _nativeMediaKitRegistered) {
      return;
    }
    await _mediaKitChannel.invokeMethod<void>('registerMediaKit');
    _nativeMediaKitRegistered = true;
  }

  Future<void> _ensurePlayerInitialized() {
    if (_player != null && _videoController != null) return Future.value();
    final pendingInitialization = _playerInitialization;
    if (pendingInitialization != null) return pendingInitialization;

    final initialization = _initializePlayer();
    _playerInitialization = initialization;
    return initialization;
  }

  Future<void> _initializePlayer() async {
    try {
      await _ensureNativeMediaKitRegistered();
      if (!mounted) return;

      MediaKit.ensureInitialized();
      if (!mounted) return;

      final player = Player(configuration: _playerConfiguration);
      final videoController = media_kit_video.VideoController(player);
      _player = player;
      _videoController = videoController;
      debugPrint(
        '[VideoPlayer] VideoController created at: ${DateTime.now().toIso8601String()}',
      );
      _listenToPlayerLogs(player);
      widget.onPlayerReady?.call(player, videoController);
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      _playerInitialization = null;
      developer.log(
        'MediaKit player initialization failed.',
        name: 'CameraLivePreview',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && _errorMessage != _streamOpenFailedMessage) {
        setState(() => _errorMessage = _streamOpenFailedMessage);
      }
    }
  }

  Future<void> _preparePlayerAndOpen(String streamUrl) async {
    await _ensurePlayerInitialized();
    if (!mounted || _currentUrl != streamUrl) return;
    if (_player == null || _videoController == null) {
      if (_errorMessage != _streamOpenFailedMessage) {
        setState(() => _errorMessage = _streamOpenFailedMessage);
      }
      return;
    }
    if (_surfaceReady) {
      await _openMedia(streamUrl);
      return;
    }
    _scheduleOpenAfterSurfaceReady();
  }

  Future<void> _openMedia(String streamUrl) async {
    if (_isOpening) return;
    _isOpening = true;
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _retryMessage = null;
      });
    }

    try {
      await _ensurePlayerInitialized();
      final player = _player;
      if (!mounted || _currentUrl != streamUrl) return;
      if (player == null) {
        if (_errorMessage != _streamOpenFailedMessage) {
          setState(() => _errorMessage = _streamOpenFailedMessage);
        }
        return;
      }
      await player.stop();
      await _applyHlsLiveOptions(streamUrl, player);
      debugPrint(
        '[VideoPlayer] open() called with URL: ${_redactedStreamUrl(streamUrl)}',
      );
      if (!mounted || _currentUrl != streamUrl) return;
      await player.open(_mediaForStream(streamUrl), play: true);
      await player.play();
      _hasOpenedUrl = true;
      _retryMessage = null;
      debugPrint('[VideoPlayer] playing url=${_redactedStreamUrl(streamUrl)}');
      _startBlackScreenTimer();
    } catch (error) {
      debugPrint(
        '[VideoPlayer] playback error: $error at ${DateTime.now().toIso8601String()}',
      );
      if (_isNonFatalLiveHlsSeekWarning(error)) {
        debugPrint('[media_kit] ignored non-fatal HLS live seek warning');
        return;
      }
      debugPrint('[media_kit] stream open failed');
      _handlePlaybackFailure(error, source: 'open', streamUrl: streamUrl);
    } finally {
      _isOpening = false;
      if (mounted) setState(() {});
    }
  }

  void _listenToPlayerLogs(Player player) {
    _playerSubscriptions.addAll([
      player.stream.error.listen((error) {
        debugPrint(
          '[VideoPlayer] playback error: $error at ${DateTime.now().toIso8601String()}',
        );
        if (_isNonFatalLiveHlsSeekWarning(error)) {
          debugPrint('[media_kit] ignored non-fatal HLS live seek warning');
          return;
        }
        debugPrint('[media_kit] stream playback error');
        _handlePlaybackFailure(error, source: 'playback');
      }),
      player.stream.playing.listen((playing) {
        debugPrint('[VideoPlayer] playing=$playing');
      }),
      player.stream.buffering.listen((buffering) {
        debugPrint('[VideoPlayer] buffering=$buffering');
      }),
      player.stream.completed.listen((completed) {
        debugPrint('[VideoPlayer] completed=$completed');
      }),
      player.stream.width.listen((width) {
        if (width != null && width > 0) _markFrameRendered();
        developer.log('video width: $width', name: 'CameraLivePreview');
      }),
      player.stream.height.listen((height) {
        if (height != null && height > 0) _markFrameRendered();
        developer.log('video height: $height', name: 'CameraLivePreview');
      }),
    ]);
  }

  Future<void> _applyHlsLiveOptions(String streamUrl, Player player) async {
    if (!_isHlsStream(streamUrl)) return;
    final options = <String, String>{
      'force-seekable': 'yes',
      'cache': 'no',
      'live-caching': '800',
    };
    for (final option in options.entries) {
      try {
        await (player.platform as dynamic).setProperty(
          option.key,
          option.value,
        );
      } catch (error) {
        debugPrint('[media_kit] ${option.key} option failed: $error');
      }
    }
  }

  Media _mediaForStream(String streamUrl) {
    if (!_isHlsStream(streamUrl)) return Media(streamUrl);
    return Media(streamUrl, extras: const {'force-seekable': 'yes'});
  }

  bool _isHlsStream(String streamUrl) {
    final uri = Uri.tryParse(streamUrl);
    if (uri == null) return false;
    return uri.path.toLowerCase().contains('.m3u8');
  }

  bool _isNonFatalLiveHlsSeekWarning(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('cannot seek') ||
        message.contains('force-seekable');
  }

  void _startBlackScreenTimer() {
    _blackScreenTimer?.cancel();
    _blackScreenTimer = Timer(const Duration(seconds: 8), () {
      final player = _player;
      if (!mounted || _hasRenderedFrame) return;
      if ((player?.state.width ?? 0) > 0 || (player?.state.height ?? 0) > 0) {
        _markFrameRendered();
        return;
      }
      if (_errorMessage == _streamOpenFailedMessage) return;
      _handlePlaybackFailure(_streamOpenFailedMessage, source: 'black_screen');
    });
  }

  void _markFrameRendered() {
    _blackScreenTimer?.cancel();
    if (_hasRenderedFrame &&
        _playbackRetryAttempt == 0 &&
        _retryMessage == null &&
        !_reportedPlaybackFailure) {
      return;
    }
    _hasRenderedFrame = true;
    _playbackRetryAttempt = 0;
    _reportedPlaybackFailure = false;
    _retryMessage = null;
    widget.onFirstFrameRendered?.call();
    debugPrint('[VideoPlayer] first frame rendered');
    if (mounted) setState(() {});
  }

  void _handlePlaybackFailure(
    Object error, {
    required String source,
    String? streamUrl,
  }) {
    final activeUrl = streamUrl ?? _currentUrl;
    if (activeUrl == null || activeUrl.isEmpty || activeUrl != _currentUrl) {
      return;
    }

    if (_playbackRetryAttempt < _retryDelays.length) {
      final attempt = _playbackRetryAttempt + 1;
      final delay = _retryDelays[_playbackRetryAttempt];
      _playbackRetryAttempt = attempt;
      _playbackRetryTimer?.cancel();
      debugPrint(
        '[VideoPlayer] $source failed, retry $attempt/${_retryDelays.length} '
        'in ${delay.inSeconds}s: $error',
      );
      if (mounted) {
        setState(() {
          _isOpening = false;
          _errorMessage = null;
          _retryMessage =
              'Đang thử phát lại ($attempt/${_retryDelays.length})...';
        });
      }
      _playbackRetryTimer = Timer(delay, () {
        if (!mounted || _currentUrl != activeUrl) return;
        unawaited(_openMedia(activeUrl));
      });
      return;
    }

    _reportPlaybackFailure('$source: $error');
  }

  void _reportPlaybackFailure(String error) {
    _playbackRetryTimer?.cancel();
    if (!_reportedPlaybackFailure) {
      _reportedPlaybackFailure = true;
      developer.log(
        'Stream playback failed after retries.',
        name: 'CameraLivePreview',
        error: error,
      );
      widget.onPlaybackError?.call(error);
    }
    if (!mounted || _errorMessage == _streamOpenFailedMessage) return;
    setState(() {
      _isOpening = false;
      _retryMessage = null;
      _errorMessage = _streamOpenFailedMessage;
    });
  }

  Future<void> _disposePlayer({required bool captureFrame}) async {
    final subscriptions = List<StreamSubscription<Object?>>.of(
      _playerSubscriptions,
    );
    _playerSubscriptions.clear();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    _blackScreenTimer?.cancel();
    _surfaceOpenTimer?.cancel();
    _playbackRetryTimer?.cancel();
    final player = _player;
    final videoController = _videoController;
    _player = null;
    _videoController = null;
    if (player == null) return;
    if (captureFrame) await _captureLastFrame(player);
    try {
      debugPrint('[VideoPlayer] player.stop() called');
      await player.stop();
      debugPrint('[VideoPlayer] player.dispose() called');
      await player.dispose();
    } catch (_) {}
    try {
      debugPrint('[VideoPlayer] controller.dispose() called');
      (videoController as dynamic).dispose();
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
    final externalErrorMessage = _externalErrorMessage;
    if (externalErrorMessage != null &&
        externalErrorMessage.trim().isNotEmpty) {
      return _VideoErrorView(
        message: externalErrorMessage,
        onRetry: _retryStream,
      );
    }
    if (_errorMessage != null) {
      return _VideoErrorView(message: _errorMessage!, onRetry: _retryStream);
    }
    final videoController = _videoController;
    if (videoController == null) {
      if (!widget.showLoadingOverlay) return const SizedBox.expand();
      return CameraLoadingOverlay(
        phase: widget.loadingPhase,
        placeholderImage: widget.placeholderImage,
      );
    }
    debugPrint(
      '[VideoPlayer] Video widget built, wid will be assigned by platform',
    );
    _scheduleOpenAfterSurfaceReady();
    final showLoadingOverlay = widget.showLoadingOverlay && !_hasRenderedFrame;
    return Stack(
      fit: StackFit.expand,
      children: [
        media_kit_video.Video(
          controller: videoController,
          fit: BoxFit.cover,
          controls: media_kit_video.NoVideoControls,
        ),
        if (_retryMessage != null)
          _RetryOverlay(message: _retryMessage!)
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: showLoadingOverlay
                ? CameraLoadingOverlay(
                    key: const ValueKey('video-loading'),
                    phase: widget.loadingPhase,
                    placeholderImage: widget.placeholderImage,
                  )
                : const SizedBox.shrink(key: ValueKey('video-ready')),
          ),
      ],
    );
  }

  Future<void> _retryStream() async {
    final currentUrl = _currentUrl;
    _playbackRetryTimer?.cancel();
    _playbackRetryAttempt = 0;
    _reportedPlaybackFailure = false;
    _retryMessage = null;
    _hasOpenedUrl = false;
    _hasRenderedFrame = false;
    if (mounted && _errorMessage != null) {
      setState(() {
        _errorMessage = null;
        _isOpening = false;
      });
    }
    if (currentUrl != null && currentUrl.isNotEmpty) {
      updateUrl(currentUrl);
    }
    widget.onRetry?.call();
  }
}

String _redactedStreamUrl(String? url) {
  final uri = Uri.tryParse(url ?? '');
  if (uri == null || uri.host.isEmpty) return 'unavailable';
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port${uri.path}';
}

class CameraLoadingOverlay extends StatefulWidget {
  const CameraLoadingOverlay({
    super.key,
    required this.phase,
    this.placeholderImage,
  });

  final CameraStreamLoadingPhase phase;
  final Uint8List? placeholderImage;

  @override
  State<CameraLoadingOverlay> createState() => _CameraLoadingOverlayState();
}

class _CameraLoadingOverlayState extends State<CameraLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Color.lerp(AppColors.darkText, AppColors.primary, 0.18)!;
    final accentColor = Color.lerp(
      AppColors.darkText,
      AppColors.primaryLight,
      0.34,
    )!;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.placeholderImage != null)
          Image.memory(widget.placeholderImage!, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, accentColor, AppColors.darkText],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final shimmerOffset = (_controller.value * 2) - 1;
            return FractionalTranslation(
              translation: Offset(shimmerOffset, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.surface.withValues(alpha: 0),
                      AppColors.surface.withValues(alpha: 0.07),
                      AppColors.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pulse = Curves.easeInOut.transform(
                      _controller.value < 0.5
                          ? _controller.value * 2
                          : (1 - _controller.value) * 2,
                    );
                    return Transform.scale(
                      scale: 0.94 + pulse * 0.08,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface.withValues(alpha: 0.11),
                          border: Border.all(
                            color: AppColors.surface.withValues(alpha: 0.22),
                          ),
                        ),
                        child: SizedBox.square(
                          dimension: 58,
                          child: Icon(
                            Icons.videocam_rounded,
                            color: AppColors.surface.withValues(alpha: 0.92),
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.phase.label,
                    key: ValueKey(widget.phase),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 112,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.surface.withValues(
                        alpha: 0.16,
                      ),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RetryOverlay extends StatelessWidget {
  const _RetryOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
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

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.safe,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _VideoLabel extends StatelessWidget {
  const _VideoLabel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class _FullscreenCameraPage extends StatefulWidget {
  const _FullscreenCameraPage({
    required this.player,
    required this.videoController,
    required this.isMuted,
    required this.onMuteToggle,
  });

  final Player player;
  final media_kit_video.VideoController videoController;
  final bool isMuted;
  final VoidCallback onMuteToggle;

  @override
  State<_FullscreenCameraPage> createState() => _FullscreenCameraPageState();
}

class _FullscreenCameraPageState extends State<_FullscreenCameraPage> {
  bool _showControls = false;
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
              child: media_kit_video.Video(
                controller: widget.videoController,
                controls: media_kit_video.NoVideoControls,
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
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          const _OverlayPill(
                            color: Colors.white24,
                            children: [
                              _StatusDot(),
                              SizedBox(width: 5),
                              Text(
                                'TRỰC TIẾP',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
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
                                  ? Icons.volume_off_outlined
                                  : Icons.volume_up_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() => _isMuted = !_isMuted);
                              widget.onMuteToggle();
                            },
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.fullscreen_exit,
                              color: Colors.white,
                            ),
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
