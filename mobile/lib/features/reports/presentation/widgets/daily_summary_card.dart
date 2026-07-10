import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/core/widgets/app_empty_state.dart';
import 'package:mobile/features/reports/domain/entities/daily_summary.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';
import 'package:mobile/features/reports/presentation/cubit/daily_summary_cubit.dart';
import 'package:mobile/features/reports/presentation/cubit/daily_summary_state.dart';
import 'package:mobile/features/reports/presentation/mappers/event_history_display_mapper.dart';
import 'package:mobile/features/reports/presentation/widgets/recent_event_tile.dart';

class DailySummaryCard extends StatefulWidget {
  const DailySummaryCard({super.key});

  @override
  State<DailySummaryCard> createState() => _DailySummaryCardState();
}

class _DailySummaryCardState extends State<DailySummaryCard> {
  static const _minimumVisibleLoadingDuration = Duration(milliseconds: 700);

  DailySummaryState? _displayState;
  DailySummaryState? _pendingDisplayState;
  DailySummary? _cachedSummary;
  DateTime? _cachedSummaryDate;
  DateTime? _loadingVisibleAt;
  Timer? _minimumLoadingTimer;
  bool _isRefreshingCachedSummary = false;

  @override
  void dispose() {
    _minimumLoadingTimer?.cancel();
    super.dispose();
  }

  void _handleStateChange(DailySummaryState state) {
    switch (state) {
      case DailySummaryInitial():
        _showLoadingOrCachedSummary(DateTime.now());
      case DailySummaryLoading(:final date):
        _showLoadingOrCachedSummary(date);
      case DailySummaryLoaded(:final summary):
        _cachedSummary = summary;
        _cachedSummaryDate = _dateOnly(summary.date);
        _showStateRespectingMinimumLoading(state);
      case DailySummaryPendingGeneration():
      case DailySummaryEmpty():
      case DailySummaryError():
        _showStateRespectingMinimumLoading(state);
    }
  }

  void _showLoadingOrCachedSummary(DateTime date) {
    _minimumLoadingTimer?.cancel();
    _pendingDisplayState = null;
    _loadingVisibleAt = null;

    if (_hasCachedSummaryFor(date)) {
      setState(() {
        _isRefreshingCachedSummary = true;
        _displayState = DailySummaryLoaded(_cachedSummary!);
      });
      return;
    }

    setState(() {
      _isRefreshingCachedSummary = false;
      _displayState = DailySummaryLoading(date);
    });
  }

  void _showStateRespectingMinimumLoading(DailySummaryState state) {
    final visibleAt = _loadingVisibleAt;
    _isRefreshingCachedSummary = false;

    if (visibleAt == null) {
      _minimumLoadingTimer?.cancel();
      _pendingDisplayState = null;
      setState(() => _displayState = state);
      return;
    }

    final elapsed = DateTime.now().difference(visibleAt);
    final remaining = _minimumVisibleLoadingDuration - elapsed;
    if (remaining <= Duration.zero) {
      _minimumLoadingTimer?.cancel();
      _pendingDisplayState = null;
      _loadingVisibleAt = null;
      setState(() => _displayState = state);
      return;
    }

    _pendingDisplayState = state;
    _minimumLoadingTimer?.cancel();
    _minimumLoadingTimer = Timer(remaining, () {
      if (!mounted || _pendingDisplayState == null) return;
      setState(() {
        _displayState = _pendingDisplayState;
        _pendingDisplayState = null;
        _loadingVisibleAt = null;
      });
    });
  }

  bool _hasCachedSummaryFor(DateTime date) {
    final cachedDate = _cachedSummaryDate;
    return _cachedSummary != null &&
        cachedDate != null &&
        cachedDate == _dateOnly(date);
  }

