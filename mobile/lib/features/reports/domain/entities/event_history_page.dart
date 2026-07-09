import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

class EventHistoryPage {
  const EventHistoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<EventHistoryItem> items;
  final int total;
  final int page;
  final int pageSize;
}
