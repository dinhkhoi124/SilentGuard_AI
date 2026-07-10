import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/reports/domain/usecases/get_event_history.dart';
import 'package:mobile/features/reports/presentation/cubit/event_history_state.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class EventHistoryCubit extends Cubit<EventHistoryState> {
  EventHistoryCubit({
    required GetEventHistory getEventHistory,
    required SessionRepository sessionRepository,
  }) : _getEventHistory = getEventHistory,
       _sessionRepository = sessionRepository,
       super(const EventHistoryInitial());

  final GetEventHistory _getEventHistory;
  final SessionRepository _sessionRepository;

  String? _fromDate;
  String? _toDate;

  /// Loads the first page on screen entry.
  /// Reads [household_id] from the cached session — no extra network call.
  Future<void> loadInitial() async {
    final householdId = _sessionRepository.currentHouseholdId;
    if (householdId == null || householdId.isEmpty) {
      // Do not emit an error here; wait for session to become available.
      emit(const EventHistoryLoading());
      return;
    }

    emit(const EventHistoryLoading());
    await _fetch(householdId);
  }

  /// Silent refresh — keeps existing items visible while fetching.
  Future<void> refresh() async {
    final householdId = _sessionRepository.currentHouseholdId;
    if (householdId == null || householdId.isEmpty) return;

    final current = state;
    if (current is EventHistoryLoaded) {
      emit(current.copyWith(isRefreshing: true));
    }

    await _fetch(householdId);
  }

  /// Filters history by date range and reloads
  Future<void> filterByDate(String fromDate, String toDate) async {
    _fromDate = fromDate;
    _toDate = toDate;
    final householdId = _sessionRepository.currentHouseholdId;
    if (householdId == null || householdId.isEmpty) return;

    emit(const EventHistoryLoading());
    await _fetch(householdId);
  }

  Future<void> _fetch(String householdId) async {
    final result = await _getEventHistory(
      GetEventHistoryParams(
        householdId: householdId,
        fromDate: _fromDate,
        toDate: _toDate,
      ),
    );

    if (isClosed) return;

    result.fold((error) => emit(EventHistoryError(error)), (page) {
      if (page.items.isEmpty) {
        emit(const EventHistoryEmpty());
      } else {
        emit(EventHistoryLoaded(items: page.items));
      }
    });
  }
}
