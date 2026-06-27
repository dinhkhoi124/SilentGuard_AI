import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class QuietWindowCard extends StatelessWidget {
  const QuietWindowCard({super.key, required this.onAddQuietWindow});

  final VoidCallback onAddQuietWindow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: theme.colorScheme.outline) : null,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.moon,
                    color: isDark
                        ? theme.colorScheme.primary
                        : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giờ nghỉ trưa',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : AppColors.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '13:00 - 15:00',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isDark
                              ? theme.colorScheme.primary
                              : AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Giảm cảnh báo không cần thiết nếu người thân thường nghỉ ngơi trong khung giờ này.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onSurfaceVariant
                              : AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onAddQuietWindow,
                icon: const Icon(Iconsax.add, size: 18),
                label: const Text('Thêm khung giờ'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? theme.colorScheme.primary
                      : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
