// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/firebase_options.dart';
import 'package:mobile/injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await di.init();

  late final AppRouter appRouter;
  final initialCameraId = await di.sl<LocalNotificationService>().initialize(
    onCameraNotificationTap: (cameraId) {
      appRouter.router.go('/camera/$cameraId');
    },
  );
  appRouter = AppRouter(
    di.sl<AuthNotifier>(),
    initialLocation: initialCameraId == null
        ? '/home'
        : '/camera/$initialCameraId',
  );

  runApp(MyApp(appRouter: appRouter));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.appRouter});

  final AppRouter? appRouter;

  @override
  Widget build(BuildContext context) {
    final router = appRouter ?? AppRouter(di.sl<AuthNotifier>());

    return BlocProvider(
      create: (_) => di.sl<AuthBloc>(),
      child: MaterialApp.router(
        title: 'WatchNest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router.router,
      ),
    );
  }
}
