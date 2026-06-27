import 'package:equatable/equatable.dart';

class NotificationAlert extends Equatable {
  const NotificationAlert({
    required this.id,
    required this.receivedAt,
    this.isRead = false,
    this.eventId,
    this.cameraId,
    this.type,
    this.severity,
    this.room,
    this.title,
    this.body,
    this.inviteRequestId,
    this.householdId,
    this.householdName,
    this.inviterName,
    this.rawData = const {},
  });

  final String id;
  final String? eventId;
  final String? cameraId;
  final String? type;
  final String? severity;
  final String? room;
  final String? title;
  final String? body;
  final String? inviteRequestId;
  final String? householdId;
  final String? householdName;
  final String? inviterName;
  final DateTime receivedAt;
  final bool isRead;
  final Map<String, dynamic> rawData;

  String get displayTitle {
    final trimmedTitle = title?.trim() ?? '';
    if (trimmedTitle.isNotEmpty) return trimmedTitle;
    
    if (type == 'household_invite') {
      return 'Lời mời tham gia hộ gia đình';
    }
    return 'Cảnh báo té ngã';
  }

  String get displayBody {
    final trimmedBody = body?.trim() ?? '';
    if (trimmedBody.isNotEmpty) return trimmedBody;

    if (type == 'household_invite') {
      return 'Bạn có một lời mời tham gia hộ gia đình đang chờ phản hồi.';
    }

    final trimmedRoom = room?.trim() ?? '';
    if (trimmedRoom.isNotEmpty) return 'Phát hiện sự kiện tại $trimmedRoom.';

    return 'Hệ thống phát hiện một sự kiện cần kiểm tra.';
  }

  String get displayRoom {
    final trimmedRoom = room?.trim() ?? '';
    if (trimmedRoom.isNotEmpty) return trimmedRoom;
    return 'Không rõ vị trí';
  }

  String get displaySeverity {
    switch ((severity ?? type ?? '').trim().toUpperCase()) {
      case 'LOW':
        return 'Thấp';
      case 'MEDIUM':
        return 'Trung bình';
      case 'HIGH':
        return 'Cao';
      case 'CRITICAL':
        return 'Khẩn cấp';
      case 'SYSTEM':
        return 'Hệ thống';
      default:
        return 'Hệ thống';
    }
  }

  NotificationAlert copyWith({bool? isRead, DateTime? receivedAt}) {
    return NotificationAlert(
      id: id,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
      eventId: eventId,
      cameraId: cameraId,
      type: type,
      severity: severity,
      room: room,
      title: title,
      body: body,
      inviteRequestId: inviteRequestId,
      householdId: householdId,
      householdName: householdName,
      inviterName: inviterName,
      rawData: rawData,
    );
  }

  factory NotificationAlert.fromPayload(
    Map<String, dynamic> data, {
    String? messageId,
    String? title,
    String? body,
    DateTime? receivedAt,
    bool isRead = false,
  }) {
    final resolvedReceivedAt = receivedAt ?? DateTime.now();
    return NotificationAlert(
      id: _resolveId(data, messageId, resolvedReceivedAt),
      eventId: _readString(data, const ['event_id', 'eventId', 'id']),
      cameraId: _readString(data, const [
        'camera_id',
        'cameraId',
        'device_id',
        'deviceId',
      ]),
      type: _readString(data, const ['type', 'notification_type']),
      severity: _readString(data, const ['severity', 'level']),
      room: _readString(data, const ['room', 'location', 'camera_room']),
      title: title,
      body: body,
      inviteRequestId: _readString(data, const [
        'invite_request_id',
        'inviteRequestId',
      ]),
      householdId: _readString(data, const ['household_id', 'householdId']),
      householdName: _readString(data, const [
        'household_name',
        'householdName',
      ]),
      inviterName: _readString(data, const ['inviter_name', 'inviterName']),
      receivedAt: resolvedReceivedAt,
      isRead: isRead,
      rawData: {
        ...Map<String, dynamic>.from(data),
        if (messageId != null && messageId.trim().isNotEmpty)
          'messageId': messageId,
      },
    );
  }

  factory NotificationAlert.fromJson(Map<String, dynamic> json) {
    return NotificationAlert(
      id: (json['id'] ?? '').toString(),
      title: _nullableString(json['title']),
      body: _nullableString(json['body']),
      eventId: _nullableString(json['eventId']),
      cameraId: _nullableString(json['cameraId']),
      type: _nullableString(json['type']),
      severity: _nullableString(json['severity']),
      room: _nullableString(json['room']),
      inviteRequestId: _nullableString(json['inviteRequestId']),
      householdId: _nullableString(json['householdId']),
      householdName: _nullableString(json['householdName']),
      inviterName: _nullableString(json['inviterName']),
      isRead: json['isRead'] == true,
      receivedAt:
          DateTime.tryParse((json['receivedAt'] ?? '').toString()) ??
          DateTime.now(),
      rawData: json['rawData'] is Map
          ? Map<String, dynamic>.from(json['rawData'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'eventId': eventId,
      'cameraId': cameraId,
      'type': type,
      'severity': severity,
      'room': room,
      'inviteRequestId': inviteRequestId,
      'householdId': householdId,
      'householdName': householdName,
      'inviterName': inviterName,
      'receivedAt': receivedAt.toIso8601String(),
      'isRead': isRead,
      'rawData': rawData,
    };
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _resolveId(
    Map<String, dynamic> data,
    String? messageId,
    DateTime receivedAt,
  ) {
    final eventId = _readString(data, const ['event_id', 'eventId', 'id']);
    if (eventId != null && eventId.isNotEmpty) return eventId;

    final firebaseId = messageId?.trim() ?? '';
    if (firebaseId.isNotEmpty) return firebaseId;

    final cameraId = _readString(data, const ['camera_id', 'cameraId']);
    final severity = _readString(data, const ['severity', 'level']);
    final fallback = [
      receivedAt.millisecondsSinceEpoch.toString(),
      cameraId,
      severity,
    ].whereType<String>().where((value) => value.isNotEmpty).join(':');
    return fallback.isNotEmpty
        ? fallback
        : receivedAt.microsecondsSinceEpoch.toString();
  }

  @override
  List<Object?> get props => [
    id,
    eventId,
    cameraId,
    type,
    severity,
    room,
    title,
    body,
    inviteRequestId,
    householdId,
    householdName,
    inviterName,
    receivedAt,
    isRead,
    rawData,
  ];
}
