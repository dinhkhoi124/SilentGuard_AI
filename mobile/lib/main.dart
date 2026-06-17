// lib/main.dart

import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/firebase_options.dart';
import 'package:mobile/injection_container.dart' as di;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  developer.log(
    'Background FCM received: messageId=${message.messageId}, '
    'data=${message.data}.',
    name: 'FcmBackground',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await di.init();

  late final AppRouter appRouter;
  final notificationsCubit = di.sl<NotificationsCubit>();
  final initialFcmAlert = await di.sl<FcmService>().takeInitialAlert();
  if (initialFcmAlert != null) {
    notificationsCubit.receiveOpenedAlert(initialFcmAlert);
  }

  final initialCameraId = await di.sl<LocalNotificationService>().initialize(
    onCameraNotificationTap: (cameraId) {
      appRouter.router.go('/camera/$cameraId');
    },
  );
  appRouter = AppRouter(
    di.sl<AuthNotifier>(),
    initialLocation: _initialLocation(
      localCameraId: initialCameraId,
      fcmAlert: initialFcmAlert,
    ),
  );
  await di.sl<FcmService>().initialize(
    notificationsCubit: notificationsCubit,
    onNotificationTap: (alert) => _openNotificationAlert(appRouter, alert),
  );

  runApp(MyApp(appRouter: appRouter));
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

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.appRouter});

  final AppRouter? appRouter;

  @override
  Widget build(BuildContext context) {
    final router = appRouter ?? AppRouter(di.sl<AuthNotifier>());

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider.value(value: di.sl<NotificationsCubit>()),
      ],
      child: MaterialApp.router(
        title: 'WatchNest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router.router,
      ),
    );
  }
}
