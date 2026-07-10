import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/services/connectivity_service.dart';
import 'package:mobile/core/services/daily_report_notification_service.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:mobile/core/theme/theme_controller.dart';
import 'package:mobile/features/household_invite/data/datasources/household_invite_remote_data_source.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/injection_container.dart' as di;
import 'package:intl/date_symbol_data_local.dart';

class AppInitializationResult {
  const AppInitializationResult({
    required this.appRouter,
    required this.notificationsCubit,
  });

  final AppRouter appRouter;
  final NotificationsCubit notificationsCubit;
}

class AppInitializer {
  const AppInitializer({this.initializeFirebase});

  final Future<void> Function()? initializeFirebase;

  Future<AppInitializationResult> initializeAfterFirstFrame({
    AppRouter? appRouter,
  }) async {
    final stopwatch = Stopwatch()..start();

    await _logStartupAsync(
      'intl.initializeDateFormatting',
      () => initializeDateFormatting('vi', null),
    );
    debugPrint('[STEP] initializeDateFormatting done');
    await _yieldToUi();

    final initializeFirebase = this.initializeFirebase;
    if (initializeFirebase != null) {
      await _logStartupAsync('Firebase.initializeApp', () async {
        try {
          // Firebase plugins require the main isolate and platform channels.
          // Isolate.run() must NOT be used here — it will deadlock platform channels.
          await initializeFirebase();
        } catch (e) {
          debugPrint(
            '[STARTUP] Firebase init failed: $e — continuing in degraded mode',
          );
        }
      });
      debugPrint('[STEP] Firebase.initializeApp done');
      await _yieldToUi();
      debugPrint('[STEP] yield after Firebase.initializeApp done');
    }

    _logStartupSync('AppInitializer.configureCrashReporting', () {
      _configureCrashReporting();
    });
    debugPrint('[STEP] configureCrashReporting done');
    await _yieldToUi();
    debugPrint('[STEP] yield after configureCrashReporting done');

    await _logStartupAsync('AppInitializer.di.init', di.init);
    debugPrint('[STEP] di.init done');
    await _yieldToUi();
    debugPrint('[STEP] yield after di.init done');

    await _logStartupAsync(
      'ConnectivityService.initialize',
      () => di.sl<ConnectivityService>().initialize(),
    );

    // Wait one full frame before ThemeController so Android's ANR watchdog
    // receives a heartbeat frame and does not flag the process as frozen.
    await Future<void>.delayed(const Duration(milliseconds: 16));

    await _logStartupAsync(
      'ThemeController.load',
      () => di.sl<ThemeController>().load(),
    );
    debugPrint('[STEP] ThemeController done');
    await _yieldToUi();
    debugPrint('[STEP] yield after ThemeController done');

    await _logStartupAsync(
      'MonitoringSuppressService.pruneExpired',
      () => di.sl<MonitoringSuppressService>().pruneExpired(),
    );
    debugPrint('[STEP] MonitoringSuppressService.pruneExpired done');
    await _yieldToUi();
    debugPrint(
      '[STEP] yield after MonitoringSuppressService.pruneExpired done',
    );

    final notificationsCubit = di.sl<NotificationsCubit>();
    final resolvedRouter = appRouter ?? AppRouter(di.sl());

    await _logStartupAsync(
      'AppInitializer.takeInitialFcmAlert',
      () => _handleInitialFcmAlert(notificationsCubit, resolvedRouter),
    );
    debugPrint('[STEP] takeInitialFcmAlert done');
    await _yieldToUi();
    debugPrint('[STEP] yield after takeInitialFcmAlert done');

    await _logStartupAsync(
      'AppInitializer.initializeLocalNotifications',
      () =>
          _initializeLocalNotificationsStep(notificationsCubit, resolvedRouter),
    );
    debugPrint('[STEP] initializeLocalNotifications done');
    await _yieldToUi();
    debugPrint('[STEP] yield after initializeLocalNotifications done');

    await _logStartupAsync(
      'DailyReportNotificationService.syncSchedule',
      () => di.sl<DailyReportNotificationService>().syncSchedule(),
    );
    debugPrint('[STEP] DailyReportNotificationService.syncSchedule done');
    await _yieldToUi();

    await _logStartupAsync(
      'AppInitializer.loadPendingInvites',
      () => _loadPendingInvites(notificationsCubit),
    );
    debugPrint('[STEP] loadPendingInvites done');
    await _yieldToUi();
    debugPrint('[STEP] yield after loadPendingInvites done');

    debugPrint('[STEP] returning AppInitializationResult');

    stopwatch.stop();

    if (kDebugMode) {
      const realDeviceBudgetMs = 3000;
      debugPrint(
        '[STARTUP] Total initializeAfterFirstFrame: ${stopwatch.elapsedMilliseconds}ms'
        '${stopwatch.elapsedMilliseconds >= realDeviceBudgetMs ? " ⚠️ EXCEEDS ${realDeviceBudgetMs}ms real device budget" : ""}',
      );
      // Do NOT assert here — emulator timing is unreliable and an AssertionError
      // surfaces as an ANR/crash on Android before error boundaries can catch it.
    }

    return AppInitializationResult(
      appRouter: resolvedRouter,
      notificationsCubit: notificationsCubit,
    );
  }

