// lib/features/home/presentation/widgets/camera_latest_event_card.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/entities/camera_event.dart';

class CameraLatestEventCard extends StatelessWidget {
  const CameraLatestEventCard({
    super.key,
    required this.device,
    required this.latestEvent,
  });

  final CameraDevice device;
  final CameraEvent latestEvent;

  @override
  Widget build(BuildContext context) {
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
                  device.location,
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
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
    child: Icon(icon, color: iconColor, size: size / 2),
  );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: ColoredBox(
      color: const Color(0xFFBDBDBD),
      child: SizedBox(width: width, height: height),
    ),
  );
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
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
