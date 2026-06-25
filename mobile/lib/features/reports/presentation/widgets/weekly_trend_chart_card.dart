import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/reports/presentation/widgets/animated_weekly_bar_chart.dart';
import 'package:mobile/features/reports/presentation/widgets/report_section_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_cubit.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_state.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';
import 'package:mobile/features/reports/presentation/widgets/weekly_event_trend_aggregator.dart';

class _WeeklyMetric {
  const _WeeklyMetric({
    required this.label,
    required this.values,
    required this.insight,
    required this.selectedDayMessage,
  });

  final String label;
  final List<int> values;
  final String insight;
  final String Function(int dayIndex, int value) selectedDayMessage;
}

String _getDayName(int index) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][index];

String _formatDuration(int seconds) {
  if (seconds < 60) return '$seconds giây';
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (remainingSeconds == 0) return '$minutes phút';
  return '$minutes phút $remainingSeconds giây';
}

String _formatAlertMessage(int dayIndex, int value) {
  if (value == 0) return 'Không có cảnh báo trong ngày này.';
  return '${_getDayName(dayIndex)} có $value cảnh báo được ghi nhận.';
}

String _formatHighSeverityMessage(int dayIndex, int value) {
  if (value == 0) return 'Không có cảnh báo mức cao trong ngày này.';
  return '${_getDayName(dayIndex)} có $value cảnh báo mức cao cần chú ý.';
}

String _formatHandledMessage(int dayIndex, int value) {
  if (value == 0) return 'Chưa có cảnh báo nào được xử lý trong ngày này.';
  return '${_getDayName(dayIndex)} có $value cảnh báo đã được xử lý.';
}

String _formatImmobilityMessage(int dayIndex, int value) {
  if (value == 0) return 'Không có dữ liệu bất động trong ngày này.';
  return '${_getDayName(dayIndex)} ghi nhận bất động lâu nhất ${_formatDuration(value)}.';
}

class WeeklyTrendChartCard extends StatefulWidget {
  const WeeklyTrendChartCard({super.key});

  @override
  State<WeeklyTrendChartCard> createState() => _WeeklyTrendChartCardState();
}

class _WeeklyTrendChartCardState extends State<WeeklyTrendChartCard> {
  int _selectedMetricIndex = 0;
  int _selectedDayIndex = DateTime.now().weekday - 1;
  String _selectedWeekScope = 'Tuần này';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _triggerDateFilter(_selectedWeekScope);
    });
  }

  void _triggerDateFilter(String scope) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    if (scope == 'Tuần này') {
      final daysSinceMonday = now.weekday - 1;
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysSinceMonday));
      end = now;
    } else if (scope == 'Tuần trước') {
      final daysSinceMonday = now.weekday - 1;
      final lastMonday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysSinceMonday + 7));
      start = lastMonday;
      end = lastMonday.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );
    } else {
      // 7 ngày gần nhất
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      end = now;
    }

    context.read<EventHistoryCubit>().filterByDate(
      start.toIso8601String(),
      end.toIso8601String(),
    );
  }

  void _onMetricChanged(int index, List<_WeeklyMetric> currentMetrics) {
    if (_selectedMetricIndex == index) return;
    setState(() {
      _selectedMetricIndex = index;
      final values = currentMetrics[index].values;
      int maxVal = -1;
      int maxIdx = DateTime.now().weekday - 1;
      for (int i = 0; i < values.length; i++) {
        if (values[i] > maxVal) {
          maxVal = values[i];
          maxIdx = i;
        }
      }
      _selectedDayIndex = maxIdx;
    });
  }

  void _onDaySelected(int index) {
    setState(() => _selectedDayIndex = index);
  }

  void _onWeekScopeChanged(String scope) {
    setState(() => _selectedWeekScope = scope);
    _triggerDateFilter(scope);
  }

  void _showWeekScopeSelector(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              )
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Chọn khoảng thời gian',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : AppColors.darkText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildScopeOption(
                    context: context,
                    title: 'Tuần này',
                    subtitle: 'Dữ liệu từ thứ 2 đến hôm nay',
                    theme: theme,
                    isDark: isDark,
                  ),
                  _buildScopeOption(
                    context: context,
                    title: 'Tuần trước',
                    subtitle: 'So sánh với tuần liền trước',
                    theme: theme,
                    isDark: isDark,
                  ),
                  _buildScopeOption(
                    context: context,
                    title: '7 ngày gần nhất',
                    subtitle: 'Tính từ hôm nay lùi lại 7 ngày',
                    theme: theme,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScopeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isSelected = _selectedWeekScope == title;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        _onWeekScopeChanged(title);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? (isDark
                                ? theme.colorScheme.primary
                                : AppColors.primary)
                          : (isDark
                                ? theme.colorScheme.onSurface
                                : AppColors.darkText),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: isDark ? theme.colorScheme.primary : AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  List<_WeeklyMetric> _buildMetrics(List<EventHistoryItem> items) {
    final aggregator = WeeklyEventTrendAggregator(items: items);

    return [
      _WeeklyMetric(
        label: 'Cảnh báo',
        values: aggregator.alerts.values,
        insight: aggregator.alerts.insight,
        selectedDayMessage: _formatAlertMessage,
      ),
      _WeeklyMetric(
        label: 'Mức cao',
        values: aggregator.highSeverity.values,
        insight: aggregator.highSeverity.insight,
        selectedDayMessage: _formatHighSeverityMessage,
      ),
      _WeeklyMetric(
        label: 'Đã xử lý',
        values: aggregator.handled.values,
        insight: aggregator.handled.insight,
        selectedDayMessage: _formatHandledMessage,
      ),
      _WeeklyMetric(
        label: 'Bất động',
        values: aggregator.immobility.values,
        insight: aggregator.immobility.insight,
        selectedDayMessage: _formatImmobilityMessage,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<EventHistoryCubit, EventHistoryState>(
      builder: (context, state) {
        final List<EventHistoryItem> items = state is EventHistoryLoaded
            ? state.items
            : const [];

        final metrics = _buildMetrics(items);
        final metric = metrics[_selectedMetricIndex];
        final maxValue = metric.values.reduce(max);
        final selectedDayValue = metric.values[_selectedDayIndex];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportSectionHeader(
              title: 'Xu hướng 7 ngày',
              actionWidget: GestureDetector(
                onTap: () => _showWeekScopeSelector(context, isDark, theme),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : AppColors.background,
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.outline
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedWeekScope,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : AppColors.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: isDark
                            ? theme.colorScheme.onSurfaceVariant
                            : AppColors.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: List.generate(metrics.length, (index) {
                  final isSelected = _selectedMetricIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () => _onMetricChanged(index, metrics),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : Colors.transparent),
                          border: isSelected || isDark
                              ? null
                              : Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: theme.textTheme.labelLarge!.copyWith(
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? theme.colorScheme.onSurfaceVariant
                                      : AppColors.mutedText),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          child: Text(metrics[index].label),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: isDark
                    ? Border.all(color: theme.colorScheme.outline)
                    : Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.shadow.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedWeeklyBarChart(
                    values: metric.values,
                    maxValue: maxValue,
                    selectedIndex: _selectedDayIndex,
                    onDaySelected: _onDaySelected,
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey<String>(
                        '$_selectedMetricIndex-$_selectedDayIndex',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        metric.selectedDayMessage(
                          _selectedDayIndex,
                          selectedDayValue,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : AppColors.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      metric.insight,
                      key: ValueKey<String>(metric.insight),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? theme.colorScheme.onSurfaceVariant
                            : AppColors.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
