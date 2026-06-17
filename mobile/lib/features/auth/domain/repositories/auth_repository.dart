import 'package:dartz/dartz.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';
import 'package:mobile/features/auth/domain/failures/auth_failure.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<Either<AuthFailure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Either<AuthFailure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<AuthFailure, AppUser?>> signInWithGoogle();

  Future<Either<AuthFailure, void>> signOut();
}
