import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/automation/presentation/widgets/automation_status_chip.dart';

class AutomationRuleTile extends StatelessWidget {
  const AutomationRuleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isTop = false,
    this.isBottom = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isTop;
  final bool isBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: null, // Static UI
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(20) : Radius.zero,
        bottom: isBottom ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )
                    : AppColors.lightBlue.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDark ? theme.colorScheme.primary : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurface
                          : AppColors.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            const SizedBox(width: 12),
            const AutomationStatusChip(label: 'Bật', color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
