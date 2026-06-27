import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class LegalTableCard extends StatelessWidget {
  const LegalTableCard({super.key, required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Assuming first row is headers, but rendering gracefully even if not
    final headers = rows.first;
    final dataRows = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: dataRows
            .map((row) => _buildRowCard(context, headers, row))
            .toList(),
      ),
    );
  }

  Widget _buildRowCard(
    BuildContext context,
    List<String> headers,
    List<String> row,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.colorScheme.surface : AppColors.surface;
    final borderColor = isDark ? theme.colorScheme.outline : AppColors.border;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : AppColors.darkText;
    final labelColor = isDark ? theme.colorScheme.primary : AppColors.primary;
    final valueColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;

    // Use the first column as the card title, and subsequent columns as attributes
    final title = row.isNotEmpty ? row.first : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (title.isNotEmpty && row.length > 1) const SizedBox(height: 12),
          for (var i = 1; i < row.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (i < headers.length)
                    SizedBox(
                      width: 80,
                      child: Text(
                        headers[i],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      row[i],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
