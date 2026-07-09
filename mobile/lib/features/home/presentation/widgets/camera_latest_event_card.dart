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
    final appearance = _eventAppearance(latestEvent.type);
    final levelAppearance = _eventLevelAppearance(latestEvent.level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleIcon(
            icon: appearance.icon,
            backgroundColor: appearance.backgroundColor,
            iconColor: appearance.iconColor,
            size: 42,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SỰ KIỆN GẦN NHẤT',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        latestEvent.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (levelAppearance.badge != null) ...[
                      const SizedBox(width: 8),
                      levelAppearance.badge!,
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _buildMetadata(latestEvent, device.location),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildMetadata(CameraEvent event, String fallbackRoom) {
    final parts = <String>[
      event.time,
      event.room.isNotEmpty ? event.room : fallbackRoom,
      if (event.durationSec != null && event.durationSec! > 0)
        '${event.durationSec}s',
      if (event.confidence != null)
        '${(event.confidence! * 100).toStringAsFixed(0)}% tin cậy',
    ];
    return parts.join(' · ');
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
      iconColor: AppColors.safe,
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
