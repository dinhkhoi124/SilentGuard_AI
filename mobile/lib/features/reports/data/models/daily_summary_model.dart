import 'package:mobile/features/reports/data/models/event_history_model.dart';
import 'package:mobile/features/reports/domain/entities/daily_summary.dart';

class DailySummaryModel {
  const DailySummaryModel({
    required this.date,
    required this.summary,
    required this.events,
  });

  final DateTime date;
  final String? summary;
  final List<EventHistoryItemModel> events;

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    final events = rawEvents is List
        ? rawEvents
              .whereType<Map<String, dynamic>>()
              .map(EventHistoryItemModel.fromJson)
              .toList(growable: false)
        : const <EventHistoryItemModel>[];

    return DailySummaryModel(
      date: _parseDate(json['date']),
      summary: json['summary'] as String?,
      events: events,
    );
  }

  static DateTime _parseDate(Object? rawDate) {
    if (rawDate is String && rawDate.isNotEmpty) {
      return DateTime.parse(rawDate);
    }
    return DateTime.now();
  }

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;

  DailySummary toEntity() {
    return DailySummary(
      date: date,
      summary: summary?.trim() ?? '',
      events: events.map((event) => event.toEntity()).toList(growable: false),
    );
  }
}
