// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/constants/mock_auth.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
  }

  static const failureMessage =
      'Tài khoản không đúng. Dùng: user@smartify.vn / 123456';

  void _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) {
    emit(const AuthLoading());
    if (event.email.trim() == kMockEmail && event.password == kMockPassword) {
      emit(const AuthSuccess());
    } else {
      emit(const AuthFailure(failureMessage));
    }
  }
}
