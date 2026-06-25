import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationLocalDataSource {
  NotificationLocalDataSource(this._preferences);

  static const storageKey = 'app_notifications';
  static const maxItems = 100;

  final SharedPreferencesAsync _preferences;

  Future<List<NotificationAlert>> loadNotifications() async {
    final raw = await _preferences.getString(storageKey);
    return decodeNotifications(raw);
  }

  Future<void> saveNotifications(List<NotificationAlert> notifications) async {
    final trimmed = notifications.take(maxItems).toList(growable: false);
    await _preferences.setString(storageKey, encodeNotifications(trimmed));
  }

  static List<NotificationAlert> decodeNotifications(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                NotificationAlert.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Stored notifications could not be decoded.',
        name: 'NotificationLocalDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  static String encodeNotifications(List<NotificationAlert> notifications) {
    return jsonEncode(notifications.map((item) => item.toJson()).toList());
  }

  static List<NotificationAlert> insertOrReplace(
    List<NotificationAlert> current,
    NotificationAlert notification,
  ) {
    final merged = [
      notification,
      ...current.where((item) => item.id != notification.id),
    ]..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return merged.take(maxItems).toList(growable: false);
  }

  static Future<void> saveBackgroundMessage(RemoteMessage message) async {
    try {
      final preferences = SharedPreferencesAsync();
      final current = decodeNotifications(
        await preferences.getString(storageKey),
      );
      final alert = NotificationAlert.fromPayload(
        Map<String, dynamic>.from(message.data),
        messageId: message.messageId,
        title: message.notification?.title ?? message.data['title']?.toString(),
        body: message.notification?.body ?? message.data['body']?.toString(),
        receivedAt: message.sentTime,
      );
      await preferences.setString(
        storageKey,
        encodeNotifications(insertOrReplace(current, alert)),
      );
      developer.log(
        '[FCM] background notification persisted: '
        'messageId=${message.messageId}, event_id=${alert.eventId}, '
        'severity=${alert.severity}.',
        name: 'NotificationLocalDataSource',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Background notification persist failed.',
        name: 'NotificationLocalDataSource',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
