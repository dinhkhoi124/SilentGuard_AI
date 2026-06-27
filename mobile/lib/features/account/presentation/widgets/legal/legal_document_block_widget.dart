import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/account/data/privacy_policy_markdown_parser.dart';
import 'package:mobile/features/account/presentation/widgets/legal/legal_bullet_item.dart';
import 'package:mobile/features/account/presentation/widgets/legal/legal_table_card.dart';

class LegalDocumentBlockWidget extends StatelessWidget {
  const LegalDocumentBlockWidget({super.key, required this.block});

  final LegalDocumentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    final primaryColor = isDark ? theme.colorScheme.primary : AppColors.primary;

    switch (block.type) {
      case LegalDocumentBlockType.metadata:
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Text(
            block.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

      case LegalDocumentBlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          child: Text(
            block.text,
            style: theme.textTheme.titleLarge?.copyWith(
              color: primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        );

      case LegalDocumentBlockType.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Text(
            block.text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

      case LegalDocumentBlockType.paragraph:
      case LegalDocumentBlockType.contact:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildRichText(context, block.text, textColor),
        );

      case LegalDocumentBlockType.bullet:
        return LegalBulletItem(text: block.text);

      case LegalDocumentBlockType.table:
        return LegalTableCard(rows: block.tableRows);
    }
  }

  Widget _buildRichText(BuildContext context, String text, Color textColor) {
    final theme = Theme.of(context);
    final parts = text.split('**');
    final spans = <InlineSpan>[];

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 != 0;

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
