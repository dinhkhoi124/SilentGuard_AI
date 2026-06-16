import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static const AndroidNotificationChannel _fallChannel =
      AndroidNotificationChannel(
        'fall_alerts',
        'Cảnh báo té ngã',
        description: 'Thông báo khẩn cấp khi phát hiện có người té ngã',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<String?> initialize({
    required void Function(String cameraId) onCameraNotificationTap,
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
        final cameraId = _cameraIdFromPayload(response.payload);
        if (cameraId != null) onCameraNotificationTap(cameraId);
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_fallChannel);

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      return _cameraIdFromPayload(launchDetails?.notificationResponse?.payload);
    }
    return null;
  }

  Future<bool> scheduleFallAlert(CameraDevice camera) async {
    if (!await _requestPermissions()) return false;

    final payload = jsonEncode({'cameraId': camera.id});
    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1 << 31,
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Cảnh báo té ngã',
      body: 'Phát hiện sự kiện tại ${camera.location}',
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 5)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fall_alerts',
          'Cảnh báo té ngã',
          channelDescription:
              'Thông báo khẩn cấp khi phát hiện có người té ngã',
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

  String? _cameraIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic>) return null;
      final cameraId = data['cameraId'];
      return cameraId is String ? cameraId : null;
    } on FormatException {
      return null;
    }
  }
}
