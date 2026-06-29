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
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5));
    }
    final type = message.data['type']?.toString();
    final cameraId = _cameraIdFromPayload(message.data);
    if (type == 'fall_alert' && cameraId != null) {
      final isSuppressed =
          await MonitoringSuppressService.isSuppressedInBackground(
            sharedPreferences: await SharedPreferences.getInstance(),
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
  debugPrint('=== MAIN STARTED ===');
  final binding = WidgetsFlutterBinding.ensureInitialized();
  _logStartupSync(
    'FlutterNativeSplash.preserve',
    () => FlutterNativeSplash.preserve(widgetsBinding: binding),
  );
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

  debugPrint('[STEP] runApp start');
  runApp(
    BootstrapApp(
      initializer: AppInitializer(initializeFirebase: _initializeFirebase),
    ),
  );
  debugPrint('[STEP] runApp done');
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

T _logStartupSync<T>(String label, T Function() action) {
  final stopwatch = Stopwatch()..start();
  try {
    return action();
  } finally {
    debugPrint('[STARTUP] $label: ${stopwatch.elapsedMilliseconds}ms');
  }
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key, required this.initializer});

  final AppInitializer initializer;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  AppRouter? _appRouter;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializePostFrame());
    });
  }

  Future<void> _initializePostFrame() async {
    debugPrint('[STEP] postFrame start');
    try {
      final result = await widget.initializer.initializeAfterFirstFrame();
      if (!mounted) return;
      setState(() {
        _appRouter = result.appRouter;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.initializer.scheduleMessagingSetup(result);
      });
      debugPrint('[STEP] postFrame complete');
    } catch (error, stackTrace) {
      debugPrint('[CRASH] _initializePostFrame failed: $error\n$stackTrace');
      if (mounted) {
        FlutterNativeSplash.remove();
        setState(() {
          _initializationError = error;
        });
      }
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
    debugPrint('[STEP] BootstrapApp.build called');
    final appRouter = _appRouter;
    if (appRouter != null) return MyApp(appRouter: appRouter);

    return _BootstrapShell(error: _initializationError);
  }
}

class _BootstrapShell extends StatelessWidget {
  const _BootstrapShell({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WatchNest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('vi', 'VN'),
      home: Scaffold(
        backgroundColor: AppTheme.light.scaffoldBackgroundColor,
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không thể khởi động ứng dụng.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
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
