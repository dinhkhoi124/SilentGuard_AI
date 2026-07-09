import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class AnimatedWeeklyBarChart extends StatelessWidget {
  const AnimatedWeeklyBarChart({
    super.key,
    required this.values,
    required this.maxValue,
    required this.selectedIndex,
    required this.onDaySelected,
  });

  final List<int> values;
  final int maxValue;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;

  static const List<String> _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final isSelected = index == selectedIndex;
          final val = index < values.length ? values[index] : 0;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(index),
              behavior: HitTestBehavior.opaque,
              child: _AnimatedBar(
                day: _days[index],
                value: val,
                maxValue: maxValue == 0 ? 1 : maxValue,
                isSelected: isSelected,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    required this.day,
    required this.value,
    required this.maxValue,
    required this.isSelected,
  });

  final String day;
  final int value;
  final int maxValue;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final targetHeightFraction = value == 0 ? 0.05 : (value / maxValue);
    final barColor = isSelected
        ? AppColors.primary
        : (isDark
              ? theme.colorScheme.surfaceContainerHighest
              : AppColors.lightBlue);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: targetHeightFraction),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, fraction, child) {
                  return FractionallySizedBox(
                    heightFactor: fraction,
                    child: child,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSelected ? 32 : 24,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected && !isDark
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: theme.textTheme.labelMedium!.copyWith(
            color: isSelected
                ? (isDark ? theme.colorScheme.onSurface : AppColors.darkText)
                : (isDark
                      ? theme.colorScheme.onSurfaceVariant
                      : AppColors.mutedText),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
          child: Text(day),
        ),
      ],
    );
  }
}
