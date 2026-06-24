enum EventSeverity {
  low,
  medium,
  high,
  critical,
  system,
  unknown;

  static EventSeverity fromString(String? raw) {
    return switch (raw?.toUpperCase()) {
      'LOW' => EventSeverity.low,
      'MEDIUM' => EventSeverity.medium,
      'HIGH' => EventSeverity.high,
      'CRITICAL' => EventSeverity.critical,
      'SYSTEM' => EventSeverity.system,
      _ => EventSeverity.unknown,
    };
  }
}

enum EventStatus {
  pending,
  acknowledged,
  dismissed,
  escalated,
  loggedOnly,
  unknown;

  static EventStatus fromString(String? raw) {
    return switch (raw?.toLowerCase()) {
      'pending' => EventStatus.pending,
      'acknowledged' => EventStatus.acknowledged,
      'dismissed' => EventStatus.dismissed,
      'escalated' => EventStatus.escalated,
      'logged_only' => EventStatus.loggedOnly,
      _ => EventStatus.unknown,
    };
  }
}

class EventHistoryItem {
  const EventHistoryItem({
    required this.id,
    required this.eventId,
    required this.severity,
    required this.status,
    required this.room,
    this.confidence,
    this.timestamp,
    this.durationSec,
    this.clipPath,
  });

  final String id;
  final String eventId;
  final EventSeverity severity;
  final EventStatus status;

  /// Display-ready room label. Never null — falls back to 'Không rõ phòng'.
  final String room;

  final double? confidence;
  final DateTime? timestamp;
  final int? durationSec;
  final String? clipPath;
}
