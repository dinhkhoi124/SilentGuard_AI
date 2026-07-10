import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';
import 'package:mobile/features/reports/presentation/cubit/daily_summary_cubit.dart';
import 'package:mobile/features/reports/presentation/cubit/daily_summary_state.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_cubit.dart';
import 'package:mobile/features/reports/presentation/widgets/daily_summary_card.dart';
import 'package:mobile/features/reports/presentation/widgets/recent_events_section.dart';
import 'package:mobile/features/reports/presentation/widgets/report_metric_grid.dart';
import 'package:mobile/features/reports/presentation/widgets/report_summary_card.dart';
import 'package:mobile/features/reports/presentation/widgets/reports_header.dart';
import 'package:mobile/features/reports/presentation/widgets/weekly_trend_chart_card.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_state.dart';
import 'package:mobile/injection_container.dart';

/// Reports tab — top-level composition only.
/// All API calls and data mapping happen below in cubit / datasource / mapper.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final EventHistoryCubit _cubit;
  late final DailySummaryCubit _dailySummaryCubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<EventHistoryCubit>();
    _dailySummaryCubit = sl<DailySummaryCubit>();
    if (widget.isActive) {
      _tryLoad();
    }
  }

  @override
  void didUpdateWidget(ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _tryLoad();
    }
  }

  void _tryLoad() {
    final householdId = sl<SessionRepository>().currentHouseholdId;
    if (householdId != null && householdId.isNotEmpty) {
      final state = _cubit.state;
      if (state is EventHistoryInitial ||
          state is EventHistoryLoading ||
          state is EventHistoryError) {
        _cubit.loadInitial();
      }

      final dailySummaryState = _dailySummaryCubit.state;
      if (dailySummaryState is DailySummaryInitial ||
          dailySummaryState is DailySummaryError) {
        _dailySummaryCubit.loadInitial();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _dailySummaryCubit),
      ],
      child: BlocListener<HomeBloc, HomeState>(
        listenWhen: (previous, current) =>
            current is HomeLoaded && previous is! HomeLoaded,
        listener: (context, state) {
          if (widget.isActive) {
            _tryLoad();
          }
        },
        child: const _ReportsPageBody(),
      ),
    );
  }
}

class _ReportsPageBody extends StatelessWidget {
  const _ReportsPageBody();

  void _showComingSoonSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onEventTap(BuildContext context, EventHistoryItem item) {
    // TODO: Navigate to event detail screen when it exists.
    // Pass item.eventId to the detail route.
    _showComingSoonSnackBar(context, 'Chi tiết sự kiện sẽ được kết nối sau.');
  }

  List<EventHistoryItem> _eventsForDailySummaryState(DailySummaryState state) {
    return switch (state) {
      DailySummaryLoaded(:final summary) => summary.events,
      DailySummaryPendingGeneration(:final todayEvents) => todayEvents,
      _ => const <EventHistoryItem>[],
    };
  }

