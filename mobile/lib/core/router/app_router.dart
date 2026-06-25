// lib/core/router/app_router.dart

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/widgets/wave_text_loader.dart';
import 'package:mobile/features/auth/presentation/pages/signup_page.dart';
import 'package:mobile/features/auth/presentation/pages/welcome_page.dart';
import 'package:mobile/features/automation/presentation/pages/emergency_contacts_page.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/account/presentation/pages/app_appearance_page.dart';
import 'package:mobile/features/account/presentation/pages/faq_page.dart';
import 'package:mobile/features/account/presentation/pages/help_support_page.dart';
import 'package:mobile/features/account/presentation/pages/notification_settings_page.dart';
import 'package:mobile/features/account/presentation/pages/privacy_policy_page.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_bloc.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_event.dart';
import 'package:mobile/features/devices/presentation/pages/device_pairing_page.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/usecases/get_camera_devices.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/pages/camera_detail_page.dart';
import 'package:mobile/features/home/presentation/pages/home_page.dart';
import 'package:mobile/features/notifications/presentation/pages/notifications_page.dart';
import 'package:mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:mobile/injection_container.dart';

class AppRouter {
  AppRouter(this.authNotifier, {this.initialLocation = '/home'})
    : _postAuthLocation = initialLocation == '/loading'
          ? '/home'
          : initialLocation;

  final AuthNotifier authNotifier;
  final String initialLocation;
  final String _postAuthLocation;

  late final GoRouter router = GoRouter(
    refreshListenable: authNotifier,
    initialLocation: '/loading',
    redirect: (context, state) {
      final isReady = authNotifier.isReady;
      final isAuthenticated = authNotifier.isAuthenticated;
      final onboardingCompleted = authNotifier.onboardingCompleted;
      final authPhase = authNotifier.phase;
      final onLoading = state.matchedLocation == '/loading';
      final onOnboarding = state.matchedLocation == '/onboarding';
      final onAuthFlow =
          state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/signup';
      developer.log(
        '[GoogleAuth] GoRouter.redirect: '
        'authNotifier=${identityHashCode(authNotifier)}, '
        'matchedLocation=${state.matchedLocation}, '
        'phase=$authPhase, isReady=$isReady, '
        'isAuthenticated=$isAuthenticated, '
        'onboardingCompleted=$onboardingCompleted, '
        'onLoading=$onLoading, onOnboarding=$onOnboarding, '
        'onAuthFlow=$onAuthFlow.',
        name: 'AppRouter',
      );

      if (!isReady) return onLoading ? null : '/loading';
      if (isAuthenticated) {
        if (onLoading || onOnboarding || onAuthFlow) return _postAuthLocation;
        return null;
      }

      if (!onboardingCompleted) return onOnboarding ? null : '/onboarding';
      if (onLoading || onOnboarding) return '/welcome';
      if (!onAuthFlow) return '/welcome';
      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(
          backgroundColor: AppColors.background,
          body: WaveTextLoader(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/faq', builder: (context, state) => const FaqPage()),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpPage()),
      GoRoute(
        path: '/home',
        builder: (context, state) => BlocProvider(
          create: (_) => sl<HomeBloc>(),
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: '/add-device',
        builder: (context, state) => BlocProvider(
          create: (_) =>
              sl<DevicePairingBloc>()..add(const DevicePairingStarted()),
          child: const DevicePairingPage(),
        ),
      ),
      GoRoute(
        path: '/emergency-contacts',
        builder: (context, state) => const EmergencyContactsPage(),
      ),
      GoRoute(
        path: '/app-appearance',
        builder: (context, state) => const AppAppearancePage(),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/help-support',
        builder: (context, state) => const HelpSupportPage(),
      ),
      GoRoute(path: '/faq', builder: (context, state) => const FaqPage()),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/camera/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          if (extra is CameraDetailArgs) {
            return BlocProvider(
              create: (_) => sl<HomeBloc>(),
              child: CameraDetailPage(
                device: extra.device,
                onThumbnailCaptured: extra.onThumbnailCaptured,
              ),
            );
          }
          if (extra is CameraDevice) {
            return BlocProvider(
              create: (_) => sl<HomeBloc>(),
              child: CameraDetailPage(device: extra),
            );
          }
          return _CameraRouteLoader(cameraId: id);
        },
      ),
    ],
  );
}

class _CameraRouteLoader extends StatelessWidget {
  const _CameraRouteLoader({required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl<GetCameraDevices>()(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return snapshot.data!.fold(
          (failure) => _CameraRouteError(message: failure),
          (devices) {
            for (final device in devices) {
              if (device.id == cameraId) {
                return BlocProvider(
                  create: (_) => sl<HomeBloc>(),
                  child: CameraDetailPage(device: device),
                );
              }
            }
            return const _CameraRouteError(
              message: 'Không tìm thấy camera này.',
            );
          },
        );
      },
    );
  }
}

class _CameraRouteError extends StatelessWidget {
  const _CameraRouteError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.destructive,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.darkText),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
