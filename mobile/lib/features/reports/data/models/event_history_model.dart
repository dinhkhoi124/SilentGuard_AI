import 'package:mobile/features/reports/domain/entities/event_history_item.dart';
import 'package:mobile/features/reports/domain/entities/event_history_page.dart';

class EventHistoryItemModel {
  const EventHistoryItemModel({
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
  final String room;
  final double? confidence;
  final DateTime? timestamp;
  final int? durationSec;
  final String? clipPath;

  factory EventHistoryItemModel.fromJson(Map<String, dynamic> json) {
    final rawRoom = json['room'];
    final room = (rawRoom is String && rawRoom.trim().isNotEmpty)
        ? rawRoom.trim()
        : 'Không rõ phòng';

    DateTime? timestamp;
    try {
      final rawTs = json['timestamp'];
      if (rawTs is String && rawTs.isNotEmpty) {
        timestamp = DateTime.parse(rawTs).toLocal();
      }
    } catch (_) {
      // Unparseable timestamp — keep null, do not crash.
    }

    double? confidence;
    final rawConf = json['confidence'];
    if (rawConf is num) confidence = rawConf.toDouble();

    int? durationSec;
    final rawDur = json['duration_sec'];
    if (rawDur is num) durationSec = rawDur.toInt();

    final rawClip = json['clip_path'];
    final clipPath = (rawClip is String && rawClip.isNotEmpty) ? rawClip : null;

    return EventHistoryItemModel(
      id: _stringOr(json['id'], 'unknown-id'),
      eventId: _stringOr(json['event_id'], 'unknown-event'),
      severity: EventSeverity.fromString(json['severity'] as String?),
      status: EventStatus.fromString(json['status'] as String?),
      room: room,
      confidence: confidence,
      timestamp: timestamp,
      durationSec: durationSec,
      clipPath: clipPath,
    );
  }

  static String _stringOr(dynamic value, String fallback) {
    if (value is String && value.isNotEmpty) return value;
    return fallback;
  }

  EventHistoryItem toEntity() {
    return EventHistoryItem(
      id: id,
      eventId: eventId,
      severity: severity,
      status: status,
      room: room,
      confidence: confidence,
      timestamp: timestamp,
      durationSec: durationSec,
      clipPath: clipPath,
    );
  }
}

class EventHistoryResponseModel {
  const EventHistoryResponseModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<EventHistoryItemModel> items;
  final int total;
  final int page;
  final int pageSize;

  factory EventHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<EventHistoryItemModel> items;
    if (rawItems is List) {
      items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(EventHistoryItemModel.fromJson)
          .toList(growable: false);
    } else {
      items = const [];
    }

    return EventHistoryResponseModel(
      items: items,
      total: _intOr(json['total'], 0),
      page: _intOr(json['page'], 1),
      pageSize: _intOr(json['page_size'], 20),
    );
  }

  static int _intOr(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  EventHistoryPage toEntity() {
    return EventHistoryPage(
      items: items.map((m) => m.toEntity()).toList(growable: false),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }
}
