import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class SeverityTimeline extends StatelessWidget {
  const SeverityTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
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
          _SeverityStep(
            level: 'Thấp',
            description: 'Chỉ ghi nhận, không làm phiền.',
            color: isDark
                ? theme.colorScheme.onSurfaceVariant
                : AppColors.mutedText,
            isLast: false,
          ),
          const _SeverityStep(
            level: 'Trung bình',
            description: 'Gửi thông báo đến người chăm sóc chính.',
            color: AppColors.primary,
            isLast: false,
          ),
          const _SeverityStep(
            level: 'Cao',
            description: 'Gửi thông báo và chuẩn bị gọi nếu không có phản hồi.',
            color: AppColors.warning,
            isLast: false,
          ),
          const _SeverityStep(
            level: 'Khẩn cấp',
            description: 'Thông báo toàn bộ liên hệ khẩn cấp.',
            color: AppColors.destructive,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SeverityStep extends StatelessWidget {
  const _SeverityStep({
    required this.level,
    required this.description,
    required this.color,
    required this.isLast,
  });

  final String level;
  final String description;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.surface
                          : AppColors.surface,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark
                          ? theme.colorScheme.outline
                          : AppColors.background,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : AppColors.mutedText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
