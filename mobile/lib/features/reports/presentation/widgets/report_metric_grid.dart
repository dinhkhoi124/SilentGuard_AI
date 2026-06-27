import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/features/reports/presentation/widgets/report_metric_tile.dart';
import 'package:mobile/features/reports/presentation/widgets/report_section_header.dart';

class ReportMetricGrid extends StatelessWidget {
  const ReportMetricGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReportSectionHeader(title: 'Chỉ số nhanh'),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: ReportMetricTile(
                value: '4',
                label: 'Đã xử lý',
                icon: Iconsax.task_square,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ReportMetricTile(
                value: '1',
                label: 'Báo động giả',
                icon: Iconsax.info_circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: ReportMetricTile(
                value: '2/2',
                label: 'Camera online',
                icon: Iconsax.video,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ReportMetricTile(
                value: '100%',
                label: 'Tỷ lệ phản hồi',
                icon: Iconsax.shield_tick,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
