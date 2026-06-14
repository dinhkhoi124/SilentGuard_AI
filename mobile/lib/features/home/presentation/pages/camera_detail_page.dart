// lib/features/home/presentation/pages/camera_detail_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/data/mock_events.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/entities/camera_event.dart';
import 'package:video_player/video_player.dart';

class CameraDetailPage extends StatefulWidget {
  const CameraDetailPage({super.key, required this.device});

  final CameraDevice device;

  @override
  State<CameraDetailPage> createState() => _CameraDetailPageState();
}

class _CameraDetailPageState extends State<CameraDetailPage> {
  VideoPlayerController? _videoController;
  Timer? _clockTimer;
  String _currentTime = '';
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTime(),
    );
    _initVideo();
  }

  void _updateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/sample_camera.mp4',
    );
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
            SliverToBoxAdapter(child: _buildTopBar()),
            SliverToBoxAdapter(child: _buildVideoPlayer()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: _buildSafetyStatus()),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(child: _buildLatestEventCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(child: _buildActionButtons()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildEventHistoryHeader()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => _buildEventTile(mockCameraEvents[index]),
                childCount: mockCameraEvents.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _SquareButton(icon: Icons.arrow_back_ios_new, onTap: context.pop),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.location,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'Camera 1  ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.device.isArmed
                            ? const Color(0xFF4CAF50)
                            : AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.device.isArmed ? 'Trực tuyến' : 'Ngoại tuyến',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.device.isArmed
                            ? const Color(0xFF4CAF50)
                            : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SquareButton(icon: Icons.settings_outlined, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_videoReady && _videoController != null)
                VideoPlayer(_videoController!)
              else
                const ColoredBox(color: Colors.black),
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
                          'LIVE',
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
                    _currentTime,
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

  Widget _buildSafetyStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const _CircleIcon(
            icon: Icons.verified_user,
            backgroundColor: Color(0xFFEEEBFD),
            iconColor: AppColors.primary,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trạng thái an toàn',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Hiện tại không có sự cố',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cập nhật lúc ${TimeOfDay.now().format(context)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const Icon(
                Icons.house_outlined,
                size: 52,
                color: Color.fromARGB(255, 200, 206, 248),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLatestEventCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const _CircleIcon(
            icon: Icons.accessibility_new,
            backgroundColor: Color(0xFFFFE5E5),
            iconColor: Color(0xFFE53935),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sự kiện gần nhất',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Nghi ngờ té ngã',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    _LevelBadge(label: 'Mức cao', color: Color(0xFFE53935)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '09:35 AM  •  20 giây trước',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedText),
                ),
                Text(
                  widget.device.location,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            children: [
              _Thumbnail(width: 64, height: 48),
              SizedBox(height: 4),
              Icon(Icons.chevron_right, color: AppColors.mutedText, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return _SectionCard(
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(icon: Icons.phone, label: 'Gọi cho người\nthân'),
          _ActionButton(icon: Icons.textsms, label: 'Nhắn tin'),
          _ActionButton(
            icon: Icons.people,
            label: 'Người nhận\ncảnh báo',
            badge: '3',
          ),
          _ActionButton(icon: Icons.pause_circle, label: 'Tạm dừng\ngiám sát'),
        ],
      ),
    );
  }

  Widget _buildEventHistoryHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Lịch sử sự kiện',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          Row(
            children: [
              Icon(Icons.filter_list, size: 16, color: AppColors.mutedText),
              SizedBox(width: 4),
              Text(
                'Tất cả sự kiện',
                style: TextStyle(fontSize: 13, color: AppColors.mutedText),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(CameraEvent event) {
    final (iconBackground, iconColor, icon) = switch (event.type) {
      EventType.fall => (
        const Color(0xFFFFE5E5),
        const Color(0xFFE53935),
        Icons.accessibility_new,
      ),
      EventType.still => (
        const Color(0xFFFFF3E0),
        const Color(0xFFFF9800),
        Icons.airline_seat_flat,
      ),
      EventType.normal => (
        const Color(0xFFE8F5E9),
        const Color(0xFF4CAF50),
        Icons.directions_run,
      ),
      EventType.reconnect => (
        const Color(0xFFF5F5F5),
        AppColors.mutedText,
        Icons.videocam_off_outlined,
      ),
    };
    final timeColor = switch (event.level) {
      EventLevel.high => const Color(0xFFE53935),
      EventLevel.medium => const Color(0xFFFF9800),
      _ => AppColors.darkText,
    };
    final badge = switch (event.level) {
      EventLevel.high => const _LevelBadge(
        label: 'Mức cao',
        color: Color(0xFFE53935),
      ),
      EventLevel.medium => const _LevelBadge(
        label: 'Mức trung bình',
        color: Color(0xFFFF9800),
      ),
      _ => null,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _CircleIcon(
            icon: icon,
            backgroundColor: iconBackground,
            iconColor: iconColor,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      event.time,
                      style: TextStyle(
                        fontSize: 12,
                        color: timeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    ?badge,
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          if (event.type != EventType.reconnect) ...[
            const SizedBox(width: 10),
            const _Thumbnail(width: 56, height: 42),
          ],
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedText),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.darkText),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16), child: child);
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.size,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: size / 2),
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
        color: Color(0xFF4CAF50),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFFBDBDBD),
        child: SizedBox(width: width, height: height),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              height: 95,
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tất cả icon có cùng kích thước và cùng vị trí
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: Icon(
                        icon,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),

                  const SizedBox(height: 7),

                  // Tất cả label bắt đầu tại cùng một vị trí
                  SizedBox(
                    height: 30,
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (badge != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}