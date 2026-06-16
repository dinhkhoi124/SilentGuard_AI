// lib/features/home/presentation/widgets/camera_card.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';

class CameraCard extends StatelessWidget {
  const CameraCard({
    super.key,
    required this.device,
    required this.onDelete,
    required this.onToggleAccessory,
  });

  final CameraDevice device;
  final ValueChanged<String> onDelete;
  final void Function(String deviceId, int accessoryIndex) onToggleAccessory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/camera/${device.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: const Color(0xFFE8E8EE)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Colors.black),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 3 icon bên trái
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: device.isArmed
                                        ? const Color(0xFF4CAF50)
                                        : AppColors.mutedText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.wifi,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.directions_walk,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ],
                            ),

                            // 2 icon bên phải
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.battery_5_bar,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        '1/2',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),

                                _buildThreeDotMenu(context),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                device.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: device.isArmed
                                      ? const Color(0xFF4CAF50)
                                      : AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: device.isArmed
                                ? const Color(0xFFF5F5F5)
                                : AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            device.isArmed
                                ? Icons.videocam_off_outlined
                                : Icons.videocam_outlined,
                            size: 16,
                            color: device.isArmed
                                ? AppColors.mutedText
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreeDotMenu(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Cài đặt thiết bị',
                style: TextStyle(fontSize: 14, color: AppColors.darkText),
              ),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Color(0xFFE53935)),
              SizedBox(width: 10),
              Text(
                'Xóa thiết bị',
                style: TextStyle(fontSize: 14, color: Color(0xFFE53935)),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'delete') {
          _showDeleteConfirmDialog(context);
        } else if (value == 'settings') {
          _showSettingsBottomSheet(context);
        }
      },
      child: Icon(Icons.more_vert, size: 16, color: Colors.white),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa thiết bị',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Bạn có chắc muốn xóa "${device.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              onDelete(device.id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.white,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cài đặt: ${device.name}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vị trí: ${device.location}',
              style: const TextStyle(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tính năng sắp ra mắt...',
              style: TextStyle(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
