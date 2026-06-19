import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';
import 'package:mobile/features/auth/domain/failures/auth_failure.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required FirebaseAuthDataSource dataSource,
    required SessionRepository sessionRepository,
  }) : _dataSource = dataSource,
       _sessionRepository = sessionRepository;

  final FirebaseAuthDataSource _dataSource;
  final SessionRepository _sessionRepository;

  @override
  AppUser? get currentUser => _dataSource.currentUser?.toAppUser();

  @override
  Stream<AppUser?> authStateChanges() {
    return _dataSource.authStateChanges().map((user) => user?.toAppUser());
  }

  @override
  Future<Either<AuthFailure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dataSource.signUpWithEmail(
        email: email.trim(),
        password: password,
      );
      return Right(user.toAppUser());
    } on FirebaseAuthException catch (error) {
      return Left(_mapFirebaseSignUpFailure(error));
    } on FirebaseAuthDataSourceException catch (error) {
      return Left(UnknownAuthFailure(error.message));
    } catch (_) {
      return const Left(UnknownAuthFailure());
    }
  }

  @override
  Future<Either<AuthFailure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dataSource.signInWithEmail(
        email: email.trim(),
        password: password,
      );
      return Right(user.toAppUser());
    } on FirebaseAuthException catch (error) {
      return Left(_mapFirebaseSignInFailure(error));
    } on FirebaseAuthDataSourceException catch (error) {
      return Left(UnknownAuthFailure(error.message));
    } catch (_) {
      return const Left(UnknownAuthFailure());
    }
  }

  @override
  Future<Either<AuthFailure, AppUser?>> signInWithGoogle() async {
    try {
      developer.log(
        '[GoogleAuth] AuthRepository.signInWithGoogle() calling datasource.',
        name: 'AuthRepository',
      );
      final user = await _dataSource.signInWithGoogle();
      developer.log(
        '[GoogleAuth] datasource returned: '
        'userPresent=${user != null}.',
        name: 'AuthRepository',
      );
      return Right(user?.toAppUser());
    } on FirebaseAuthException catch (error, stackTrace) {
      developer.log(
        '[GoogleAuth] FirebaseAuthException in repository: '
        'code=${error.code}, message=${error.message}.',
        name: 'AuthRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(_mapGoogleFailure(error));
    } on FirebaseAuthDataSourceException catch (error, stackTrace) {
      developer.log(
        '[GoogleAuth] FirebaseAuthDataSourceException in repository: '
        'message=${error.message}.',
        name: 'AuthRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(UnknownAuthFailure(error.message));
    } catch (error, stackTrace) {
      developer.log(
        '[GoogleAuth] unexpected exception in repository.',
        name: 'AuthRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return const Left(UnknownAuthFailure());
    }
  }

  @override
  Future<Either<AuthFailure, void>> signOut() async {
    try {
      final backendLogoutResult = await _sessionRepository.logout();
      backendLogoutResult.fold(
        (failure) => developer.log(
          '[GoogleAuth] Backend logout failed before Firebase signOut: '
          '${failure.message}.',
          name: 'AuthRepository',
        ),
        (_) {},
      );
      await _dataSource.signOut();
      return const Right(null);
    } on FirebaseAuthException catch (error) {
      return Left(_mapGoogleFailure(error));
    } on FirebaseAuthDataSourceException catch (error) {
      return Left(UnknownAuthFailure(error.message));
    } catch (_) {
      return const Left(UnknownAuthFailure());
    } finally {
      _sessionRepository.clearCachedSession();
    }
  }

  AuthFailure _mapFirebaseSignUpFailure(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => const EmailAlreadyInUseFailure(),
      'invalid-email' => const InvalidEmailFailure(),
      'weak-password' => const WeakPasswordFailure(),
      'network-request-failed' => const NetworkFailure(),
      _ => UnknownAuthFailure(error.message),
    };
  }

  AuthFailure _mapFirebaseSignInFailure(FirebaseAuthException error) {
    return switch (error.code) {
      'user-not-found' => const UserNotFoundFailure(),
      'wrong-password' => const WrongPasswordFailure(),
      'invalid-credential' => const InvalidCredentialFailure(),
      'invalid-email' => const InvalidEmailFailure(),
      'user-disabled' => const UserDisabledFailure(),
      'too-many-requests' => const TooManyRequestsFailure(),
      'network-request-failed' => const NetworkFailure(),
      _ => UnknownAuthFailure(error.message),
    };
  }

  AuthFailure _mapGoogleFailure(FirebaseAuthException error) {
    return switch (error.code) {
      'account-exists-with-different-credential' =>
        const AccountExistsWithDifferentCredentialFailure(),
      'network-request-failed' => const NetworkFailure(),
      _ => UnknownAuthFailure(error.message),
    };
  }
}

extension FirebaseUserMapper on User {
  AppUser toAppUser() {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoURL,
    );
  }
}
