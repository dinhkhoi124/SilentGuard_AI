import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class FaqSearchField extends StatelessWidget {
  const FaqSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fillColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;
    final textColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    final hintColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        onChanged: onChanged,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm',
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: hintColor,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Iconsax.search_normal, color: hintColor, size: 20),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