  void scheduleMessagingSetup(AppInitializationResult result) {
    // Delay FCM setup well past first interactive frame to avoid competing
    // with the initial render and triggering the Android ANR watchdog.
    // microtask() runs before the next frame; 500ms ensures the UI is visible.
    Future<void>.delayed(const Duration(milliseconds: 500)).then((_) async {
      try {
        await _initializeMessagingSetup(result);
      } catch (error, stackTrace) {
        debugPrint(
          '[CRASH] scheduleMessagingSetup failed: $error\n$stackTrace',
        );
      }
    });
  }

  Future<void> _initializeMessagingSetup(AppInitializationResult result) async {
    try {
      await _logStartupAsync(
        'AppInitializer.FcmService.initialize',
        () => di
            .sl<FcmService>()
            .initialize(
              notificationsCubit: result.notificationsCubit,
              onNotificationTap: (alert) =>
                  _openNotificationAlert(result.appRouter, alert),
            )
            .timeout(const Duration(seconds: 10)),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Deferred FCM listener initialization failed.',
        name: 'AppInitializer',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleInitialFcmAlert(
    NotificationsCubit notificationsCubit,
    AppRouter resolvedRouter,
  ) async {
    final initialFcmAlert = await _takeInitialFcmAlert();
    if (initialFcmAlert == null) return;

    notificationsCubit.receiveOpenedAlert(initialFcmAlert);
    developer.log(
      '[FCM] opened from terminated: event_id=${initialFcmAlert.eventId}, '
      'severity=${initialFcmAlert.severity}, persisted=true, '
      'navigationTriggered=true.',
      name: 'AppInitializer',
    );
    _openNotificationAlert(resolvedRouter, initialFcmAlert);
  }

  Future<void> _initializeLocalNotificationsStep(
    NotificationsCubit notificationsCubit,
    AppRouter resolvedRouter,
  ) async {
    final initialLocalAlert = await _initializeLocalNotifications(
      onAlertTap: (alert) {
        unawaited(
          _handleLocalNotificationTap(
            notificationsCubit,
            resolvedRouter,
            alert,
          ),
        );
      },
      onNavigateToTap: (destination) {
        _openDestination(resolvedRouter, destination);
      },
    );
    if (initialLocalAlert == null) return;
    await _handleLocalNotificationTap(
      notificationsCubit,
      resolvedRouter,
      initialLocalAlert,
    );
  }

  Future<void> _loadPendingInvites(
    NotificationsCubit notificationsCubit,
  ) async {
    try {
      final authNotifier = di.sl<AuthNotifier>();
      if (!authNotifier.isAuthenticated) return;

      final remoteDataSource = di.sl<HouseholdInviteRemoteDataSource>();
      final invites = await remoteDataSource.getPendingInvites();

      for (final invite in invites) {
        final payload = {
          'type': 'household_invite',
          'invite_request_id': invite.inviteRequestId,
          'household_id': invite.householdId,
          'household_name': invite.householdName,
          'inviter_name': invite.inviterName,
          'title': 'Báº¡n Ä‘Æ°á»£c má»i vÃ o gia Ä‘Ã¬nh',
          'body':
              '${invite.inviterName} má»i báº¡n theo dÃµi camera gia Ä‘Ã¬nh cÃ¹ng.',
        };
        final alert = NotificationAlert.fromPayload(
          payload,
          messageId: 'invite_${invite.inviteRequestId}',
          receivedAt: invite.createdAt,
        );
        // Store as opened alert so it does not trigger foreground banner but appears in list.
        notificationsCubit.receiveOpenedAlert(alert.copyWith(isRead: false));
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch pending invites on startup',
        name: 'AppInitializer',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<NotificationAlert?> _takeInitialFcmAlert() async {
    try {
      return await di.sl<FcmService>().takeInitialAlert().timeout(
        const Duration(seconds: 5),
      );
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

  Future<NotificationAlert?> _initializeLocalNotifications({
    required void Function(NotificationAlert alert) onAlertTap,
    void Function(String destination)? onNavigateToTap,
  }) async {
    try {
      return await di.sl<LocalNotificationService>().initialize(
        onAlertNotificationTap: onAlertTap,
        onNavigateToTap: onNavigateToTap,
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

  void _openNotificationAlert(AppRouter appRouter, NotificationAlert alert) {
    final cameraId = alert.cameraId;
    if (cameraId != null && cameraId.isNotEmpty) {
      developer.log(
        '[FCM] navigation triggered: cameraId=$cameraId, '
        'event_id=${alert.eventId}, severity=${alert.severity}.',
        name: 'AppInitializer',
      );
      appRouter.router.go('/camera/${Uri.encodeComponent(cameraId)}');
      return;
    }

    developer.log(
      '[FCM] navigation skipped to home: event_id=${alert.eventId}, '
      'severity=${alert.severity}, cameraIdMissing=true.',
      name: 'AppInitializer',
    );
    appRouter.router.go('/home');
  }

  /// Navigate to a named destination from a navigate_to notification payload.
  void _openDestination(AppRouter appRouter, String destination) {
    developer.log(
      '[FCM] navigate_to tapped: destination=$destination',
      name: 'AppInitializer',
    );
    switch (destination) {
      case 'reports':
        // Tab index 3 = Reports (see _tabTitles in home_page.dart).
        appRouter.router.go('/home', extra: 3);
      default:
        appRouter.router.go('/home');
    }
  }

  Future<void> _handleLocalNotificationTap(
    NotificationsCubit notificationsCubit,
    AppRouter appRouter,
    NotificationAlert alert,
  ) async {
    final cameraId = alert.cameraId?.trim();
    if (cameraId != null &&
        cameraId.isNotEmpty &&
        await di.sl<MonitoringSuppressService>().isSuppressed(cameraId)) {
      developer.log(
        '[FCM] local notification tap suppressed; navigation skipped.',
        name: 'AppInitializer',
      );
      return;
    }

    notificationsCubit.receiveOpenedAlert(alert);
    _openNotificationAlert(appRouter, alert);
  }

  Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);
}

Future<T> _logStartupAsync<T>(String label, Future<T> Function() action) async {
  final stopwatch = Stopwatch()..start();
  try {
    return await action();
  } finally {
    debugPrint('[STARTUP] $label: ${stopwatch.elapsedMilliseconds}ms');
  }
}

T _logStartupSync<T>(String label, T Function() action) {
  final stopwatch = Stopwatch()..start();
  try {
    return action();
  } finally {
    debugPrint('[STARTUP] $label: ${stopwatch.elapsedMilliseconds}ms');
  }
}
