import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import '../../domain/entities/rtmp_stream.dart';

// Hiển thị thông tin kỹ thuật của luồng dưới dạng danh sách mở rộng (ExpansionTile).
class RtmpInfoPanel extends StatelessWidget {
  const RtmpInfoPanel({super.key, required this.stream});

  final RtmpStream stream;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: const Text(
          'Thông tin luồng',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
            letterSpacing: 1.5,
          ),
        ),
        iconColor: AppColors.mutedText,
        collapsedIconColor: AppColors.mutedText,
        children: [
          const _InfoRow(label: 'Giao thức', value: 'RTMP'),
          const _InfoRow(label: 'Chế độ', value: 'Low Latency'),
          _InfoRow(label: 'Chất lượng', value: stream.isHd ? 'HD' : 'SD'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              stream.url,
              style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

// Hàng hiển thị chi tiết (nhãn bên trái, giá trị bên phải).
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
