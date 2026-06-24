import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

/// Converts [EventHistoryItem] domain data into presentation-ready strings/icons.
/// All mapping logic lives here — widgets stay dumb.
class EventHistoryDisplayMapper {
  const EventHistoryDisplayMapper._();

  static String title(EventHistoryItem item) {
    final roomLabel = _roomLabel(item.room);
    return switch (item.severity) {
      EventSeverity.critical => 'Cảnh báo khẩn cấp tại $roomLabel',
      EventSeverity.high => 'Cảnh báo tại $roomLabel',
      EventSeverity.medium => 'Cảnh báo tại $roomLabel',
      EventSeverity.low => 'Sự kiện tại $roomLabel',
      EventSeverity.system => 'Hệ thống tại $roomLabel',
      EventSeverity.unknown => 'Sự kiện tại $roomLabel',
    };
  }

  static String subtitle(EventHistoryItem item) {
    final severityLabel = _severityLabel(item.severity);
    final statusLabel = _statusLabel(item.status);
    final dur = item.durationSec;
    if (dur != null && dur > 0) {
      return '$severityLabel · $statusLabel · ${dur}s';
    }
    return '$severityLabel · $statusLabel';
  }

  static String statusBadge(EventHistoryItem item) {
    return _statusLabel(item.status);
  }

  static String timeLabel(EventHistoryItem item) {
    final ts = item.timestamp;
    if (ts == null) return '--:--';
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static IconData icon(EventHistoryItem item) {
    return switch (item.severity) {
      EventSeverity.critical => Iconsax.danger,
      EventSeverity.high => Iconsax.danger,
      EventSeverity.medium => Iconsax.warning_2,
      EventSeverity.low => Iconsax.info_circle,
      EventSeverity.system => Iconsax.monitor,
      EventSeverity.unknown => Iconsax.activity,
    };
  }

  // ─── private helpers ────────────────────────────────────────────────────────

  static String _roomLabel(String room) {
    return _roomTranslations[room.toLowerCase()] ?? room;
  }

  static const _roomTranslations = <String, String>{
    'bedroom': 'phòng ngủ',
    'living_room': 'phòng khách',
    'living-room': 'phòng khách',
    'livingroom': 'phòng khách',
    'bathroom': 'nhà tắm',
    'kitchen': 'bếp',
    'hallway': 'hành lang',
    'garage': 'ga-ra',
    'không rõ phòng': 'không rõ phòng',
  };

  static String _severityLabel(EventSeverity severity) {
    return switch (severity) {
      EventSeverity.critical => 'Khẩn cấp',
      EventSeverity.high => 'Mức cao',
      EventSeverity.medium => 'Mức trung bình',
      EventSeverity.low => 'Mức thấp',
      EventSeverity.system => 'Hệ thống',
      EventSeverity.unknown => 'Không rõ',
    };
  }

  static String _statusLabel(EventStatus status) {
    return switch (status) {
      EventStatus.pending => 'Chờ xử lý',
      EventStatus.acknowledged => 'Đã xác nhận',
      EventStatus.dismissed => 'Đã bỏ qua',
      EventStatus.escalated => 'Đã chuyển tiếp',
      EventStatus.loggedOnly => 'Chỉ ghi nhận',
      EventStatus.unknown => 'Không rõ',
    };
  }
}
