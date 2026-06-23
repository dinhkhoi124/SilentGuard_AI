import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/automation/presentation/widgets/automation_status_chip.dart';

class AutomationHeader extends StatelessWidget {
  const AutomationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Thiết lập cách SilentGuard phản ứng khi phát hiện sự cố.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const AutomationStatusBadge(),
      ],
    );
  }
}
