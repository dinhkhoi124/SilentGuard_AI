import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

class WeeklyMetricData {
  const WeeklyMetricData({required this.values, required this.insight});
  final List<int> values;
  final String insight;
}

class WeeklyEventTrendAggregator {
  const WeeklyEventTrendAggregator({required this.items});

  final List<EventHistoryItem> items;

  List<int> _aggregateByCondition(bool Function(EventHistoryItem) predicate) {
    final values = List.filled(7, 0);
    for (final item in items) {
      if (item.timestamp != null && predicate(item)) {
        // item.timestamp!.weekday returns 1 (Monday) to 7 (Sunday)
        final index = item.timestamp!.weekday - 1;
        values[index]++;
      }
    }
    return values;
  }

  WeeklyMetricData get alerts {
    final values = _aggregateByCondition(
      (item) => item.severity != EventSeverity.system,
    );
    final total = values.fold(0, (a, b) => a + b);
    return WeeklyMetricData(
      values: values,
      insight: total == 0
          ? 'Không có cảnh báo nào trong khoảng thời gian này.'
          : 'Tổng cộng $total cảnh báo được ghi nhận.',
    );
  }

  WeeklyMetricData get emergencies {
    final values = _aggregateByCondition(
      (item) =>
          item.severity == EventSeverity.critical ||
          item.severity == EventSeverity.high,
    );
    final total = values.fold(0, (a, b) => a + b);
    return WeeklyMetricData(
      values: values,
      insight: total == 0
          ? 'Không có sự kiện khẩn cấp nào.'
          : 'Có $total sự kiện khẩn cấp cần lưu ý.',
    );
  }

  WeeklyMetricData get feedback {
    final values = _aggregateByCondition(
      (item) =>
          item.status == EventStatus.acknowledged ||
          item.status == EventStatus.dismissed,
    );
    final total = values.fold(0, (a, b) => a + b);
    return WeeklyMetricData(
      values: values,
      insight: total == 0
          ? 'Chưa có phản hồi nào từ gia đình.'
          : 'Gia đình đã phản hồi $total sự kiện.',
    );
  }
}
