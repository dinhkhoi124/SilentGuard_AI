import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/reports/presentation/widgets/ai_daily_summary_card.dart';
import 'package:mobile/features/reports/presentation/widgets/recent_events_section.dart';
import 'package:mobile/features/reports/presentation/widgets/report_metric_grid.dart';
import 'package:mobile/features/reports/presentation/widgets/report_summary_card.dart';
import 'package:mobile/features/reports/presentation/widgets/reports_header.dart';
import 'package:mobile/features/reports/presentation/widgets/safety_trend_chart.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  void _showComingSoonSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            sliver: SliverList.list(
              children: [
                ReportsHeader(
                  onFilterTap: () => _showComingSoonSnackBar(
                    context,
                    'Bộ lọc thời gian sẽ được kết nối sau.',
                  ),
                ),
                const SizedBox(height: 24),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Expanded(
                        child: ReportSummaryCard(
                          title: 'Hôm nay',
                          mainValue: '0',
                          unitLabel: 'cảnh báo khẩn cấp',
                          subtitle: '2 sự kiện đã ghi nhận',
                          icon: Iconsax.shield_tick,
                          accentColor: AppColors.safe,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ReportSummaryCard(
                          title: 'Phản hồi',
                          mainValue: '42s',
                          unitLabel: 'trung bình',
                          subtitle: 'Nhanh hơn 18s so với hôm qua',
                          icon: Iconsax.timer_1,
                          accentColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SafetyTrendChart(
                  onFilterTap: () => _showComingSoonSnackBar(
                    context,
                    'Bộ lọc thời gian sẽ được kết nối sau.',
                  ),
                ),
                const SizedBox(height: 32),
                const AiDailySummaryCard(),
                const SizedBox(height: 32),
                const ReportMetricGrid(),
                const SizedBox(height: 32),
                RecentEventsSection(
                  onEventTap: () => _showComingSoonSnackBar(
                    context,
                    'Chi tiết sự kiện sẽ được kết nối sau.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
