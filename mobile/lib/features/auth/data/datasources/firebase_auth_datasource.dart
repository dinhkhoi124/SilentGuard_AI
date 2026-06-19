import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/core/config/app_config.dart';

abstract interface class FirebaseAuthDataSource {
  User? get currentUser;

  Stream<User?> authStateChanges();

  Future<User> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<User> signInWithEmail({
    required String email,
    required String password,
  });

  Future<User?> signInWithGoogle();

  Future<void> signOut();
}

class FirebaseAuthDataSourceImpl implements FirebaseAuthDataSource {
  FirebaseAuthDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  Future<User> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw const FirebaseAuthDataSourceException();
    return user;
  }

  @override
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw const FirebaseAuthDataSourceException();
    return user;
  }

  @override
  Future<User?> signInWithGoogle() async {
    developer.log(
      '[GoogleAuth] signInWithGoogle: ensuring GoogleSignIn is initialized.',
      name: 'FirebaseAuthDataSource',
    );
    await _ensureGoogleInitialized();

    try {
      developer.log(
        '[GoogleAuth] calling GoogleSignIn.authenticate().',
        name: 'FirebaseAuthDataSource',
      );
      final googleUser = await _googleSignIn.authenticate();
      developer.log(
        '[GoogleAuth] authenticate() returned a Google user.',
        name: 'FirebaseAuthDataSource',
      );
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      developer.log(
        '[GoogleAuth] authentication obtained: '
        'idTokenPresent=${idToken != null && idToken.isNotEmpty}; '
        'accessTokenPresent=not exposed by google_sign_in v7 authentication.',
        name: 'FirebaseAuthDataSource',
      );
      if (idToken == null || idToken.isEmpty) {
        throw const FirebaseAuthDataSourceException(
          'Google không trả về mã xác thực.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      developer.log(
        '[GoogleAuth] calling FirebaseAuth.signInWithCredential().',
        name: 'FirebaseAuthDataSource',
      );
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      developer.log(
        '[GoogleAuth] signInWithCredential() completed: '
        'userPresent=${userCredential.user != null}.',
        name: 'FirebaseAuthDataSource',
      );
      return userCredential.user;
    } on GoogleSignInException catch (error, stackTrace) {
      developer.log(
        '[GoogleAuth] GoogleSignInException: '
        'code=${error.code}, description=${error.description}.',
        name: 'FirebaseAuthDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw FirebaseAuthDataSourceException(
        error.description ?? 'Google Sign-In thất bại.',
      );
    } catch (error, stackTrace) {
      developer.log(
        '[GoogleAuth] unexpected exception in signInWithGoogle().',
        name: 'FirebaseAuthDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _ensureGoogleInitialized();
    await _googleSignIn.signOut();
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      developer.log(
        '[GoogleAuth] GoogleSignIn already initialized.',
        name: 'FirebaseAuthDataSource',
      );
      return;
    }
    developer.log(
      '[GoogleAuth] initializing GoogleSignIn with serverClientIdPresent='
      '${AppConfig.googleSignInServerClientId.trim().isNotEmpty}.',
      name: 'FirebaseAuthDataSource',
    );
    await _googleSignIn.initialize(
      serverClientId: AppConfig.googleSignInServerClientId,
    );
    _googleInitialized = true;
    developer.log(
      '[GoogleAuth] GoogleSignIn.initialize() completed.',
      name: 'FirebaseAuthDataSource',
    );
  }
}

class FirebaseAuthDataSourceException implements Exception {
  const FirebaseAuthDataSourceException([this.message]);

  final String? message;
}
