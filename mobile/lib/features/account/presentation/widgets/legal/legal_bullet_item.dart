import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class LegalBulletItem extends StatelessWidget {
  const LegalBulletItem({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    final bulletColor = isDark ? theme.colorScheme.primary : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: bulletColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: _buildRichText(context, text, textColor)),
        ],
      ),
    );
  }

  Widget _buildRichText(BuildContext context, String text, Color textColor) {
    // Basic bold parsing: **bold text**
    final parts = text.split('**');
    final spans = <InlineSpan>[];
    final theme = Theme.of(context);

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 != 0; // Odd indices are bold if text contains **

      spans.add(
        TextSpan(
          text: parts[i],
          style: theme.textTheme.bodyLarge?.copyWith(
            color: textColor,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}
