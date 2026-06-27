import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/automation/presentation/widgets/automation_rule_tile.dart';

class AutomationRulesSection extends StatelessWidget {
  const AutomationRulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
          const AutomationRuleTile(
            title: 'Phát hiện té ngã',
            subtitle:
                'Gửi thông báo khi AI phát hiện người thân có thể bị ngã.',
            icon: Iconsax.warning_2,
            isTop: true,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isDark ? theme.colorScheme.outline : AppColors.background,
          ),
          const AutomationRuleTile(
            title: 'Tự động gọi khi không phản hồi',
            subtitle:
                'Nếu cảnh báo mức cao không được xác nhận sau 2 phút, hệ thống sẽ gọi liên hệ tiếp theo.',
            icon: Iconsax.call,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isDark ? theme.colorScheme.outline : AppColors.background,
          ),
          const AutomationRuleTile(
            title: 'Camera mất kết nối',
            subtitle:
                'Báo khi camera không gửi tín hiệu hoạt động trong vài phút.',
            icon: Iconsax.video_slash,
            isBottom: true,
          ),
        ],
      ),
    );
  }
}
