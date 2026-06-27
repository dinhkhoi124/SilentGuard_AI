import 'package:dartz/dartz.dart';
import 'package:mobile/features/reports/domain/entities/event_history_page.dart';

abstract interface class EventHistoryRepository {
  Future<Either<String, EventHistoryPage>> getHistory({
    required String householdId,
    int page = 1,
    int pageSize = 20,
    String? severity,
    String? room,
    String? fromDate,
    String? toDate,
  });
}
