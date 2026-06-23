import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/reports/presentation/widgets/recent_event_tile.dart';
import 'package:mobile/features/reports/presentation/widgets/report_section_header.dart';

class RecentEventsSection extends StatelessWidget {
  const RecentEventsSection({super.key, required this.onEventTap});

  final VoidCallback onEventTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReportSectionHeader(title: 'Sự kiện gần đây'),
        const SizedBox(height: 12),
        Container(
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
            children: [
              RecentEventTile(
                time: '14:32',
                title: 'Cảnh báo tại phòng khách',
                subtitle: 'Mức trung bình · Đã xác nhận',
                statusBadge: 'Đã xử lý',
                icon: Iconsax.warning_2,
                onTap: onEventTap,
              ),
              Divider(
                height: 1,
                indent: 80,
                color: isDark
                    ? theme.colorScheme.outline
                    : AppColors.background,
              ),
              RecentEventTile(
                time: '09:18',
                title: 'Camera phòng ngủ hoạt động lại',
                subtitle: 'Hệ thống · Camera online',
                statusBadge: 'Ổn định',
                icon: Iconsax.video,
                onTap: onEventTap,
              ),
              Divider(
                height: 1,
                indent: 80,
                color: isDark
                    ? theme.colorScheme.outline
                    : AppColors.background,
              ),
              RecentEventTile(
                time: '02:15',
                title: 'Cảnh báo tại phòng ngủ',
                subtitle: 'Mức cao · Phản hồi sau 42 giây',
                statusBadge: 'Đã xử lý',
                icon: Iconsax.danger,
                onTap: onEventTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
