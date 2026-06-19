import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:permission_handler/permission_handler.dart';

class FcmService {
  FcmService({
    required ApiClient apiClient,
    required FirebaseAuth firebaseAuth,
    FirebaseMessaging? messaging,
  }) : _apiClient = apiClient,
       _firebaseAuth = firebaseAuth,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;
  final FirebaseMessaging _messaging;
  static const _messagingTimeout = Duration(seconds: 5);
  static const _backendRegistrationTimeout = Duration(seconds: 5);

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;

  Future<void> initialize({
    required NotificationsCubit notificationsCubit,
    required void Function(NotificationAlert alert) onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final alert = _alertFromMessage(message);
      developer.log(
        'Foreground FCM alert received: eventId=${alert.eventId}, '
        'cameraId=${alert.cameraId}.',
        name: 'FcmService',
      );
      notificationsCubit.receiveForegroundAlert(alert);
    });

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final alert = _alertFromMessage(message);
      developer.log(
        'FCM notification opened: eventId=${alert.eventId}, '
        'cameraId=${alert.cameraId}.',
        name: 'FcmService',
      );
      notificationsCubit.receiveOpenedAlert(alert);
      onNotificationTap(alert);
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
          alert: true,
          badge: true,
          sound: true,
        )
        .timeout(_messagingTimeout);
    developer.log(
      'FCM permission status: ${settings.authorizationStatus}.',
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
      developer.log('FCM token registered from $source.', name: 'FcmService');
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
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
