import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/features/household_invite/data/datasources/household_invite_remote_data_source.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/injection_container.dart' as di;

class AppInitializationResult {
  const AppInitializationResult({
    required this.appRouter,
    required this.notificationsCubit,
  });

  final AppRouter appRouter;
  final NotificationsCubit notificationsCubit;
}

class AppInitializer {
  const AppInitializer();

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
    final resolvedRouter = appRouter ?? AppRouter(di.sl());

    unawaited(
      Future.microtask(() async {
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
      }),
    );

    unawaited(
      Future.microtask(() async {
        final initialLocalAlert = await _initializeLocalNotifications(
          onAlertTap: (alert) {
            notificationsCubit.receiveOpenedAlert(alert);
            _openNotificationAlert(resolvedRouter, alert);
          },
        );
        if (initialLocalAlert != null) {
          notificationsCubit.receiveOpenedAlert(initialLocalAlert);
          _openNotificationAlert(resolvedRouter, initialLocalAlert);
        }
      }),
    );

    unawaited(
      Future.microtask(() async {
        try {
          final authNotifier = di.sl<AuthNotifier>();
          if (authNotifier.isAuthenticated) {
            final remoteDataSource = di.sl<HouseholdInviteRemoteDataSource>();
            final invites = await remoteDataSource.getPendingInvites();

            for (final invite in invites) {
              final payload = {
                'type': 'household_invite',
                'invite_request_id': invite.inviteRequestId,
                'household_id': invite.householdId,
                'household_name': invite.householdName,
                'inviter_name': invite.inviterName,
                'title': 'Bạn được mời vào gia đình',
                'body':
                    '${invite.inviterName} mời bạn theo dõi camera gia đình cùng.',
              };
              final alert = NotificationAlert.fromPayload(
                payload,
                messageId: 'invite_${invite.inviteRequestId}',
                receivedAt: invite.createdAt,
              );
              // Store as opened alert so it doesn't trigger foreground banner but appears in list
              notificationsCubit.receiveOpenedAlert(
                alert.copyWith(isRead: false),
              );
            }
          }
        } catch (e) {
          developer.log(
            'Failed to fetch pending invites on startup',
            error: e,
            name: 'AppInitializer',
          );
        }
      }),
    );

    return AppInitializationResult(
      appRouter: resolvedRouter,
      notificationsCubit: notificationsCubit,
    );
  }

  void scheduleMessagingSetup(AppInitializationResult result) {
    unawaited(
      Future.microtask(() async {
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

  Future<NotificationAlert?> _initializeLocalNotifications({
    required void Function(NotificationAlert alert) onAlertTap,
  }) async {
    try {
      return await di.sl<LocalNotificationService>().initialize(
        onAlertNotificationTap: onAlertTap,
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

  Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);
}
