// lib/features/home/presentation/widgets/camera_video_player.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:video_player/video_player.dart';

class CameraVideoPlayer extends StatelessWidget {
  const CameraVideoPlayer({
    super.key,
    required this.currentTime,
    this.rtspUrl,
    this.useMockAsset = false,
  });

  final String currentTime;
  final String? rtspUrl;
  final bool useMockAsset;

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
              CameraLivePreview(rtspUrl: rtspUrl, useMockAsset: useMockAsset),
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
  const CameraLivePreview({super.key, this.rtspUrl, this.useMockAsset = false});

  final String? rtspUrl;
  final bool useMockAsset;

  @override
  State<CameraLivePreview> createState() => _CameraLivePreviewState();
}

class _CameraLivePreviewState extends State<CameraLivePreview> {
  static const _videoAssetPath = 'assets/videos/videoplayback.mp4';

  VideoPlayerController? _assetController;
  VlcPlayerController? _vlcController;
  bool _assetReady = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant CameraLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rtspUrl != widget.rtspUrl ||
        oldWidget.useMockAsset != widget.useMockAsset) {
      _disposeControllers();
      _initController();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initController() {
    final rtspUrl = widget.rtspUrl?.trim();
    if (widget.useMockAsset) {
      _initMockAsset();
      return;
    }

    if (rtspUrl == null || rtspUrl.isEmpty) return;
    _vlcController = VlcPlayerController.network(
      rtspUrl,
      autoInitialize: true,
      autoPlay: true,
      hwAcc: HwAcc.auto,
    );
  }

  Future<void> _initMockAsset() async {
    final controller = VideoPlayerController.asset(_videoAssetPath);
    _assetController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted && identical(_assetController, controller)) {
        setState(() => _assetReady = true);
      }
    } catch (_) {
      if (identical(_assetController, controller)) {
        _assetController = null;
      }
      unawaited(controller.dispose());
    }
  }

  void _disposeControllers() {
    final assetController = _assetController;
    final vlcController = _vlcController;
    _assetController = null;
    _vlcController = null;
    _assetReady = false;

    if (assetController != null) unawaited(assetController.dispose());
    if (vlcController != null) unawaited(vlcController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final vlcController = _vlcController;
    final assetController = _assetController;

    if (widget.useMockAsset && _assetReady && assetController != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: assetController.value.size.width,
          height: assetController.value.size.height,
          child: VideoPlayer(assetController),
        ),
      );
    }

    if (!widget.useMockAsset && vlcController != null) {
      return VlcPlayer(
        controller: vlcController,
        aspectRatio: 16 / 9,
        placeholder: const ColoredBox(color: Colors.black),
      );
    }

    return const ColoredBox(color: Colors.black);
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
      color: Color(0xFF4CAF50),
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
