import 'package:dartz/dartz.dart';
import 'package:mobile/features/reports/domain/entities/daily_summary.dart';

sealed class DailySummaryFailure {
  const DailySummaryFailure();
}

final class DailySummaryPendingFailure extends DailySummaryFailure {
  const DailySummaryPendingFailure();
}

final class DailySummaryErrorFailure extends DailySummaryFailure {
  const DailySummaryErrorFailure(this.message);

  final String message;
}

abstract interface class DailySummaryRepository {
  Future<Either<DailySummaryFailure, DailySummary>> getDailySummary({
    required DateTime date,
    required String householdId,
  });
}
