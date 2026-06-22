import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/session/data/datasources/session_remote_datasource.dart';
import 'package:mobile/features/session/domain/entities/backend_session.dart';
import 'package:mobile/features/session/domain/entities/household.dart';
import 'package:mobile/features/session/domain/failures/session_failure.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._remoteDataSource);

  final SessionRemoteDataSource _remoteDataSource;

  BackendSession? _cachedSession;
  Future<Either<SessionFailure, BackendSession>>? _provisionInFlight;
  int _cacheGeneration = 0;

  @override
  BackendSession? get currentSession => _cachedSession;

  @override
  Household? get currentHousehold => _cachedSession?.household;

  @override
  String? get currentHouseholdId => _cachedSession?.householdId;

  @override
  Future<Either<SessionFailure, BackendSession>> provisionSession({
    String? inviteCode,
  }) {
    final cached = _cachedSession;
    if (cached != null) return Future.value(Right(cached));

    final inFlight = _provisionInFlight;
    if (inFlight != null) return inFlight;

    final future = _provisionSession(inviteCode: inviteCode).whenComplete(() {
      _provisionInFlight = null;
    });
    _provisionInFlight = future;
    return future;
  }

  @override
  Future<Either<SessionFailure, void>> logout() async {
    try {
      await _remoteDataSource.logout();
      return const Right(null);
    } on ApiException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return Left(_mapApiException(error));
    } on TimeoutException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể kết nối máy chủ. Kết nối quá thời gian chờ.'),
      );
    } on SocketException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.'),
      );
    } on http.ClientException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.'),
      );
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể đăng xuất khỏi máy chủ. Vui lòng thử lại.'),
      );
    } finally {
      clearCachedSession();
    }
  }

  @override
  void clearCachedSession() {
    _cacheGeneration++;
    _cachedSession = null;
    _provisionInFlight = null;
  }

  Future<Either<SessionFailure, BackendSession>> _provisionSession({
    String? inviteCode,
  }) async {
    // Hard cap on each datasource call so that a cold-start backend spin-up
    // (e.g. Railway.app free tier) never causes an ANR or blocks the auth flow.
    const perCallTimeout = Duration(seconds: 8);
    final generation = _cacheGeneration;
    try {
      final backendUser = await _remoteDataSource
          .login(inviteCode: inviteCode)
          .timeout(perCallTimeout);
      final household = await _remoteDataSource
          .getCurrentHousehold()
          .timeout(perCallTimeout);
      final session = BackendSession(
        backendUser: backendUser,
        household: household,
      );
      if (generation == _cacheGeneration) _cachedSession = session;
      return Right(session);
    } on TimeoutException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể kết nối máy chủ. Kết nối quá thời gian chờ.'),
      );
    } on ApiException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return Left(_mapApiException(error));
    } on SocketException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.'),
      );
    } on http.ClientException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.'),
      );
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể thiết lập tài khoản. Vui lòng thử lại.'),
      );
    }
  }

  SessionFailure _mapApiException(ApiException error) {
    return switch (error.kind) {
      ApiExceptionKind.configuration => SessionFailure(error.message),
      ApiExceptionKind.unauthorized => const SessionFailure(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      ),
      ApiExceptionKind.forbidden => const SessionFailure(
        'Tài khoản không có quyền truy cập dữ liệu này.',
      ),
      ApiExceptionKind.notFound => const SessionFailure(
        'Không tìm thấy thông tin tài khoản trên máy chủ.',
      ),
      ApiExceptionKind.badRequest => SessionFailure(error.message),
      ApiExceptionKind.invalidResponse => const SessionFailure(
        'Phản hồi máy chủ không hợp lệ.',
      ),
      ApiExceptionKind.server => const SessionFailure(
        'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.',
      ),
      ApiExceptionKind.unknown => const SessionFailure(
        'Không thể thiết lập tài khoản. Vui lòng thử lại.',
      ),
    };
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    developer.log(
      'Backend session request failed.',
      name: 'SessionRepository',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
