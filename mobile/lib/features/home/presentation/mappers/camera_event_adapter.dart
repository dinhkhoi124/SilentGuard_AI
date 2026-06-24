import 'package:mobile/features/home/domain/entities/camera_event.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

/// Converts [EventHistoryItem] (backend-sourced) to [CameraEvent]
/// so the existing [CameraEventTile] and feedback UI work with zero changes.
///
/// Mapping decisions:
/// - [id] is set to [EventHistoryItem.eventId] (the human-readable EVT-…
///   string) because [AlertReviewFeedback.eventId] is used in the review
///   PATCH endpoint which expects the event_id string, not the DB uuid.
/// - [time] is formatted as HH:mm from [timestamp], or '--:--' if missing.
/// - [type] and [level] are derived from [severity].
/// - [description] combines room + status + duration for display context.
/// - [thumbnailAsset] is always null — clip thumbnails are not fetched on list.
class CameraEventAdapter {
  const CameraEventAdapter._();

  static CameraEvent fromEventHistoryItem(EventHistoryItem item) {
    return CameraEvent(
      // Use event_id (EVT-…) for feedback API compatibility
      id: item.eventId,
      time: _formatTime(item.timestamp),
      title: _title(item.severity),
      description: _description(item),
      level: _level(item.severity),
      type: _type(item.severity),
      thumbnailAsset: null,
    );
  }

  static List<CameraEvent> fromList(List<EventHistoryItem> items) {
    return items.map(fromEventHistoryItem).toList(growable: false);
  }

  // ─── private helpers ────────────────────────────────────────────────────────

  static String _formatTime(DateTime? ts) {
    if (ts == null) return '--:--';
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _title(EventSeverity severity) {
    return switch (severity) {
      EventSeverity.critical => 'Cảnh báo té ngã',
      EventSeverity.high => 'Cảnh báo té ngã',
      EventSeverity.medium => 'Cảnh báo cần kiểm tra',
      EventSeverity.low => 'Sự kiện nhẹ',
      EventSeverity.system => 'Sự kiện hệ thống',
      EventSeverity.unknown => 'Sự kiện camera',
    };
  }

  static String _description(EventHistoryItem item) {
    final statusLabel = _statusLabel(item.status);
    final dur = item.durationSec;
    final conf = item.confidence;

    final parts = <String>[
      item.room,
      statusLabel,
      if (dur != null && dur > 0) '${dur}s',
      if (conf != null) '${(conf * 100).toStringAsFixed(0)}% tin cậy',
    ];
    return parts.join(' · ');
  }

  static String _statusLabel(EventStatus status) {
    return switch (status) {
      EventStatus.pending => 'Đang chờ',
      EventStatus.acknowledged => 'Đã xử lý',
      EventStatus.dismissed => 'Báo động giả',
      EventStatus.escalated => 'Đã chuyển tiếp',
      EventStatus.loggedOnly => 'Chỉ ghi nhận',
      EventStatus.unknown => 'Không rõ',
    };
  }

  static EventLevel _level(EventSeverity severity) {
    return switch (severity) {
      EventSeverity.critical || EventSeverity.high => EventLevel.high,
      EventSeverity.medium => EventLevel.medium,
      EventSeverity.low => EventLevel.normal,
      EventSeverity.system || EventSeverity.unknown => EventLevel.info,
    };
  }

  static EventType _type(EventSeverity severity) {
    return switch (severity) {
      EventSeverity.critical || EventSeverity.high => EventType.fall,
      EventSeverity.medium => EventType.still,
      EventSeverity.low => EventType.normal,
      EventSeverity.system || EventSeverity.unknown => EventType.reconnect,
    };
  }
}
