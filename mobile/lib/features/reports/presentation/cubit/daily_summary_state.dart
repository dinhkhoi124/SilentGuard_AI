import 'package:mobile/features/reports/domain/entities/daily_summary.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

sealed class DailySummaryState {
  const DailySummaryState();
}

final class DailySummaryInitial extends DailySummaryState {
  const DailySummaryInitial();
}

final class DailySummaryLoading extends DailySummaryState {
  const DailySummaryLoading(this.date);

  final DateTime date;
}

final class DailySummaryLoaded extends DailySummaryState {
  const DailySummaryLoaded(this.summary);

  final DailySummary summary;
}

final class DailySummaryPendingGeneration extends DailySummaryState {
  const DailySummaryPendingGeneration({
    required this.todayEvents,
    required this.date,
  });

  final List<EventHistoryItem> todayEvents;
  final DateTime date;
}

final class DailySummaryEmpty extends DailySummaryState {
  const DailySummaryEmpty(this.date);

  final DateTime date;
}

final class DailySummaryError extends DailySummaryState {
  const DailySummaryError({required this.message, required this.date});

  final String message;
  final DateTime date;
}
