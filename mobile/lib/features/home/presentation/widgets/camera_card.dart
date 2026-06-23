// lib/features/home/presentation/widgets/camera_card.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/presentation/pages/camera_detail_page.dart';

class CameraCard extends StatelessWidget {
  const CameraCard({
    super.key,
    required this.device,
    required this.thumbnailBytes,
    required this.onDelete,
    required this.onToggleAccessory,
    required this.onThumbnailCaptured,
  });

  final CameraDevice device;
  final Uint8List? thumbnailBytes;
  final ValueChanged<String> onDelete;
  final void Function(String deviceId, int accessoryIndex) onToggleAccessory;
  final ValueChanged<Uint8List> onThumbnailCaptured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? theme.colorScheme.surface : AppColors.surface;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : AppColors.darkText;
    final mutedColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;
    final actionBackground = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : device.isArmed
        ? AppColors.surfaceSoft
        : AppColors.lightBlue;
    return GestureDetector(
      onTap: () => context.push(
        '/camera/${device.id}',
        extra: CameraDetailArgs(
          device: device,
          onThumbnailCaptured: onThumbnailCaptured,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: thumbnailBytes != null
                          ? ClipRRect(
                              key: ValueKey('thumb-${device.id}'),
                              borderRadius: BorderRadius.circular(18),
                              child: Image.memory(
                                thumbnailBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : _buildEmptyThumbnailPlaceholder(context),
                    ),
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: device.isArmed
                                        ? AppColors.safe
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
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
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                device.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: device.isArmed
                                      ? AppColors.safe
                                      : mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: actionBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            device.isArmed
                                ? Icons.videocam_off_outlined
                                : Icons.videocam_outlined,
                            size: 16,
                            color: device.isArmed
                                ? mutedColor
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

  Widget _buildEmptyThumbnailPlaceholder(BuildContext context) {
    return Container(
      key: const ValueKey('thumb-empty'),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_outlined, size: 32, color: Colors.white),
          SizedBox(height: 4),
          Text(
            'SlientGuard',
            style: TextStyle(
              fontFamily: 'Syne Mono',
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeDotMenu(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 206),
      offset: const Offset(0, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: AppColors.shadow,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'settings',
          height: 48,
          child: Row(
            children: [
              _MenuIcon(
                icon: Icons.settings_outlined,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text(
                'Cài đặt thiết bị',
                style: TextStyle(fontSize: 14, color: AppColors.darkText),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 48,
          child: Row(
            children: [
              _MenuIcon(
                icon: Icons.delete_outline,
                color: AppColors.destructive,
              ),
              SizedBox(width: 10),
              Text(
                'Xóa thiết bị',
                style: TextStyle(fontSize: 14, color: AppColors.destructive),
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
      child: const Icon(Icons.more_vert, size: 16, color: Colors.white),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DialogIcon(
                icon: Icons.delete_outline,
                color: AppColors.destructive,
              ),
              const SizedBox(height: 18),
              const Text(
                'Xóa thiết bị',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn có chắc muốn xóa "${device.name}" không?',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.destructive,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        onDelete(device.id);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Xóa'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 18),
              const Text(
                'Cài đặt thiết bị',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                device.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vị trí: ${device.location}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              const _InfoPanel(
                icon: Icons.tune_rounded,
                title: 'Tùy chỉnh đang được chuẩn bị',
                message: 'Các lựa chọn cấu hình camera sẽ sẵn sàng sau.',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox.square(
        dimension: 30,
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

class _DialogIcon extends StatelessWidget {
  const _DialogIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(icon, color: color, size: 24),
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

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MenuIcon(icon: icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 13,
                      height: 1.4,
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
