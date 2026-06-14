// lib/features/home/presentation/widgets/camera_event_tile.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/camera_event.dart';

class CameraEventTile extends StatelessWidget {
  const CameraEventTile({super.key, required this.event});

  final CameraEvent event;

  @override
  Widget build(BuildContext context) {
    final appearance = _eventAppearance(event.type);
    final levelAppearance = _eventLevelAppearance(event.level);

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
            icon: appearance.icon,
            backgroundColor: appearance.backgroundColor,
            iconColor: appearance.iconColor,
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
                        color: levelAppearance.timeColor,
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
                    ?levelAppearance.badge,
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

({Color backgroundColor, Color iconColor, IconData icon}) _eventAppearance(
  EventType type,
) {
  return switch (type) {
    EventType.fall => (
      backgroundColor: const Color(0xFFFFE5E5),
      iconColor: const Color(0xFFE53935),
      icon: Icons.accessibility_new,
    ),
    EventType.still => (
      backgroundColor: const Color(0xFFFFF3E0),
      iconColor: const Color(0xFFFF9800),
      icon: Icons.airline_seat_flat,
    ),
    EventType.normal => (
      backgroundColor: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF4CAF50),
      icon: Icons.directions_run,
    ),
    EventType.reconnect => (
      backgroundColor: const Color(0xFFF5F5F5),
      iconColor: AppColors.mutedText,
      icon: Icons.videocam_off_outlined,
    ),
  };
}

({Color timeColor, _LevelBadge? badge}) _eventLevelAppearance(
  EventLevel level,
) {
  return switch (level) {
    EventLevel.high => (
      timeColor: const Color(0xFFE53935),
      badge: const _LevelBadge(label: 'Mức cao', color: Color(0xFFE53935)),
    ),
    EventLevel.medium => (
      timeColor: const Color(0xFFFF9800),
      badge: const _LevelBadge(
        label: 'Mức trung bình',
        color: Color(0xFFFF9800),
      ),
    ),
    _ => (timeColor: AppColors.darkText, badge: null),
  };
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
