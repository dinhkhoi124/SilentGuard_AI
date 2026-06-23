import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/reports/presentation/widgets/report_section_header.dart';

class SafetyTrendChart extends StatelessWidget {
  const SafetyTrendChart({super.key, required this.onFilterTap});

  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportSectionHeader(
          title: 'Xu hướng 7 ngày',
          actionWidget: InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Tuần này',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : AppColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(color: theme.colorScheme.outline)
                : null,
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
              SizedBox(
                height: 180,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const _ChartBar(day: 'T2', value: 0, maxValue: 2),
                    const _ChartBar(day: 'T3', value: 1, maxValue: 2),
                    const _ChartBar(day: 'T4', value: 0, maxValue: 2),
                    const _ChartBar(
                      day: 'T5',
                      value: 2,
                      maxValue: 2,
                      isHighlighted: true,
                    ),
                    const _ChartBar(day: 'T6', value: 0, maxValue: 2),
                    const _ChartBar(day: 'T7', value: 1, maxValue: 2),
                    const _ChartBar(day: 'CN', value: 0, maxValue: 2),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Không có cảnh báo khẩn cấp trong tuần này.',
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
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.day,
    required this.value,
    required this.maxValue,
    this.isHighlighted = false,
  });

  final String day;
  final int value;
  final int maxValue;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final barColor = isHighlighted
        ? AppColors.primary
        : (isDark
              ? theme.colorScheme.surfaceContainerHighest
              : AppColors.lightBlue);

    // Calculate relative height fraction
    final double fraction = value == 0 ? 0.05 : (value / maxValue);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isHighlighted)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$value cảnh báo',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction,
              child: Container(
                width: 32,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark
                ? theme.colorScheme.onSurfaceVariant
                : AppColors.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
