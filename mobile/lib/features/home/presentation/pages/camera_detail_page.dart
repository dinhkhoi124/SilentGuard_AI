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

  @override
  void dispose() {
    _clockTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
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
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 18),
              const Text(
                'Tùy chọn camera',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.device.location,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          child: SizedBox.square(
                            dimension: 42,
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Giả lập cảnh báo té ngã',
                                style: TextStyle(
                                  color: AppColors.darkText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Gửi thông báo sau 5 giây.',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.mutedText,
                        ),
                      ],
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const SizedBox(width: 40, height: 5),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}
