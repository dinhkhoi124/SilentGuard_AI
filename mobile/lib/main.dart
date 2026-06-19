// lib/main.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:mobile/core/bootstrap/app_initializer.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/firebase_options.dart';
import 'package:mobile/injection_container.dart' as di;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
    developer.log(
      'Background FCM received: messageId=${message.messageId}, '
      'data=${message.data}.',
      name: 'FcmBackground',
    );
  } catch (error, stackTrace) {
    developer.log(
      'Background FCM initialization failed; message handling skipped.',
      name: 'FcmBackground',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> main() async {
  // Tier 1: only the Flutter binding and Firebase core are allowed to block
  // before runApp. Everything else is delayed until Flutter can paint splash.
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    const BootstrapApp(
      initializer: AppInitializer(
        backgroundMessageHandler: _firebaseMessagingBackgroundHandler,
      ),
    ),
  );
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key, required this.initializer});

  final AppInitializer initializer;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  AppInitializationResult? _initializationResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializePostFrame());
    });
  }

  Future<void> _initializePostFrame() async {
    try {
      // Tier 2: plugin setup, DI, local notifications, initial FCM lookup, and
      // router creation are intentionally post-frame. AppInitializer yields
      // between platform-channel calls to avoid DartMessenger congestion.
      final result = await widget.initializer.initializeAfterFirstFrame();
      if (!mounted) return;

      setState(() => _initializationResult = result);
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
    final result = _initializationResult;
    if (result == null) {
      return MaterialApp(
        title: 'WatchNest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(backgroundColor: Color(0xFF2B5CE6)),
      );
    }

    return MyApp(appRouter: result.appRouter);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appRouter});

  final AppRouter appRouter;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider.value(value: di.sl<NotificationsCubit>()),
      ],
      child: MaterialApp.router(
        title: 'WatchNest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter.router,
      ),
    );
  }
}
