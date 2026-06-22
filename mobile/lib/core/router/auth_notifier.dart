// lib/core/router/auth_notifier.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/onboarding_service.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

// Timeouts for background operations — long enough to succeed on a slow
// railway.app cold-start, but bounded so they never block the auth flow.
const Duration _kProvisionTimeout = Duration(seconds: 8);
const Duration _kFcmTimeout = Duration(seconds: 5);

enum AuthStartupPhase {
  checkingSession,
  provisioningSession,
  unauthenticated,
  authenticated,
}

class AuthNotifier extends ChangeNotifier with WidgetsBindingObserver {
  AuthNotifier(
    this._authRepository,
    this._sessionRepository,
    this._fcmService,
    this._onboardingService,
  ) {
    developer.log(
      '[GoogleAuth] AuthNotifier created: '
      'instance=${identityHashCode(this)}, '
      'currentUserPresent=${_authRepository.currentUser != null}, '
      'cachedBackendSessionPresent=${_sessionRepository.currentSession != null}, '
      'phase=$_phase, isReady=$_isReady, '
      'isAuthenticated=$_isAuthenticated, '
      'onboardingCompleted=$_onboardingCompleted.',
      name: 'AuthNotifier',
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadOnboardingStatus());
    unawaited(_completeMinimumSplashDelay());
    _subscription = _authRepository.authStateChanges().listen(
      _handleAuthStateChanged,
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          '[GoogleAuth] authStateChanges stream error.',
          name: 'AuthNotifier',
          error: error,
          stackTrace: stackTrace,
        );
        _completeAuthCheck(false);
      },
    );
  }

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;
  final FcmService _fcmService;
  final OnboardingService _onboardingService;
  late final StreamSubscription<AppUser?> _subscription;
  bool _isReady = false;
  bool _isAuthenticated = false;
  bool _onboardingCompleted = false;
  bool _authResolved = false;
  bool _onboardingLoaded = false;
  bool _minimumSplashElapsed = false;
  bool _disposed = false;
  bool _splashRemoved = false;
  // Set to true when the last background provision attempt failed.
  // Cleared on next successful provision or on sign-out.
  bool _provisionFailed = false;
  int _authRevision = 0;
  AuthStartupPhase _phase = AuthStartupPhase.checkingSession;

  bool get isReady => _isReady;
  bool get isAuthenticated => _isAuthenticated;
  bool get onboardingCompleted => _onboardingCompleted;
  AuthStartupPhase get phase => _phase;

  Future<void> completeOnboarding() async {
    await _onboardingService.markCompleted();
    if (_onboardingCompleted) return;
    _onboardingCompleted = true;
    _notifyStatusChanged('onboarding completed');
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      _onboardingCompleted = await _onboardingService.isCompleted();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read onboarding completion flag.',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
      _onboardingCompleted = false;
    }
    _onboardingLoaded = true;
    _publishStartupStatus();
  }

  Future<void> _completeMinimumSplashDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _minimumSplashElapsed = true;
    _publishStartupStatus();
  }

  void _handleAuthStateChanged(AppUser? user) {
    final revision = ++_authRevision;
    developer.log(
      '[GoogleAuth] authStateChanges emitted: '
      'userPresent=${user != null}, previousPhase=$_phase, '
      'previousReady=$_isReady, '
      'previousAuthenticated=$_isAuthenticated.',
      name: 'AuthNotifier',
    );

    if (user == null) {
      _provisionFailed = false;
      _sessionRepository.clearCachedSession();
      _completeAuthCheck(false);
      return;
    }

    // Immediately mark the user as authenticated so the router can redirect
    // to /home without waiting for the backend provision call. The provision
    // and FCM registration continue in the background.
    _phase = AuthStartupPhase.authenticated;
    _completeAuthCheck(true);

    unawaited(_provisionInBackground(revision));
  }

  /// Runs session provision + FCM token registration asynchronously.
  /// Never throws — any failure is logged and stored in [_provisionFailed]
  /// so that [didChangeAppLifecycleState] can retry on next foreground resume.
  Future<void> _provisionInBackground(int revision) async {
    if (_disposed || revision != _authRevision) return;

    try {
      developer.log(
        'Starting background session provision.',
        name: 'AuthNotifier',
      );
      final result = await _sessionRepository
          .provisionSession()
          .timeout(_kProvisionTimeout);

      if (_disposed || revision != _authRevision) return;

      result.fold(
        (failure) {
          developer.log(
            '[AuthNotifier] Background provision failed: ${failure.message}.',
            name: 'AuthNotifier',
          );
          _provisionFailed = true;
        },
        (_) {
          developer.log(
            'Background session provision succeeded.',
            name: 'AuthNotifier',
          );
          _provisionFailed = false;
        },
      );
    } on TimeoutException {
      developer.log(
        '[AuthNotifier] provisionSession timed out — continuing without session.',
        name: 'AuthNotifier',
      );
      _provisionFailed = true;
    } catch (error, stackTrace) {
      developer.log(
        '[AuthNotifier] Background provision error.',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
      _provisionFailed = true;
    }

    if (_disposed || revision != _authRevision) return;

    // Always attempt FCM token registration after provision (success or fail),
    // so the user still receives push notifications even if the session call
    // timed out on a slow cold-start.
    try {
      await _fcmService.registerToken().timeout(_kFcmTimeout);
    } on TimeoutException {
      developer.log(
        '[AuthNotifier] FCM token registration timed out.',
        name: 'AuthNotifier',
      );
    } catch (error, stackTrace) {
      developer.log(
        '[AuthNotifier] FCM token registration failed.',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Retries background provision when the app returns to the foreground and
  /// the previous attempt failed (e.g. no network at cold-start).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isAuthenticated &&
        _provisionFailed &&
        !_disposed) {
      developer.log(
        '[AuthNotifier] App resumed with failed provision — retrying.',
        name: 'AuthNotifier',
      );
      unawaited(_provisionInBackground(_authRevision));
    }
  }

  void _completeAuthCheck(bool isAuthenticated) {
    _authResolved = true;
    final authChanged = _isAuthenticated != isAuthenticated;
    _isAuthenticated = isAuthenticated;
    _phase = isAuthenticated
        ? AuthStartupPhase.authenticated
        : AuthStartupPhase.unauthenticated;
    _publishStartupStatus(force: authChanged);
  }

  void _publishStartupStatus({bool force = false}) {
    final isReady = _authResolved && _onboardingLoaded && _minimumSplashElapsed;
    final wasReady = _isReady;
    if (_isReady == isReady && !force) {
      developer.log(
        '[GoogleAuth] AuthNotifier status unchanged; '
        'notifyListeners() skipped.',
        name: 'AuthNotifier',
      );
      return;
    }

    _isReady = isReady;
    if (!wasReady && isReady && !_splashRemoved) {
      _splashRemoved = true;
      // Remove the native splash only when router auth state is resolved, so
      // users never see the wrong route during Firebase session restoration.
      FlutterNativeSplash.remove();
    }
    _notifyStatusChanged('startup status');
  }

  void _notifyStatusChanged(String reason) {
    developer.log(
      '[GoogleAuth] AuthNotifier calling notifyListeners(): '
      'reason=$reason, phase=$_phase, isReady=$_isReady, '
      'isAuthenticated=$_isAuthenticated, '
      'onboardingCompleted=$_onboardingCompleted.',
      name: 'AuthNotifier',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authRevision++;
    _subscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
