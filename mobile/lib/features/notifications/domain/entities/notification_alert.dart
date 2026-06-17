import 'package:equatable/equatable.dart';

class NotificationAlert extends Equatable {
  const NotificationAlert({
    required this.receivedAt,
    this.eventId,
    this.cameraId,
    this.severity,
    this.room,
    this.title,
    this.body,
  });

  final String? eventId;
  final String? cameraId;
  final String? severity;
  final String? room;
  final String? title;
  final String? body;
  final DateTime receivedAt;

  String get displayTitle {
    final trimmedTitle = title?.trim() ?? '';
    if (trimmedTitle.isNotEmpty) return trimmedTitle;
    return 'Cảnh báo té ngã';
  }

  String get displayBody {
    final trimmedBody = body?.trim() ?? '';
    if (trimmedBody.isNotEmpty) return trimmedBody;

    final trimmedRoom = room?.trim() ?? '';
    if (trimmedRoom.isNotEmpty) return 'Phát hiện sự kiện tại $trimmedRoom.';

    return 'Smartify vừa nhận cảnh báo mới.';
  }

  factory NotificationAlert.fromPayload(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    return NotificationAlert(
      eventId: _readString(data, const ['event_id', 'eventId', 'id']),
      cameraId: _readString(data, const [
        'camera_id',
        'cameraId',
        'device_id',
        'deviceId',
      ]),
      severity: _readString(data, const ['severity', 'level']),
      room: _readString(data, const ['room', 'location', 'camera_room']),
      title: title,
      body: body,
      receivedAt: DateTime.now(),
    );
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    eventId,
    cameraId,
    severity,
    room,
    title,
    body,
    receivedAt,
  ];
}
