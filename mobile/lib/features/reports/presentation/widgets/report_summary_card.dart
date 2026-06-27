import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({
    super.key,
    required this.title,
    required this.mainValue,
    required this.unitLabel,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String mainValue;
  final String unitLabel;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                mainValue,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : AppColors.darkText,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  unitLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
