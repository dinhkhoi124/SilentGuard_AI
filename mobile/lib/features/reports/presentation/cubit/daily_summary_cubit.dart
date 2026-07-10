import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/reports/domain/repositories/daily_summary_repository.dart';
import 'package:mobile/features/reports/domain/usecases/get_daily_summary.dart';
import 'package:mobile/features/reports/domain/usecases/get_event_history.dart';
import 'package:mobile/features/reports/presentation/cubit/daily_summary_state.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class DailySummaryCubit extends Cubit<DailySummaryState> {
  DailySummaryCubit({
    required GetDailySummary getDailySummary,
    required GetEventHistory getEventHistory,
    required SessionRepository sessionRepository,
  }) : _getDailySummary = getDailySummary,
       _getEventHistory = getEventHistory,
       _sessionRepository = sessionRepository,
       super(const DailySummaryInitial());

  final GetDailySummary _getDailySummary;
  final GetEventHistory _getEventHistory;
  final SessionRepository _sessionRepository;

  DateTime _selectedDate = _dateOnly(DateTime.now());

  Future<void> loadInitial() {
    return dailySummaryDateChanged(_selectedDate);
  }

  Future<void> dailySummaryDateChanged(DateTime date) async {
    _selectedDate = _dateOnly(date);
    emit(DailySummaryLoading(_selectedDate));

    final householdId = _sessionRepository.currentHouseholdId;
    if (householdId == null || householdId.isEmpty) {
      return;
    }

    final result = await _getDailySummary(
      date: _selectedDate,
      householdId: householdId,
    );
    if (isClosed) return;

    await result.fold(_handleFailure, (summary) async {
      if (summary.events.isEmpty && summary.summary.trim().isEmpty) {
        emit(DailySummaryEmpty(_selectedDate));
        return;
      }
      emit(DailySummaryLoaded(summary));
    });
  }

  Future<void> dailySummaryRefreshed() {
    return dailySummaryDateChanged(_selectedDate);
  }

  Future<void> dailySummaryRetryRequested() {
    return dailySummaryDateChanged(_selectedDate);
  }

  Future<void> _handleFailure(DailySummaryFailure failure) async {
    switch (failure) {
      case DailySummaryPendingFailure():
        await _handlePendingSummary();
      case DailySummaryErrorFailure(:final message):
        emit(DailySummaryError(message: message, date: _selectedDate));
    }
  }

  Future<void> _handlePendingSummary() async {
    final householdId = _sessionRepository.currentHouseholdId;
    if (householdId == null || householdId.isEmpty) {
      emit(
        DailySummaryError(
          message: 'Chưa tìm thấy hộ gia đình hiện tại. Vui lòng thử lại sau.',
          date: _selectedDate,
        ),
      );
      return;
    }

    final dateText = _formatDate(_selectedDate);
    final historyResult = await _getEventHistory(
      GetEventHistoryParams(
        householdId: householdId,
        pageSize: 50,
        fromDate: dateText,
        toDate: dateText,
      ),
    );
    if (isClosed) return;

    historyResult.fold(
      (message) =>
          emit(DailySummaryError(message: message, date: _selectedDate)),
      (page) {
        if (page.items.isEmpty) {
          emit(DailySummaryEmpty(_selectedDate));
          return;
        }
        if (_isToday(_selectedDate)) {
          emit(
            DailySummaryPendingGeneration(
              todayEvents: page.items,
              date: _selectedDate,
            ),
          );
          return;
        }
        emit(
          DailySummaryError(
            message: 'Chưa có báo cáo AI cho ngày này. Vui lòng thử lại sau.',
            date: _selectedDate,
          ),
        );
      },
    );
  }

  static bool _isToday(DateTime date) {
    return _dateOnly(date) == _dateOnly(DateTime.now());
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _formatDate(DateTime date) {
    final normalized = _dateOnly(date);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}