  List<EventHistoryItem> _eventsForTodayFromHistory(EventHistoryState state) {
    final items = switch (state) {
      EventHistoryLoaded(:final items) => items,
      _ => const <EventHistoryItem>[],
    };

    final today = _dateOnly(DateTime.now());
    return items
        .where((item) {
          final timestamp = item.timestamp;
          return timestamp != null && _dateOnly(timestamp) == today;
        })
        .toList(growable: false);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  _ReportMetrics _buildReportMetrics({
    required List<EventHistoryItem> events,
    required List<CameraDevice> cameras,
  }) {
    final processedCount = events
        .where((event) => event.status != EventStatus.pending)
        .length;
    final falseAlarmCount = events
        .where((event) => event.status == EventStatus.dismissed)
        .length;
    final onlineCameraCount = cameras
        .where((camera) => camera.status.toLowerCase() == 'online')
        .length;
    final responseRate = events.isEmpty
        ? '100%'
        : '${((processedCount / events.length) * 100).round()}%';

    return _ReportMetrics(
      processedEvents: processedCount.toString(),
      falseAlarms: falseAlarmCount.toString(),
      cameraOnline: '$onlineCameraCount/${cameras.length}',
      responseRate: responseRate,
    );
  }

  _DailySummaryStats _buildDailySummaryStats({
    required DailySummaryState dailySummaryState,
    required EventHistoryState eventHistoryState,
  }) {
    final dailyEvents = _eventsForDailySummaryState(dailySummaryState);
    final historyTodayEvents = _eventsForTodayFromHistory(eventHistoryState);
    final events = historyTodayEvents.isNotEmpty
        ? historyTodayEvents
        : dailyEvents;

    if (dailySummaryState is DailySummaryInitial ||
        dailySummaryState is DailySummaryLoading) {
      return const _DailySummaryStats(
        criticalEvents: '--',
        totalEventsSubtitle: 'Đang tải dữ liệu hôm nay...',
        averageDuration: '--',
        averageDurationSubtitle: 'Đang tính thời gian sự cố',
        accentColor: AppColors.primary,
      );
    }

    if (dailySummaryState is DailySummaryError && events.isEmpty) {
      return const _DailySummaryStats(
        criticalEvents: '--',
        totalEventsSubtitle: 'Chưa tải được dữ liệu hôm nay',
        averageDuration: '--',
        averageDurationSubtitle: 'Vui lòng thử lại sau',
        accentColor: AppColors.destructive,
      );
    }

    final criticalEvents = events
        .where(
          (event) =>
              event.severity == EventSeverity.critical ||
              event.severity == EventSeverity.high,
        )
        .length;
    final durations = events
        .map((event) => event.durationSec)
        .whereType<int>()
        .where((duration) => duration > 0)
        .toList(growable: false);
    final averageDuration = durations.isEmpty
        ? '--'
        : '${(durations.reduce((a, b) => a + b) / durations.length).round()}s';

    return _DailySummaryStats(
      criticalEvents: criticalEvents.toString(),
      totalEventsSubtitle: '${events.length} sự kiện đã ghi nhận',
      averageDuration: averageDuration,
      averageDurationSubtitle: durations.isEmpty
          ? 'Chưa có thời lượng sự cố'
          : 'Thời gian diễn ra mỗi sự kiện',
      accentColor: criticalEvents > 0 ? AppColors.destructive : AppColors.safe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              24,
              AppSpacing.pagePadding,
              20,
            ),
            sliver: SliverList.list(
              children: [
                ReportsHeader(
                  onFilterTap: () => _showComingSoonSnackBar(
                    context,
                    'Bộ lọc thời gian sẽ được kết nối sau.',
                  ),
                ),
                const SizedBox(height: 24),
                BlocBuilder<DailySummaryCubit, DailySummaryState>(
                  builder: (context, dailySummaryState) {
                    return BlocBuilder<EventHistoryCubit, EventHistoryState>(
                      builder: (context, eventHistoryState) {
                        final stats = _buildDailySummaryStats(
                          dailySummaryState: dailySummaryState,
                          eventHistoryState: eventHistoryState,
                        );

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ReportSummaryCard(
                                  title: 'Hôm nay',
                                  mainValue: stats.criticalEvents,
                                  unitLabel: 'cảnh báo mức cao',
                                  subtitle: stats.totalEventsSubtitle,
                                  icon: Iconsax.shield_tick,
                                  accentColor: stats.accentColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ReportSummaryCard(
                                  title: 'Độ dài sự cố',
                                  mainValue: stats.averageDuration,
                                  unitLabel: 'trung bình',
                                  subtitle: stats.averageDurationSubtitle,
                                  icon: Iconsax.timer_1,
                                  accentColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
                const DailySummaryCard(),
                const SizedBox(height: 32),
                const WeeklyTrendChartCard(),
                const SizedBox(height: 32),
                BlocBuilder<DailySummaryCubit, DailySummaryState>(
                  builder: (context, dailySummaryState) {
                    return BlocBuilder<HomeBloc, HomeState>(
                      builder: (context, homeState) {
                        final events = _eventsForDailySummaryState(
                          dailySummaryState,
                        );
                        final cameras = homeState is HomeLoaded
                            ? homeState.devices
                            : const <CameraDevice>[];
                        final metrics = _buildReportMetrics(
                          events: events,
                          cameras: cameras,
                        );

                        return ReportMetricGrid(
                          processedEvents: metrics.processedEvents,
                          falseAlarms: metrics.falseAlarms,
                          cameraOnline: metrics.cameraOnline,
                          responseRate: metrics.responseRate,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
                RecentEventsSection(
                  onEventTap: (item) => _onEventTap(context, item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMetrics {
  const _ReportMetrics({
    required this.processedEvents,
    required this.falseAlarms,
    required this.cameraOnline,
    required this.responseRate,
  });

  final String processedEvents;
  final String falseAlarms;
  final String cameraOnline;
  final String responseRate;
}

class _DailySummaryStats {
  const _DailySummaryStats({
    required this.criticalEvents,
    required this.totalEventsSubtitle,
    required this.averageDuration,
    required this.averageDurationSubtitle,
    required this.accentColor,
  });

  final String criticalEvents;
  final String totalEventsSubtitle;
  final String averageDuration;
  final String averageDurationSubtitle;
  final Color accentColor;
}
