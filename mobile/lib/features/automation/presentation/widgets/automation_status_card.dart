import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';

class AutomationStatusCard extends StatelessWidget {
  const AutomationStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: theme.colorScheme.outline) : null,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.shield_tick5,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bảo vệ tự động đang bật',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurface
                        : AppColors.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'AI sẽ theo dõi camera đã kết nối và gửi cảnh báo khi phát hiện dấu hiệu té ngã hoặc bất thường.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              int cameraCount = 0;
              if (state is HomeLoaded) {
                cameraCount = state.devices.length;
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaChip(icon: Iconsax.video, label: '$cameraCount camera'),
                  const _MetaChip(
                    icon: Iconsax.notification_status,
                    label: 'FCM sẵn sàng',
                  ),
                  const _MetaChip(icon: Iconsax.flash, label: 'Cập nhật tức thời'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark
                ? theme.colorScheme.onSurfaceVariant
                : AppColors.mutedText,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
