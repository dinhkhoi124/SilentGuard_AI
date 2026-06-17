// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/auth/domain/failures/auth_failure.dart'
    as auth_failures;
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _authRepository;

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
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
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
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
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
    result.fold(
      (failure) {
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
      (user) {
        developer.log(
          '[GoogleAuth] AuthBloc received success branch: '
          'userPresent=${user != null}, uid=${user?.uid}, email=${user?.email}.',
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
            '[GoogleAuth] AuthBloc emitting AuthSuccess.',
            name: 'AuthBloc',
          );
          emit(AuthSuccess(user));
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
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (_) => emit(const AuthSignedOut()),
    );
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
