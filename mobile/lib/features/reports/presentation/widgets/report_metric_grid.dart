import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/features/reports/presentation/widgets/report_metric_tile.dart';
import 'package:mobile/features/reports/presentation/widgets/report_section_header.dart';

class ReportMetricGrid extends StatelessWidget {
  const ReportMetricGrid({
    super.key,
    required this.processedEvents,
    required this.falseAlarms,
    required this.cameraOnline,
    required this.responseRate,
  });

  final String processedEvents;
  final String falseAlarms;
  final String cameraOnline;
  final String responseRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReportSectionHeader(title: 'Chỉ số nhanh'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportMetricTile(
                value: processedEvents,
                label: 'Đã xử lý',
                icon: Iconsax.task_square,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ReportMetricTile(
                value: falseAlarms,
                label: 'Báo động giả',
                icon: Iconsax.info_circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportMetricTile(
                value: cameraOnline,
                label: 'Camera online',
                icon: Iconsax.video,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ReportMetricTile(
                value: responseRate,
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
