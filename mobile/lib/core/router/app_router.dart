// lib/core/router/app_router.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/pages/signin_page.dart';
import 'package:mobile/features/auth/presentation/pages/signup_page.dart';
import 'package:mobile/features/auth/presentation/pages/welcome_page.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/pages/home_page.dart';
import 'package:mobile/injection_container.dart';

class AppRouter {
  AppRouter(this.authNotifier);

  final AuthNotifier authNotifier;

  late final GoRouter router = GoRouter(
    refreshListenable: authNotifier,
    initialLocation: '/welcome',
    redirect: (context, state) {
      final isAuthenticated = authNotifier.isAuthenticated;
      final onAuthFlow =
          state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/signin';

      if (isAuthenticated && onAuthFlow) return '/home';
      if (!isAuthenticated && !onAuthFlow) return '/welcome';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => BlocProvider(
          create: (_) => sl<AuthBloc>(),
          child: const SignUpPage(),
        ),
      ),
      GoRoute(path: '/signin', builder: (context, state) => const SignInPage()),
      GoRoute(
        path: '/home',
        builder: (context, state) => BlocProvider(
          create: (_) => sl<HomeBloc>()..add(const HomeStarted()),
          child: const HomePage(),
        ),
      ),
    ],
  );
}
