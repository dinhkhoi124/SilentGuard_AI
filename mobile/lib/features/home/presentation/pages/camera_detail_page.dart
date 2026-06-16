// lib/features/home/presentation/pages/camera_detail_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/data/mock_events.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/presentation/widgets/camera_action_buttons.dart';
import 'package:mobile/features/home/presentation/widgets/camera_event_history_header.dart';
import 'package:mobile/features/home/presentation/widgets/camera_event_tile.dart';
import 'package:mobile/features/home/presentation/widgets/camera_latest_event_card.dart';
import 'package:mobile/features/home/presentation/widgets/camera_safety_status.dart';
import 'package:mobile/features/home/presentation/widgets/camera_top_bar.dart';
import 'package:mobile/features/home/presentation/widgets/camera_video_player.dart';
import 'package:mobile/injection_container.dart';
import 'package:video_player/video_player.dart';

class CameraDetailPage extends StatefulWidget {
  const CameraDetailPage({super.key, required this.device});

  final CameraDevice device;

  @override
  State<CameraDetailPage> createState() => _CameraDetailPageState();
}

class _CameraDetailPageState extends State<CameraDetailPage> {
  static const _videoAssetPath = 'assets/videos/videoplayback.mp4';

  VideoPlayerController? _videoController;
  Timer? _clockTimer;
  String _currentTime = '';
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initVideo();
    });
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() => _currentTime = _formatTime(DateTime.now()));
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(_videoAssetPath);
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      await controller.dispose();
      _videoController = null;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CameraTopBar(
                device: widget.device,
                onBack: () => context.go('/home'),
                onSettings: _showCameraOptions,
              ),
            ),
            SliverToBoxAdapter(
              child: CameraVideoPlayer(
                videoReady: _videoReady,
                controller: _videoController,
                currentTime: _currentTime,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: CameraSafetyStatus(
                device: widget.device,
                updateTime: TimeOfDay.now().format(context),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: CameraLatestEventCard(
                device: widget.device,
                latestEvent: mockCameraEvents.first,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            const SliverToBoxAdapter(child: CameraActionButtons()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: CameraEventHistoryHeader()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => CameraEventTile(event: mockCameraEvents[index]),
                childCount: mockCameraEvents.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Future<void> _showCameraOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final scheduled = await sl<LocalNotificationService>()
                    .scheduleFallAlert(widget.device);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      scheduled
                          ? 'Thông báo giả lập sẽ xuất hiện sau 5 giây.'
                          : 'Cần cấp quyền thông báo để giả lập cảnh báo.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Giả lập cảnh báo té ngã'),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}
