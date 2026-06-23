import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class ReportsHeader extends StatelessWidget {
  const ReportsHeader({super.key, required this.onFilterTap});

  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Theo dõi tình hình an toàn và phản hồi của gia đình.',
            style: TextStyle(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: onFilterTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '7 ngày',
              style: TextStyle(
                color: isDark
                    ? theme.colorScheme.onSurface
                    : AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
