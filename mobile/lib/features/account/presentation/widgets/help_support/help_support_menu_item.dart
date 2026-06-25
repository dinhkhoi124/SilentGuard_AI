import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class HelpSupportMenuItem extends StatelessWidget {
  const HelpSupportMenuItem({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    final chevronColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: chevronColor, size: 26),
          ],
        ),
      ),
    );
  }
}
