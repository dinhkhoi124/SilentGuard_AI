// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/services/fcm_service.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';
import 'package:mobile/features/auth/domain/failures/auth_failure.dart'
    as auth_failures;
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required SessionRepository sessionRepository,
    required FcmService fcmService,
    required MonitoringSuppressService monitoringSuppressService,
  }) : _authRepository = authRepository,
       _sessionRepository = sessionRepository,
       _fcmService = fcmService,
       _monitoringSuppressService = monitoringSuppressService,
       super(const AuthInitial()) {
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;
  final FcmService _fcmService;
  final MonitoringSuppressService _monitoringSuppressService;

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    final validationMessage = _validateEmailAndPassword(
      email: event.email,
      password: event.password,
    );
    if (validationMessage != null) {
      emit(AuthFailure(validationMessage));
      return;
    }

    emit(const AuthLoading());
    final result = await _authRepository.signUpWithEmail(
      email: event.email,
      password: event.password,
    );
    await result.fold(
      (failure) async => emit(AuthFailure(failure.message)),
      (user) => _provisionAndEmitSuccess(user, emit),
    );
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final validationMessage = _validateEmailAndPassword(
      email: event.email,
      password: event.password,
    );
    if (validationMessage != null) {
      emit(AuthFailure(validationMessage));
      return;
    }

    emit(const AuthLoading());
    final result = await _authRepository.signInWithEmail(
      email: event.email,
      password: event.password,
    );
    await result.fold(
      (failure) async => emit(AuthFailure(failure.message)),
      (user) => _provisionAndEmitSuccess(user, emit),
    );
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    developer.log(
      '[GoogleAuth] AuthBloc received AuthGoogleSignInRequested.',
      name: 'AuthBloc',
    );
    emit(const AuthLoading());
    developer.log(
      '[GoogleAuth] AuthBloc emitted AuthLoading.',
      name: 'AuthBloc',
    );
    final result = await _authRepository.signInWithGoogle();
    developer.log(
      '[GoogleAuth] AuthRepository.signInWithGoogle() completed.',
      name: 'AuthBloc',
    );
    await result.fold(
      (failure) async {
        developer.log(
          '[GoogleAuth] AuthBloc received failure: '
          '${failure.runtimeType}, message="${failure.message}".',
          name: 'AuthBloc',
        );
        if (failure is auth_failures.GoogleSignInCancelledFailure) {
          developer.log(
            '[GoogleAuth] AuthBloc emitting AuthInitial after cancellation.',
            name: 'AuthBloc',
          );
          emit(const AuthInitial());
        } else {
          developer.log(
            '[GoogleAuth] AuthBloc emitting AuthFailure.',
            name: 'AuthBloc',
          );
          emit(AuthFailure(failure.message));
        }
      },
      (user) async {
        developer.log(
          '[GoogleAuth] AuthBloc received success branch: '
          'userPresent=${user != null}.',
          name: 'AuthBloc',
        );
        if (user == null) {
          developer.log(
            '[GoogleAuth] AuthBloc emitting AuthInitial for null user.',
            name: 'AuthBloc',
          );
          emit(const AuthInitial());
        } else {
          developer.log(
            '[GoogleAuth] AuthBloc provisioning backend session.',
            name: 'AuthBloc',
          );
          await _provisionAndEmitSuccess(user, emit);
        }
      },
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _authRepository.signOut();
    await result.fold((failure) async => emit(AuthFailure(failure.message)), (
      _,
    ) async {
      await _monitoringSuppressService.clearAll();
      emit(const AuthSignedOut());
    });
  }

  Future<void> _provisionAndEmitSuccess(
    AppUser user,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthProvisioning());
    final sessionResult = await _sessionRepository.provisionSession();
    sessionResult.fold((failure) => emit(AuthFailure(failure.message)), (_) {
      developer.log(
        '[GoogleAuth] AuthBloc emitting AuthSuccess after backend provisioning.',
        name: 'AuthBloc',
      );
      emit(AuthSuccess(user));
      _scheduleFcmTokenRegistration();
    });
  }

  void _scheduleFcmTokenRegistration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          _registerFcmTokenSilently,
        ),
      );
    });
  }

  Future<void> _registerFcmTokenSilently() async {
    try {
      await _fcmService.registerToken();
    } catch (error, stackTrace) {
      developer.log(
        'FCM token registration failed after backend provisioning. '
        'Login will continue.',
        name: 'AuthBloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String? _validateEmailAndPassword({
    required String email,
    required String password,
  }) {
    final trimmedEmail = email.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return 'Vui lòng nhập email hợp lệ.';
    }
    if (password.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    return null;
  }
}
