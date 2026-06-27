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
          ? 'Không có cảnh báo khẩn cấp trong tuần này.'
          : 'Tổng cộng $total cảnh báo được ghi nhận.',
    );
  }

  WeeklyMetricData get highSeverity {
    final values = _aggregateByCondition(
      (item) =>
          item.severity == EventSeverity.critical ||
          item.severity == EventSeverity.high,
    );
    final total = values.fold(0, (a, b) => a + b);
    return WeeklyMetricData(
      values: values,
      insight: total == 0
          ? 'Không có cảnh báo mức cao trong tuần này.'
          : 'Theo dõi kỹ các ngày có cảnh báo mức cao.',
    );
  }

  WeeklyMetricData get handled {
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
          : 'Các phản hồi giúp gia đình theo dõi việc xử lý cảnh báo.',
    );
  }

  WeeklyMetricData get immobility {
    final values = List.filled(7, 0);
    for (final item in items) {
      if (item.timestamp != null &&
          item.durationSec != null &&
          item.durationSec! > 0) {
        final index = item.timestamp!.weekday - 1;
        if (item.durationSec! > values[index]) {
          values[index] = item.durationSec!;
        }
      }
    }
    final maxVal = values.fold(0, (a, b) => a > b ? a : b);
    return WeeklyMetricData(
      values: values,
      insight: maxVal == 0
          ? 'Không có dữ liệu bất động trong tuần này.'
          : 'Thời gian bất động dài cần được kiểm tra sớm.',
    );
  }
}
