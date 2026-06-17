import 'package:dartz/dartz.dart';
import 'package:mobile/features/session/domain/entities/backend_session.dart';
import 'package:mobile/features/session/domain/entities/household.dart';
import 'package:mobile/features/session/domain/failures/session_failure.dart';

abstract interface class SessionRepository {
  BackendSession? get currentSession;
  Household? get currentHousehold;
  String? get currentHouseholdId;

  Future<Either<SessionFailure, BackendSession>> provisionSession({
    String? inviteCode,
  });

  Future<Either<SessionFailure, void>> logout();

  void clearCachedSession();
}
