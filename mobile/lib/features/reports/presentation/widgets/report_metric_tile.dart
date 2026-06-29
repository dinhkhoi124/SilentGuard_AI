import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class ReportMetricTile extends StatelessWidget {
  const ReportMetricTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : AppColors.darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                icon,
                color: isDark ? theme.colorScheme.primary : AppColors.primary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
