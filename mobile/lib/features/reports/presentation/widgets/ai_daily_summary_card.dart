import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/reports/presentation/widgets/report_section_header.dart';

class AiDailySummaryCard extends StatelessWidget {
  const AiDailySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReportSectionHeader(title: 'Tóm tắt bởi AI'),
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
              Row(
                children: [
                  const Icon(
                    Iconsax.magic_star,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tình hình hôm nay ổn định',
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
                'Hệ thống ghi nhận 2 sự kiện mức thấp và trung bình. Không có cảnh báo khẩn cấp. Camera phòng ngủ và phòng khách hoạt động bình thường.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurfaceVariant
                      : AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Iconsax.clock,
                    size: 14,
                    color: isDark
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cập nhật lúc 21:00',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
