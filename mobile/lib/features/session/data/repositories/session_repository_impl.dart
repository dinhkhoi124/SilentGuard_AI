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
  static const _retryBackoffs = [
    // FIX: retry transient Render/network failures before surfacing them.
    Duration(seconds: 1), // FIX: first warm-up retry delay.
    Duration(seconds: 2), // FIX: second warm-up retry delay.
    Duration(seconds: 4), // FIX: final warm-up retry delay.
  ]; // FIX: cap retries to avoid an endless provision loop inside the repository.

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
  Future<Either<SessionFailure, void>> logout({String? idToken}) async {
    try {
      await _remoteDataSource.logout(idToken: idToken);
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
  Future<Either<SessionFailure, void>> switchHousehold(
    String householdId,
  ) async {
    try {
      await _remoteDataSource.switchHousehold(householdId);
      clearCachedSession();
      await provisionSession();
      return const Right(null);
    } on ApiException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return Left(_mapApiException(error));
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể chuyển hộ gia đình. Vui lòng thử lại.'),
      );
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
    final generation = _cacheGeneration;
    try {
      final session = await _provisionWithRetry(
        // FIX: retry backend cold-start failures before returning a failure.
        inviteCode: inviteCode,
      ); // FIX: keep the retry policy local to session provisioning.
      if (generation == _cacheGeneration) _cachedSession = session;
      return Right(session);
    } on TimeoutException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure(
          'Không thể kết nối máy chủ. Kết nối quá thời gian chờ.',
          kind: SessionFailureKind
              .backendUnavailable, // FIX: timeout means backend unavailable, not expired Firebase auth.
        ),
      );
    } on ApiException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return Left(_mapApiException(error));
    } on SocketException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure(
          'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
          kind: SessionFailureKind
              .backendUnavailable, // FIX: network failure should warm up/retry, not logout.
        ),
      );
    } on http.ClientException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure(
          'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
          kind: SessionFailureKind
              .backendUnavailable, // FIX: HTTP client failure is a backend availability path.
        ),
      );
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        SessionFailure('Không thể thiết lập tài khoản. Vui lòng thử lại.'),
      );
    }
  }

  Future<BackendSession> _provisionWithRetry({String? inviteCode}) async {
    for (var attempt = 0; attempt <= _retryBackoffs.length; attempt++) {
      // FIX: one initial attempt plus three retries.
      try {
        return await _runProvisionAttempt(
          inviteCode: inviteCode,
        ); // FIX: keep retry classification around the full backend session sync.
      } on Object catch (error, stackTrace) {
        if (!_isRetryableProvisionError(
              error,
            ) || // FIX: never retry definitive auth/config/client errors.
            attempt == _retryBackoffs.length) {
          // FIX: stop after the configured retry budget.
          Error.throwWithStackTrace(
            error,
            stackTrace,
          ); // FIX: preserve the original exception and stack for mapping/logging.
        }

        final delay =
            _retryBackoffs[attempt]; // FIX: exponential backoff for Render cold starts.
        developer.log(
          'Backend session provision retry scheduled in ${delay.inSeconds}s.',
          name: 'SessionRepository',
          error: error,
          stackTrace: stackTrace,
        );
        await Future<void>.delayed(
          delay,
        ); // FIX: avoid hammering a cold backend while it wakes up.
      }
    }

    throw TimeoutException(
      'Session provision retry budget exhausted.',
    ); // FIX: defensive fallback; loop normally returns or rethrows.
  }

  Future<BackendSession> _runProvisionAttempt({String? inviteCode}) async {
    final backendUser = await _remoteDataSource.login(
      inviteCode: inviteCode,
    ); // FIX: login uses its own 35s datasource timeout.
    final household = await _remoteDataSource
        .getCurrentHousehold(); // FIX: keep other API calls on their existing timeout.
    final session = BackendSession(
      backendUser: backendUser,
      household: household,
    );
    return session; // FIX: return the fully synced backend session only after both calls succeed.
  }

  bool _isRetryableProvisionError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return true; // FIX: network and timeout failures are transient backend availability problems.
    }
    if (error is ApiException) {
      return error.kind == ApiExceptionKind.server ||
          error.kind ==
              ApiExceptionKind
                  .unknown; // FIX: retry 5xx/unknown, but not 401/403.
    }
    return false; // FIX: avoid retrying programming/validation errors.
  }

  SessionFailure _mapApiException(ApiException error) {
    return switch (error.kind) {
      ApiExceptionKind.configuration => SessionFailure(error.message),
      ApiExceptionKind.unauthorized => const SessionFailure(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        kind:
            SessionFailureKind.unauthorized, // FIX: 401 is a real auth failure.
      ),
      ApiExceptionKind.forbidden => const SessionFailure(
        'Tài khoản không có quyền truy cập dữ liệu này.',
        kind: SessionFailureKind
            .forbidden, // FIX: 403 is definitive and must not be retried as warm-up.
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
        kind: SessionFailureKind
            .backendUnavailable, // FIX: 5xx is backend unavailable, not expired auth.
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
