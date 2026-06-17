// lib/core/router/auth_notifier.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(
    this._authRepository,
    this._sessionRepository,
    this._fcmService,
  ) {
    _isAuthenticated =
        _authRepository.currentUser != null &&
        _sessionRepository.currentSession != null;
    developer.log(
      '[GoogleAuth] AuthNotifier created: '
      'instance=${identityHashCode(this)}, '
      'initialAuthenticated=$_isAuthenticated.',
      name: 'AuthNotifier',
    );
    _subscription = _authRepository.authStateChanges().listen(
      _handleAuthStateChanged,
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          '[GoogleAuth] authStateChanges stream error.',
          name: 'AuthNotifier',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;
  final FcmService _fcmService;
  late final StreamSubscription<AppUser?> _subscription;
  bool _isAuthenticated = false;
  int _authRevision = 0;

  bool get isAuthenticated => _isAuthenticated;

  void _handleAuthStateChanged(AppUser? user) {
    final revision = ++_authRevision;
    unawaited(_syncAuthState(user, revision));
  }

  Future<void> _syncAuthState(AppUser? user, int revision) async {
    developer.log(
      '[GoogleAuth] authStateChanges emitted: '
      'userPresent=${user != null}, uid=${user?.uid}, '
      'previousAuthenticated=$_isAuthenticated.',
      name: 'AuthNotifier',
    );

    if (user == null) {
      _sessionRepository.clearCachedSession();
      _setAuthenticated(false);
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
        _setAuthenticated(false);
      },
      (_) {
        unawaited(_registerFcmTokenSilently());
        _setAuthenticated(true);
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

  void _setAuthenticated(bool nextAuthenticated) {
    if (_isAuthenticated == nextAuthenticated) {
      developer.log(
        '[GoogleAuth] AuthNotifier auth boolean unchanged; '
        'notifyListeners() skipped.',
        name: 'AuthNotifier',
      );
      return;
    }

    _isAuthenticated = nextAuthenticated;
    developer.log(
      '[GoogleAuth] AuthNotifier calling notifyListeners().',
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
