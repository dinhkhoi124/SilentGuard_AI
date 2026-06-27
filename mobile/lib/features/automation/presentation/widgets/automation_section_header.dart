import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class AutomationSectionHeader extends StatelessWidget {
  const AutomationSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: isDark ? theme.colorScheme.onSurface : AppColors.darkText,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}
