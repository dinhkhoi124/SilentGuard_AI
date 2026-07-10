import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

class DailySummary {
  const DailySummary({
    required this.date,
    required this.summary,
    required this.events,
  });

  final DateTime date;
  final String summary;
  final List<EventHistoryItem> events;
}
