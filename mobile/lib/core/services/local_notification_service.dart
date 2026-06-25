import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static const AndroidNotificationChannel _fallChannel =
      AndroidNotificationChannel(
        'fall_alerts',
        'Cảnh báo té ngã',
        description: 'Thông báo phát hiện té ngã',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
  static const AndroidNotificationChannel _inviteChannel =
      AndroidNotificationChannel(
        'invites',
        'Lời mời gia đình',
        description: 'Lời mời tham gia hộ gia đình',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        'general',
        'Thông báo',
        description: 'Thông báo chung từ SilentGuard',
      );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<NotificationAlert?> initialize({
    required void Function(NotificationAlert alert) onAlertNotificationTap,
  }) async {
    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final alert = _alertFromPayload(response.payload);
        developer.log(
          '[FCM] local notification tapped: '
          'messageId=${alert?.rawData['messageId']}, '
          'event_id=${alert?.eventId}, severity=${alert?.severity}, '
          'persisted=true, navigationTriggered=${alert != null}.',
          name: 'LocalNotificationService',
        );
        if (alert != null) onAlertNotificationTap(alert);
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await _createAndroidChannels(androidPlugin);
    developer.log(
      '[FCM] Android notification channels verified.',
      name: 'LocalNotificationService',
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final alert = _alertFromPayload(
        launchDetails?.notificationResponse?.payload,
      );
      developer.log(
        '[FCM] local notification launch payload consumed: '
        'event_id=${alert?.eventId}, severity=${alert?.severity}.',
        name: 'LocalNotificationService',
      );
      return alert;
    }
    return null;
  }

  Future<void> showAlert(NotificationAlert alert) async {
    final payload = _payloadForAlert(alert);
    final notificationId = alert.id.hashCode & 0x7fffffff;

    await _plugin.show(
      id: notificationId,
      title: alert.displayTitle,
      body: alert.displayBody,
      notificationDetails: NotificationDetails(
        android: _androidDetailsFor(alert),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );

    developer.log(
      '[FCM] local notification shown: '
      'event_id=${alert.eventId}, severity=${alert.severity}, '
      'notificationId=$notificationId.',
      name: 'LocalNotificationService',
    );
  }

  Future<void> showFallAlert(NotificationAlert alert) => showAlert(alert);

  static Future<void> showBackgroundMessage(RemoteMessage message) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await plugin.initialize(settings: settings);

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await _createAndroidChannels(androidPlugin);

    final data = Map<String, dynamic>.from(message.data);
    final alert = NotificationAlert.fromPayload(
      data,
      messageId: message.messageId,
      title: data['title']?.toString(),
      body: data['body']?.toString(),
      receivedAt: message.sentTime,
    );
    await plugin.show(
      id: alert.id.hashCode & 0x7fffffff,
      title: alert.displayTitle,
      body: alert.displayBody,
      notificationDetails: NotificationDetails(
        android: _androidDetailsFor(alert),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _payloadForAlert(alert),
    );
  }

  Future<bool> scheduleFallAlert(CameraDevice camera) async {
    if (!await _requestPermissions()) return false;

    final alert = NotificationAlert.fromPayload(
      {'cameraId': camera.id, 'room': camera.location, 'type': 'SYSTEM'},
      title: 'Cảnh báo té ngã',
      body: 'Phát hiện sự kiện tại ${camera.location}',
      receivedAt: DateTime.now(),
    );
    final payload = _payloadForAlert(alert);
    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1 << 31,
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: alert.displayTitle,
      body: alert.displayBody,
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 5)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fall_alerts',
          'Fall Alerts',
          channelDescription: 'Emergency fall detection alerts',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    return true;
  }

  Future<bool> _requestPermissions() async {
    final androidPermission = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    if (androidPermission == false) return false;

    final exactAlarmPermission = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    if (exactAlarmPermission == false) return false;

    final iosPermission = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return iosPermission ?? true;
  }

  static Future<void> _createAndroidChannels(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    await androidPlugin?.createNotificationChannel(_fallChannel);
    await androidPlugin?.createNotificationChannel(_inviteChannel);
    await androidPlugin?.createNotificationChannel(_generalChannel);
  }

  static AndroidNotificationDetails _androidDetailsFor(
    NotificationAlert alert,
  ) {
    switch (alert.type) {
      case 'household_invite':
        return const AndroidNotificationDetails(
          'invites',
          'Lời mời gia đình',
          channelDescription: 'Lời mời tham gia hộ gia đình',
          importance: Importance.high,
          priority: Priority.high,
        );
      case 'fall_alert':
        return const AndroidNotificationDetails(
          'fall_alerts',
          'Cảnh báo té ngã',
          channelDescription: 'Thông báo phát hiện té ngã',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        );
      default:
        return const AndroidNotificationDetails(
          'general',
          'Thông báo',
          channelDescription: 'Thông báo chung từ SilentGuard',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
    }
  }

  static String _payloadForAlert(NotificationAlert alert) {
    return jsonEncode({
      ...alert.rawData,
      'id': alert.id,
      'event_id': alert.eventId,
      'camera_id': alert.cameraId,
      'type': alert.type,
      'severity': alert.severity,
      'room': alert.room,
      'title': alert.title,
      'body': alert.body,
      'receivedAt': alert.receivedAt.toIso8601String(),
    });
  }

  NotificationAlert? _alertFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      return NotificationAlert.fromPayload(
        data,
        messageId: data['messageId']?.toString(),
        title: data['title']?.toString(),
        body: data['body']?.toString(),
        receivedAt: DateTime.tryParse(data['receivedAt']?.toString() ?? ''),
        isRead: true,
      );
    } on FormatException {
      return null;
    }
  }
}
