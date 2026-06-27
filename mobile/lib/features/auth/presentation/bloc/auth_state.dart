// lib/features/auth/presentation/bloc/auth_state.dart

import 'package:equatable/equatable.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthProvisioning extends AuthState {
  const AuthProvisioning([this.message = 'Đang thiết lập tài khoản...']);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class AuthSuccess extends AuthState {
  const AuthSuccess(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
