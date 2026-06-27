import 'package:dartz/dartz.dart';
import 'package:mobile/features/reports/domain/entities/event_history_page.dart';
import 'package:mobile/features/reports/domain/repositories/event_history_repository.dart';

class GetEventHistoryParams {
  const GetEventHistoryParams({
    required this.householdId,
    this.page = 1,
    this.pageSize = 20,
    this.severity,
    this.room,
    this.fromDate,
    this.toDate,
  });

  final String householdId;
  final int page;
  final int pageSize;
  final String? severity;
  final String? room;
  final String? fromDate;
  final String? toDate;
}

class GetEventHistory {
  const GetEventHistory(this._repository);

  final EventHistoryRepository _repository;

  Future<Either<String, EventHistoryPage>> call(GetEventHistoryParams params) {
    return _repository.getHistory(
      householdId: params.householdId,
      page: params.page,
      pageSize: params.pageSize,
      severity: params.severity,
      room: params.room,
      fromDate: params.fromDate,
      toDate: params.toDate,
    );
  }
}
