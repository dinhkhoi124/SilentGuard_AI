import 'package:equatable/equatable.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';

enum NotificationDelivery { foreground, opened }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.unreadAlerts = const [],
    this.latestAlert,
    this.latestDelivery,
    this.revision = 0,
  });

  final List<NotificationAlert> unreadAlerts;
  final NotificationAlert? latestAlert;
  final NotificationDelivery? latestDelivery;
  final int revision;

  bool get hasUnread => unreadAlerts.isNotEmpty;

  NotificationsState copyWith({
    List<NotificationAlert>? unreadAlerts,
    NotificationAlert? latestAlert,
    NotificationDelivery? latestDelivery,
    int? revision,
  }) {
    return NotificationsState(
      unreadAlerts: unreadAlerts ?? this.unreadAlerts,
      latestAlert: latestAlert ?? this.latestAlert,
      latestDelivery: latestDelivery ?? this.latestDelivery,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props => [
    unreadAlerts,
    latestAlert,
    latestDelivery,
    revision,
  ];
}
