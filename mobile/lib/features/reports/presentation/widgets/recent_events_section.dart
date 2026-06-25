import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_cubit.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_state.dart';
import 'package:mobile/features/reports/presentation/mappers/event_history_display_mapper.dart';
import 'package:mobile/core/widgets/app_empty_state.dart';
import 'package:mobile/features/reports/presentation/widgets/recent_event_tile.dart';
import 'package:mobile/features/reports/presentation/widgets/report_section_header.dart';

class RecentEventsSection extends StatelessWidget {
  const RecentEventsSection({super.key, required this.onEventTap});

  final void Function(EventHistoryItem item) onEventTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReportSectionHeader(title: 'Sự kiện gần đây'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(color: theme.colorScheme.outline)
                : null,
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
          child: BlocBuilder<EventHistoryCubit, EventHistoryState>(
            builder: (context, state) {
              return switch (state) {
                EventHistoryInitial() => _LoadingBody(isDark: isDark),
                EventHistoryLoading() => _LoadingBody(isDark: isDark),
                EventHistoryLoaded(:final items, :final isRefreshing) =>
                  _LoadedBody(
                    items: items,
                    isRefreshing: isRefreshing,
                    isDark: isDark,
                    onEventTap: onEventTap,
                  ),
                EventHistoryEmpty() => _EmptyBody(isDark: isDark),
                EventHistoryError(:final message) => _ErrorBody(
                  message: message,
                  isDark: isDark,
                  onRetry: () =>
                      context.read<EventHistoryCubit>().loadInitial(),
                ),
              };
            },
          ),
        ),
      ],
    );
  }
}

// ─── private sub-widgets ──────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Đang tải lịch sử sự kiện...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.history_outlined,
      title: 'Chưa có sự kiện gần đây',
      message:
          'Khi hệ thống ghi nhận cảnh báo, các sự kiện mới nhất sẽ xuất hiện tại đây.',
      compact: true,
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.isDark,
    required this.onRetry,
  });

  final String message;
  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Text(
            'Không thể tải lịch sử sự kiện. Vui lòng thử lại.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.items,
    required this.isRefreshing,
    required this.isDark,
    required this.onEventTap,
  });

  final List<EventHistoryItem> items;
  final bool isRefreshing;
  final bool isDark;
  final void Function(EventHistoryItem item) onEventTap;

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark
        ? Theme.of(context).colorScheme.outline
        : AppColors.background;

    return Column(
      children: [
        if (isRefreshing)
          LinearProgressIndicator(
            minHeight: 2,
            color: isDark
                ? Theme.of(context).colorScheme.primary
                : AppColors.primary,
            backgroundColor: Colors.transparent,
          ),
        for (var i = 0; i < items.length; i++) ...[
          RecentEventTile(
            time: EventHistoryDisplayMapper.timeLabel(items[i]),
            title: EventHistoryDisplayMapper.title(items[i]),
            subtitle: EventHistoryDisplayMapper.subtitle(items[i]),
            statusBadge: EventHistoryDisplayMapper.statusBadge(items[i]),
            icon: EventHistoryDisplayMapper.icon(items[i]),
            onTap: () => onEventTap(items[i]),
          ),
          if (i < items.length - 1)
            Divider(height: 1, indent: 120, endIndent: 20, color: dividerColor),
        ],
      ],
    );
  }
}
