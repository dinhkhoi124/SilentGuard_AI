// lib/core/router/auth_notifier.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._authRepository) {
    _isAuthenticated = _authRepository.currentUser != null;
    _subscription = _authRepository.authStateChanges().listen((user) {
      final nextAuthenticated = user != null;
      if (_isAuthenticated == nextAuthenticated) return;

      _isAuthenticated = nextAuthenticated;
      notifyListeners();
    });
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<Object?> _subscription;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
