import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:permission_handler/permission_handler.dart';

class FcmService with WidgetsBindingObserver {
  FcmService({
    required ApiClient apiClient,
    required FirebaseAuth firebaseAuth,
    required LocalNotificationService localNotificationService,
    required MonitoringSuppressService monitoringSuppressService,
    FirebaseMessaging? messaging,
  }) : _apiClient = apiClient,
       _firebaseAuth = firebaseAuth,
       _localNotificationService = localNotificationService,
       _monitoringSuppressService = monitoringSuppressService,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;
  final LocalNotificationService _localNotificationService;
  final MonitoringSuppressService _monitoringSuppressService;
  final FirebaseMessaging _messaging;
  static const _messagingTimeout = Duration(seconds: 5);
  static const _backendRegistrationTimeout = Duration(seconds: 5);

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  NotificationsCubit? _notificationsCubit;
  bool _initialized = false;

  Future<void> initialize({
    required NotificationsCubit notificationsCubit,
    required void Function(NotificationAlert alert) onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _notificationsCubit = notificationsCubit;
    WidgetsBinding.instance.addObserver(this);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) =>
          unawaited(_handleForegroundMessage(message, notificationsCubit)),
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      unawaited(
        _handleOpenedMessage(message, notificationsCubit, onNotificationTap),
      );
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(
        _registerTokenValue(token, source: 'refresh').catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          // _registerTokenValue already logs the error.
        }),
      ),
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'FCM token refresh stream failed.',
          name: 'FcmService',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<NotificationAlert?> takeInitialAlert() async {
    try {
      final message = await _messaging.getInitialMessage().timeout(
        _messagingTimeout,
      );
      if (message == null) return null;
      if (await _isMessageSuppressed(message)) {
        developer.log(
          '[FCM] terminated message suppressed locally.',
          name: 'FcmService',
        );
        return null;
      }
      return _alertFromMessage(message);
    } catch (error, stackTrace) {
      developer.log(
        'Initial FCM message lookup failed; continuing startup.',
        name: 'FcmService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> registerToken() async {
    try {
      await requestNotificationPermission();
      final token = await _messaging.getToken().timeout(_messagingTimeout);
      await _registerTokenValue(token, source: 'current');
    } catch (error, stackTrace) {
      developer.log(
        'FCM token retrieval failed; continuing without push registration.',
        name: 'FcmService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<NotificationSettings> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidStatus = await Permission.notification.request();
      developer.log(
        'Android notification permission status: $androidStatus.',
        name: 'FcmService',
      );
    }

    final settings = await _messaging
        .requestPermission(alert: true, badge: true, sound: true)
        .timeout(_messagingTimeout);
    await _messaging
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        )
        .timeout(_messagingTimeout);
    developer.log(
      '[FCM] permission status: ${settings.authorizationStatus}.',
      name: 'FcmService',
    );
    return settings;
  }

  Future<void> _registerTokenValue(
    String? token, {
    required String source,
  }) async {
    final normalizedToken = token?.trim() ?? '';
    if (normalizedToken.isEmpty) {
      developer.log(
        'FCM token is empty; registration skipped.',
        name: 'FcmService',
      );
      return;
    }

    if (_firebaseAuth.currentUser == null) {
      developer.log(
        'FCM token $source registration skipped because no Firebase user is signed in.',
        name: 'FcmService',
      );
      return;
    }

    try {
      await _apiClient
          .postObject('/api/users/device-token', {'fcm_token': normalizedToken})
          .timeout(_backendRegistrationTimeout);
      developer.log('[FCM] token registered from $source.', name: 'FcmService');
    } catch (error, stackTrace) {
      developer.log(
        'FCM token registration failed from $source.',
        name: 'FcmService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  NotificationAlert _alertFromMessage(RemoteMessage message) {
    return NotificationAlert.fromPayload(
      Map<String, dynamic>.from(message.data),
      messageId: message.messageId,
      title: message.notification?.title ?? message.data['title']?.toString(),
      body: message.notification?.body ?? message.data['body']?.toString(),
      receivedAt: message.sentTime,
    );
  }

  Future<void> _handleForegroundMessage(
    RemoteMessage message,
    NotificationsCubit notificationsCubit,
  ) async {
    if (await _isMessageSuppressed(message)) {
      developer.log(
        '[FCM] foreground message suppressed locally.',
        name: 'FcmService',
      );
      notificationsCubit.receiveForegroundMessage(message);
      return;
    }

    final alert = _alertFromMessage(message);
    developer.log(
      '[FCM] foreground received: messageId=${message.messageId}, '
      'event_id=${alert.eventId}, severity=${alert.severity}, '
      'persisted=true, navigationTriggered=false.',
      name: 'FcmService',
    );
    notificationsCubit.receiveForegroundMessage(message);
    try {
      await _localNotificationService.showAlert(alert);
    } catch (error, stackTrace) {
      developer.log(
        '[FCM] foreground local notification display failed.',
        name: 'FcmService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleOpenedMessage(
    RemoteMessage message,
    NotificationsCubit notificationsCubit,
    void Function(NotificationAlert alert) onNotificationTap,
  ) async {
    if (await _isMessageSuppressed(message)) {
      developer.log(
        '[FCM] opened message suppressed locally; navigation skipped.',
        name: 'FcmService',
      );
      return;
    }

    final alert = _alertFromMessage(message);
    developer.log(
      '[FCM] opened from background: messageId=${message.messageId}, '
      'event_id=${alert.eventId}, severity=${alert.severity}, '
      'persisted=true, navigationTriggered=true.',
      name: 'FcmService',
    );
    notificationsCubit.receiveOpenedMessage(message);
    onNotificationTap(alert);
  }

  Future<bool> _isMessageSuppressed(RemoteMessage message) async {
    if (message.data['type']?.toString() != 'fall_alert') return false;
    final cameraId = _cameraIdFromData(message.data);
    if (cameraId == null) return false;
    return _monitoringSuppressService.isSuppressed(cameraId);
  }

  String? _cameraIdFromData(Map<String, dynamic> data) {
    for (final key in const [
      'camera_id',
      'cameraId',
      'device_id',
      'deviceId',
    ]) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final cubit = _notificationsCubit;
    if (cubit == null) return;
    developer.log(
      '[FCM] app resumed; reloading local notification store.',
      name: 'FcmService',
    );
    unawaited(cubit.refreshFromLocalAndSyncPendingAlerts());
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
