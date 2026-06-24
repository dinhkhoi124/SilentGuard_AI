import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/presentation/cubit/camera_event_history_state.dart';
import 'package:mobile/features/reports/domain/usecases/get_event_history.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class CameraEventHistoryCubit extends Cubit<CameraEventHistoryState> {
  CameraEventHistoryCubit({
    required GetEventHistory getEventHistory,
    required SessionRepository sessionRepository,
  }) : _getEventHistory = getEventHistory,
       _sessionRepository = sessionRepository,
       super(const CameraEventHistoryInitial());

  final GetEventHistory _getEventHistory;
  final SessionRepository _sessionRepository;

  /// Loads all household events.
  ///
  /// TODO: Filter by camera_id when backend supports camera_id in GET /api/events/history.
  Future<void> loadForCamera(CameraDevice device) async {
    final householdId = _sessionRepository.currentHouseholdId;

    if (householdId == null || householdId.isEmpty) {
      emit(
        const CameraEventHistoryError(
          'Không thể xác định hộ gia đình. Vui lòng đăng nhập lại.',
        ),
      );
      return;
    }

    emit(const CameraEventHistoryLoading());

    final result = await _getEventHistory(
      GetEventHistoryParams(householdId: householdId, pageSize: 20),
    );

    if (isClosed) return;

    result.fold((error) => emit(CameraEventHistoryError(error)), (page) {
      if (page.items.isEmpty) {
        emit(const CameraEventHistoryEmpty());
      } else {
        emit(CameraEventHistoryLoaded(items: page.items));
      }
    });
  }

  /// Retries the last load for [device].
  Future<void> retry(CameraDevice device) => loadForCamera(device);
}
