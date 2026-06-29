import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class AiConfigCard extends StatelessWidget {
  const AiConfigCard({super.key, required this.onTryAiConfig});

  final VoidCallback onTryAiConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Nếu là dark mode thì dùng màu surface của theme, ngược lại dùng màu trắng
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline
              : AppColors.primary.withValues(alpha: 0.01),
        ),
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
                  'Nhờ AI gợi ý quy tắc',
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
            'Ví dụ: "Ba tôi hay ngủ trưa dưới sàn từ 1 giờ đến 3 giờ chiều, đừng báo động mạnh trong thời gian đó."',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTryAiConfig,
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? theme.colorScheme.primary
                    : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Thử sau',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
