import 'package:equatable/equatable.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';

enum NotificationDelivery { foreground, opened }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.notifications = const [],
    this.latestAlert,
    this.latestDelivery,
    this.revision = 0,
    this.isLoading = false,
  });

  final List<NotificationAlert> notifications;
  final NotificationAlert? latestAlert;
  final NotificationDelivery? latestDelivery;
  final int revision;
  final bool isLoading;

  List<NotificationAlert> get unreadAlerts =>
      notifications.where((item) => !item.isRead).toList(growable: false);

  int get unreadCount => unreadAlerts.length;

  bool get hasUnread => unreadCount > 0;

  NotificationsState copyWith({
    List<NotificationAlert>? notifications,
    NotificationAlert? latestAlert,
    NotificationDelivery? latestDelivery,
    int? revision,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      latestAlert: latestAlert ?? this.latestAlert,
      latestDelivery: latestDelivery ?? this.latestDelivery,
      revision: revision ?? this.revision,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    notifications,
    latestAlert,
    latestDelivery,
    revision,
    isLoading,
  ];
}
