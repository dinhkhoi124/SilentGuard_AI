// lib/main.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:mobile/core/bootstrap/app_initializer.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/theme_controller.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/features/video_upload/presentation/bloc/video_upload_bloc.dart';
import 'package:mobile/firebase_options.dart';
import 'package:mobile/injection_container.dart' as di;
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
    final type = message.data['type']?.toString();
    final cameraId = _cameraIdFromPayload(message.data);
    if (type == 'fall_alert' && cameraId != null) {
      final isSuppressed =
          await MonitoringSuppressService.isSuppressedInBackground(
            sharedPreferences: SharedPreferencesAsync(),
            cameraId: cameraId,
          );
      if (isSuppressed) {
        await NotificationLocalDataSource.saveBackgroundMessage(message);
        developer.log(
          '[FCM] background message suppressed locally; persisted=true.',
          name: 'FcmBackground',
        );
        return;
      }
    }
    await NotificationLocalDataSource.saveBackgroundMessage(message);
    await LocalNotificationService.showBackgroundMessage(message);
    developer.log(
      '[FCM] background received: messageId=${message.messageId}, '
      'event_id=${message.data['event_id'] ?? message.data['eventId']}, '
      'severity=${message.data['severity']}, persisted=true.',
      name: 'FcmBackground',
    );
  } catch (error, stackTrace) {
    developer.log(
      'Background FCM handling failed.',
      name: 'FcmBackground',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

String? _cameraIdFromPayload(Map<String, dynamic> data) {
  for (final key in const ['camera_id', 'cameraId', 'device_id', 'deviceId']) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

Future<void> main() async {
  // Tier 1: only the Flutter binding and Firebase core are allowed to block
  // before runApp. Everything else is delayed until Flutter can paint splash.
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  Stopwatch? startupStopwatch;
  if (kDebugMode) {
    startupStopwatch = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[Startup] First frame rendered in '
        '${startupStopwatch!.elapsedMilliseconds}ms',
      );
    });
  }
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  ]);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await di.init();
  await di.sl<ThemeController>().load();

  final appRouter = AppRouter(di.sl());

  runApp(
    BootstrapApp(appRouter: appRouter, initializer: const AppInitializer()),
  );
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({
    super.key,
    required this.appRouter,
    required this.initializer,
  });

  final AppRouter appRouter;
  final AppInitializer initializer;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializePostFrame());
    });
  }

  Future<void> _initializePostFrame() async {
    try {
      // Tier 2: plugin setup, local notifications, and initial FCM lookup stay
      // post-frame. AppInitializer yields between platform-channel calls to
      // avoid DartMessenger congestion.
      final result = await widget.initializer.initializeAfterFirstFrame(
        appRouter: widget.appRouter,
      );
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.initializer.scheduleMessagingSetup(result);
      });
    } catch (error, stackTrace) {
      developer.log(
        'App post-frame initialization failed.',
        name: 'Bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyApp(appRouter: widget.appRouter);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appRouter});

  final AppRouter appRouter;

  @override
  Widget build(BuildContext context) {
    final themeController = di.sl<ThemeController>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider(create: (_) => di.sl<VideoUploadBloc>()),
        BlocProvider.value(value: di.sl<NotificationsCubit>()),
      ],
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'WatchNest',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeController.themeMode,
            locale: const Locale('vi', 'VN'),
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}