  void _onLoadingBecameVisible() {
    _loadingVisibleAt ??= DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: theme.colorScheme.outline) : null,
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
      child: BlocConsumer<DailySummaryCubit, DailySummaryState>(
        listener: (context, state) => _handleStateChange(state),
        builder: (context, state) {
          final displayState = _displayState ?? state;
          if (displayState case DailySummaryLoaded(:final summary)) {
            _cachedSummary = summary;
            _cachedSummaryDate = _dateOnly(summary.date);
          }
          final date = switch (displayState) {
            DailySummaryInitial() => DateTime.now(),
            DailySummaryLoading(:final date) => date,
            DailySummaryLoaded(:final summary) => summary.date,
            DailySummaryPendingGeneration(:final date) => date,
            DailySummaryEmpty(:final date) => date,
            DailySummaryError(:final date) => date,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(date: date),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  reverseDuration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.025),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: switch (displayState) {
                    DailySummaryInitial() => DelayedLoadingSwitcher(
                      key: const ValueKey('daily-summary-loading'),
                      onLoadingVisible: _onLoadingBecameVisible,
                    ),
                    DailySummaryLoading() => DelayedLoadingSwitcher(
                      key: const ValueKey('daily-summary-loading'),
                      onLoadingVisible: _onLoadingBecameVisible,
                    ),
                    DailySummaryLoaded(:final summary) => AiSummaryCard(
                      key: ValueKey('daily-summary-loaded-${summary.summary}'),
                      summary: summary,
                      isRefreshing: _isRefreshingCachedSummary,
                    ),
                    DailySummaryPendingGeneration(:final todayEvents) =>
                      _PendingBody(
                        key: const ValueKey('daily-summary-pending'),
                        events: todayEvents,
                      ),
                    DailySummaryEmpty(:final date) => _EmptyBody(
                      key: const ValueKey('daily-summary-empty'),
                      date: date,
                    ),
                    DailySummaryError() => _ErrorBody(
                      key: const ValueKey('daily-summary-error'),
                      onRetry: () => context
                          .read<DailySummaryCubit>()
                          .dailySummaryRetryRequested(),
                    ),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isToday = _isSameDay(date, DateTime.now());
    final title = isToday
        ? 'Báo cáo AI hôm nay'
        : 'Báo cáo AI ngày ${DateFormat('dd/MM', 'vi').format(date)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Iconsax.magic_star,
                    size: 20,
                    color: isDark
                        ? theme.colorScheme.primary
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : AppColors.darkText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurfaceVariant
                      : AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _DateSelectorButton(date: date),
      ],
    );
  }
}

class _DateSelectorButton extends StatelessWidget {
  const _DateSelectorButton({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDateSelector(context, date),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.calendar_1,
              size: 16,
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppColors.mutedText,
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('dd/MM', 'vi').format(date),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDark
                    ? theme.colorScheme.onSurface
                    : AppColors.darkText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateSelector(BuildContext context, DateTime selectedDate) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final dates = List<DateTime>.generate(
          7,
          (index) => _dateOnly(DateTime.now().subtract(Duration(days: index))),
        );

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
                      'Chọn ngày báo cáo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : AppColors.darkText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final date in dates)
                    _DateOption(
                      date: date,
                      isSelected: _isSameDay(date, selectedDate),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context
                            .read<DailySummaryCubit>()
                            .dailySummaryDateChanged(date);
                      },
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
}

class _DateOption extends StatelessWidget {
  const _DateOption({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isToday = _isSameDay(date, DateTime.now());
    final subtitle = isToday
        ? 'Báo cáo AI sẽ sẵn sàng sau 23:00'
        : DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);

    return InkWell(
      onTap: onTap,
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
                    isToday ? 'Hôm nay' : DateFormat('dd/MM').format(date),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurface
                          : AppColors.darkText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
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
                Iconsax.tick_circle,
                size: 20,
                color: isDark ? theme.colorScheme.primary : AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

enum _LoadingPhase { hidden, compact, full, longWait }

class DelayedLoadingSwitcher extends StatefulWidget {
  const DelayedLoadingSwitcher({super.key, required this.onLoadingVisible});

  final VoidCallback onLoadingVisible;

  @override
  State<DelayedLoadingSwitcher> createState() => _DelayedLoadingSwitcherState();
}

class _DelayedLoadingSwitcherState extends State<DelayedLoadingSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Timer> _timers = <Timer>[];
  _LoadingPhase _phase = _LoadingPhase.hidden;
  bool _hasNotifiedVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _timers
      ..add(
        Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          _notifyLoadingVisible();
          setState(() => _phase = _LoadingPhase.compact);
        }),
      )
      ..add(
        Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _phase = _LoadingPhase.full);
        }),
      )
      ..add(
        Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _phase = _LoadingPhase.longWait);
        }),
      );
  }

  void _notifyLoadingVisible() {
    if (_hasNotifiedVisible) return;
    _hasNotifiedVisible = true;
    widget.onLoadingVisible();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = _phase != _LoadingPhase.hidden;

    return AnimatedSize(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: isVisible
            ? AiSummaryLoadingCard(
                key: const ValueKey('summary-loading-card'),
                animation: _controller,
                isExpanded:
                    _phase == _LoadingPhase.full ||
                    _phase == _LoadingPhase.longWait,
                isLongWait: _phase == _LoadingPhase.longWait,
              )
            : const SizedBox.shrink(key: ValueKey('summary-loading-hidden')),
      ),
    );
  }
}

class AiSummaryLoadingCard extends StatelessWidget {
  const AiSummaryLoadingCard({
    super.key,
    required this.animation,
    required this.isExpanded,
    required this.isLongWait,
  });

