// lib/core/router/auth_notifier.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/onboarding_service.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class AuthNotifier extends ChangeNotifier {
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
      'isReady=$_isReady, isAuthenticated=$_isAuthenticated, '
      'onboardingCompleted=$_onboardingCompleted.',
      name: 'AuthNotifier',
    );
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
  int _authRevision = 0;

  bool get isReady => _isReady;
  bool get isAuthenticated => _isAuthenticated;
  bool get onboardingCompleted => _onboardingCompleted;

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
    unawaited(_syncAuthState(user, revision));
  }

  Future<void> _syncAuthState(AppUser? user, int revision) async {
    developer.log(
      '[GoogleAuth] authStateChanges emitted: '
      'userPresent=${user != null}, uid=${user?.uid}, '
      'previousReady=$_isReady, '
      'previousAuthenticated=$_isAuthenticated.',
      name: 'AuthNotifier',
    );

    if (user == null) {
      _sessionRepository.clearCachedSession();
      _completeAuthCheck(false);
      return;
    }

    final result = await _sessionRepository.provisionSession();
    if (revision != _authRevision) return;

    result.fold(
      (failure) {
        developer.log(
          '[GoogleAuth] Backend provisioning failed in AuthNotifier: '
          '${failure.message}.',
          name: 'AuthNotifier',
        );
        _completeAuthCheck(false);
      },
      (_) {
        unawaited(_registerFcmTokenSilently());
        _completeAuthCheck(true);
      },
    );
  }

  Future<void> _registerFcmTokenSilently() async {
    try {
      await _fcmService.registerToken();
    } catch (error, stackTrace) {
      developer.log(
        'FCM token registration failed after AuthNotifier provisioning.',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _completeAuthCheck(bool isAuthenticated) {
    _authResolved = true;
    final authChanged = _isAuthenticated != isAuthenticated;
    _isAuthenticated = isAuthenticated;
    _publishStartupStatus(force: authChanged);
  }

  void _publishStartupStatus({bool force = false}) {
    final isReady = _authResolved && _onboardingLoaded && _minimumSplashElapsed;
    if (_isReady == isReady && !force) {
      developer.log(
        '[GoogleAuth] AuthNotifier status unchanged; '
        'notifyListeners() skipped.',
        name: 'AuthNotifier',
      );
      return;
    }

    _isReady = isReady;
    _notifyStatusChanged('startup status');
  }

  void _notifyStatusChanged(String reason) {
    developer.log(
      '[GoogleAuth] AuthNotifier calling notifyListeners(): '
      'reason=$reason, isReady=$_isReady, '
      'isAuthenticated=$_isAuthenticated, '
      'onboardingCompleted=$_onboardingCompleted.',
      name: 'AuthNotifier',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _authRevision++;
    _subscription.cancel();
    super.dispose();
  }
}
