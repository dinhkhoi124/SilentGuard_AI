import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class ReportSectionHeader extends StatelessWidget {
  const ReportSectionHeader({
    super.key,
    required this.title,
    this.actionWidget,
  });

  final String title;
  final Widget? actionWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? theme.colorScheme.onSurface : AppColors.darkText,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ?actionWidget,
      ],
    );
  }
}
