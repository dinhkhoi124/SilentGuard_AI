import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/injection_container.dart' as di;

typedef BackgroundMessageHandler = Future<void> Function(RemoteMessage message);

class AppInitializationResult {
  const AppInitializationResult({
    required this.appRouter,
    required this.notificationsCubit,
  });

  final AppRouter appRouter;
  final NotificationsCubit notificationsCubit;
}

class AppInitializer {
  const AppInitializer({required this.backgroundMessageHandler});

  final BackgroundMessageHandler backgroundMessageHandler;

  Future<AppInitializationResult> initializeAfterFirstFrame({
    AppRouter? appRouter,
  }) async {
    _configureCrashReporting();
    await _yieldToUi();

    // GetIt registration is lazy, but keep it post-frame so plugin singletons
    // cannot be resolved before the native splash has handed off to Flutter.
    await di.init();
    await _yieldToUi();

    final notificationsCubit = di.sl<NotificationsCubit>();
    final initialFcmAlert = await _takeInitialFcmAlert();
    if (initialFcmAlert != null) {
      notificationsCubit.receiveOpenedAlert(initialFcmAlert);
    }
    await _yieldToUi();

    final initialCameraId = await _initializeLocalNotifications(
      onCameraTap: (cameraId) {
        appRouter?.router.go('/camera/$cameraId');
      },
    );
    await _yieldToUi();

    appRouter ??= AppRouter(
      di.sl(),
      initialLocation: _initialLocation(
        localCameraId: initialCameraId,
        fcmAlert: initialFcmAlert,
      ),
    );

    return AppInitializationResult(
      appRouter: appRouter,
      notificationsCubit: notificationsCubit,
    );
  }

  void scheduleMessagingSetup(AppInitializationResult result) {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3), () async {
        // Background handler registration can create a background engine on
        // Android, so keep it well after the first rendered Flutter frame.
        FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);
        await _yieldToUi();

        await di.sl<FcmService>().initialize(
          notificationsCubit: result.notificationsCubit,
          onNotificationTap: (alert) =>
              _openNotificationAlert(result.appRouter, alert),
        );
      }).catchError((Object error, StackTrace stackTrace) {
        developer.log(
          'Deferred FCM listener initialization failed.',
          name: 'AppInitializer',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  Future<NotificationAlert?> _takeInitialFcmAlert() async {
    try {
      return await di.sl<FcmService>().takeInitialAlert();
    } catch (error, stackTrace) {
      developer.log(
        'Initial FCM alert lookup failed; continuing startup.',
        name: 'AppInitializer',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String?> _initializeLocalNotifications({
    required void Function(String cameraId) onCameraTap,
  }) async {
    try {
      return await di.sl<LocalNotificationService>().initialize(
        onCameraNotificationTap: onCameraTap,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Local notification initialization failed; continuing startup.',
        name: 'AppInitializer',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  void _configureCrashReporting() {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
      return true;
    };
  }

  String _initialLocation({
    required String? localCameraId,
    required NotificationAlert? fcmAlert,
  }) {
    if (localCameraId != null) return '/camera/$localCameraId';

    final fcmCameraId = fcmAlert?.cameraId;
    if (fcmCameraId != null && fcmCameraId.isNotEmpty) {
      return '/camera/${Uri.encodeComponent(fcmCameraId)}';
    }

    return '/home';
  }

  void _openNotificationAlert(AppRouter appRouter, NotificationAlert alert) {
    final cameraId = alert.cameraId;
    if (cameraId != null && cameraId.isNotEmpty) {
      appRouter.router.go('/camera/${Uri.encodeComponent(cameraId)}');
      return;
    }

    appRouter.router.go('/home');
  }

  Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);
}
