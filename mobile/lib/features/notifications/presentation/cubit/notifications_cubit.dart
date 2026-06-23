import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._localDataSource)
    : super(const NotificationsState()) {
    unawaited(loadNotifications());
  }

  final NotificationLocalDataSource _localDataSource;

  Future<void> loadNotifications() async {
    emit(state.copyWith(isLoading: true));
    try {
      final notifications = await _localDataSource.loadNotifications();
      emit(state.copyWith(notifications: notifications, isLoading: false));
    } catch (error, stackTrace) {
      developer.log(
        'Notification history load failed.',
        name: 'NotificationsCubit',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(isLoading: false));
    }
  }

  void receiveForegroundAlert(NotificationAlert alert) {
    unawaited(_storeAlert(alert, NotificationDelivery.foreground));
  }

  void receiveOpenedAlert(NotificationAlert alert) {
    unawaited(
      _storeAlert(alert.copyWith(isRead: true), NotificationDelivery.opened),
    );
  }

  void receiveForegroundMessage(RemoteMessage message) {
    receiveForegroundAlert(_alertFromMessage(message));
  }

  void receiveOpenedMessage(RemoteMessage message) {
    receiveOpenedAlert(_alertFromMessage(message));
  }

  Future<void> markRead(String id) async {
    final updated = state.notifications
        .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList(growable: false);
    await _persist(updated);
    emit(state.copyWith(notifications: updated));
  }

  Future<void> markAllRead() async {
    if (!state.hasUnread) return;
    final updated = state.notifications
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false);
    await _persist(updated);
    emit(state.copyWith(notifications: updated));
  }

  Future<void> _storeAlert(
    NotificationAlert alert,
    NotificationDelivery delivery,
  ) async {
    final notifications = NotificationLocalDataSource.insertOrReplace(
      state.notifications,
      alert,
    );
    await _persist(notifications);
    emit(
      state.copyWith(
        notifications: notifications,
        latestAlert: alert,
        latestDelivery: delivery,
        revision: state.revision + 1,
      ),
    );
  }

  Future<void> _persist(List<NotificationAlert> notifications) async {
    try {
      await _localDataSource.saveNotifications(notifications);
    } catch (error, stackTrace) {
      developer.log(
        'Notification history persist failed.',
        name: 'NotificationsCubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  NotificationAlert _alertFromMessage(RemoteMessage message) {
    return NotificationAlert.fromPayload(
      Map<String, dynamic>.from(message.data),
      messageId: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      receivedAt: message.sentTime,
    );
  }
}