  final Animation<double> animation;
  final bool isExpanded;
  final bool isLongWait;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtleSurface = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32)
        : AppColors.background;
    final title = isLongWait
        ? 'AI vẫn đang tạo tóm tắt...'
        : 'AI đang tạo tóm tắt...';
    final subtitle = isLongWait
        ? 'Quá trình này có thể lâu hơn bình thường do nội dung cảnh báo hoặc kết nối mạng.'
        : 'Đang phân tích nội dung cảnh báo để tạo bản tóm tắt ngắn gọn.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(isExpanded ? 18 : 14),
      decoration: BoxDecoration(
        color: subtleSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.42)
              : AppColors.border.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProcessingMark(animation: animation),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Text(
                        title,
                        key: ValueKey('summary-loading-title-$isLongWait'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : AppColors.darkText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: isExpanded
                            ? Padding(
                                key: ValueKey(
                                  'summary-loading-subtitle-$isLongWait',
                                ),
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? theme.colorScheme.onSurfaceVariant
                                        : AppColors.mutedText,
                                    height: 1.35,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('summary-loading-no-subtitle'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isExpanded
                  ? Padding(
                      key: const ValueKey('summary-loading-skeleton'),
                      padding: const EdgeInsets.only(top: 18),
                      child: SummarySkeletonShimmer(animation: animation),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('summary-loading-no-skeleton'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingMark extends StatelessWidget {
  const _ProcessingMark({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? theme.colorScheme.primary : AppColors.primary;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse =
            0.78 + (0.22 * Curves.easeInOut.transform(animation.value));
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(Iconsax.shield_search, color: accent, size: 19),
          ),
        );
      },
    );
  }
}

class SummarySkeletonShimmer extends StatelessWidget {
  const SummarySkeletonShimmer({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : AppColors.surface;
    final highlightColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.92);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: isDark ? 0.34 : 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.28)
              : AppColors.border.withValues(alpha: 0.58),
        ),
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final shimmerPosition = (animation.value * 2) - 1;
              return LinearGradient(
                begin: Alignment(-1 + shimmerPosition, 0),
                end: Alignment(1 + shimmerPosition, 0),
                colors: [
                  baseColor.withValues(alpha: 0.52),
                  highlightColor,
                  baseColor.withValues(alpha: 0.52),
                ],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(widthFactor: 0.68, height: 11),
            SizedBox(height: 10),
            _SkeletonLine(widthFactor: 0.94, height: 9),
            SizedBox(height: 8),
            _SkeletonLine(widthFactor: 0.82, height: 9),
            SizedBox(height: 8),
            _SkeletonLine(widthFactor: 0.46, height: 9),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
              : AppColors.border.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class AiSummaryCard extends StatefulWidget {
  const AiSummaryCard({
    super.key,
    required this.summary,
    this.isRefreshing = false,
  });

  final DailySummary summary;
  final bool isRefreshing;

  @override
  State<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends State<AiSummaryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: widget.isRefreshing
              ? Align(
                  key: const ValueKey('summary-refreshing-indicator'),
                  alignment: Alignment.centerRight,
                  child: _RefreshingBadge(isDark: isDark),
                )
              : const SizedBox.shrink(
                  key: ValueKey('summary-no-refreshing-indicator'),
                ),
        ),
        if (widget.isRefreshing) const SizedBox(height: 8),
        Text(
          widget.summary.summary,
          maxLines: _isExpanded ? null : 5,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? theme.colorScheme.onSurfaceVariant
                : AppColors.mutedText,
            height: 1.45,
          ),
        ),
        if (widget.summary.summary.length > 180) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: isDark
                  ? theme.colorScheme.primary
                  : AppColors.primary,
            ),
            child: Text(_isExpanded ? 'Thu gọn' : 'Xem thêm'),
          ),
        ],
      ],
    );
  }
}

class _RefreshingBadge extends StatelessWidget {
  const _RefreshingBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;
    final background = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.48)
        : AppColors.background;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.refresh, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            'Đang cập nhật...',
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBody extends StatelessWidget {
  const _PendingBody({super.key, required this.events});

  final List<EventHistoryItem> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark
        ? theme.colorScheme.outline
        : AppColors.background;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Báo cáo tổng hợp AI cho hôm nay sẽ sẵn sàng sau 23:00. Dưới đây là các sự kiện đã ghi nhận trong ngày.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? theme.colorScheme.onSurfaceVariant
                : AppColors.mutedText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  )
                : AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < events.length; i++) ...[
                RecentEventTile(
                  time: EventHistoryDisplayMapper.timeLabel(events[i]),
                  title: EventHistoryDisplayMapper.title(events[i]),
                  subtitle: EventHistoryDisplayMapper.subtitle(events[i]),
                  statusBadge: EventHistoryDisplayMapper.statusBadge(events[i]),
                  icon: EventHistoryDisplayMapper.icon(events[i]),
                  onTap: () {},
                ),
                if (i < events.length - 1)
                  Divider(
                    height: 1,
                    indent: 80,
                    endIndent: 20,
                    color: dividerColor,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Iconsax.document_text,
      title: 'Chưa có đủ dữ liệu để tạo tóm tắt',
      message:
          'Khi có thêm cảnh báo trong ngày, AI sẽ tạo bản tóm tắt tại đây.',
      compact: true,
      animate: false,
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Không thể tạo tóm tắt lúc này',
      message: 'Vui lòng thử lại sau hoặc kiểm tra kết nối mạng.',
      primaryActionLabel: 'Thử lại',
      onPrimaryAction: onRetry,
      compact: true,
      animate: false,
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);
