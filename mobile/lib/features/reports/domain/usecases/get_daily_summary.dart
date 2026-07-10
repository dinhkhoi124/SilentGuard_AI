import 'package:dartz/dartz.dart';
import 'package:mobile/features/reports/domain/entities/daily_summary.dart';
import 'package:mobile/features/reports/domain/repositories/daily_summary_repository.dart';

class GetDailySummary {
  const GetDailySummary(this._repository);

  final DailySummaryRepository _repository;

  Future<Either<DailySummaryFailure, DailySummary>> call({
    required DateTime date,
    required String householdId,
  }) {
    return _repository.getDailySummary(date: date, householdId: householdId);
  }
}
