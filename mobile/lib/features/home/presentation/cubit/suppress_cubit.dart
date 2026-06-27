import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';

sealed class SuppressState {
  const SuppressState();
}

final class SuppressInitial extends SuppressState {
  const SuppressInitial();
}

final class SuppressLoading extends SuppressState {
  const SuppressLoading();
}

final class SuppressActive extends SuppressState {
  const SuppressActive({required this.cameraId, required this.suppressedUntil});

  final String cameraId;
  final DateTime suppressedUntil;
}

final class SuppressInactive extends SuppressState {
  const SuppressInactive({required this.cameraId});

  final String cameraId;
}

final class SuppressFailure extends SuppressState {
  const SuppressFailure({required this.cameraId, required this.message});

  final String cameraId;
  final String message;
}

class SuppressCubit extends Cubit<SuppressState> {
  SuppressCubit(this._service) : super(const SuppressInitial());

  final MonitoringSuppressService _service;
  Timer? _countdownTimer;

  Future<void> loadState(String cameraId) async {
    _countdownTimer?.cancel();
    emit(const SuppressLoading());

    try {
      final suppressedUntil = await _service.getSuppressedUntil(cameraId);
      if (isClosed) return;

      if (suppressedUntil == null) {
        emit(SuppressInactive(cameraId: cameraId));
        return;
      }

      _emitActive(cameraId, suppressedUntil);
    } catch (_) {
      if (!isClosed) {
        emit(
          SuppressFailure(
            cameraId: cameraId,
            message: 'Không thể đọc trạng thái tạm dừng.',
          ),
        );
      }
    }
  }

  Future<void> pauseMonitoring(String cameraId, int durationMinutes) async {
    emit(const SuppressLoading());
    try {
      await _service.suppress(cameraId, durationMinutes);
      if (isClosed) return;

      final suppressedUntil = await _service.getSuppressedUntil(cameraId);
      if (isClosed) return;
      if (suppressedUntil == null) {
        emit(SuppressInactive(cameraId: cameraId));
        return;
      }

      _emitActive(cameraId, suppressedUntil);
    } catch (_) {
      if (!isClosed) {
        emit(
          SuppressFailure(
            cameraId: cameraId,
            message: 'Không thể tạm dừng thông báo. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  Future<void> resumeMonitoring(String cameraId) async {
    _countdownTimer?.cancel();
    emit(const SuppressLoading());
    try {
      await _service.resume(cameraId);
      if (!isClosed) emit(SuppressInactive(cameraId: cameraId));
    } catch (_) {
      if (!isClosed) {
        emit(
          SuppressFailure(
            cameraId: cameraId,
            message: 'Không thể tiếp tục thông báo. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  void _emitActive(String cameraId, DateTime suppressedUntil) {
    emit(SuppressActive(cameraId: cameraId, suppressedUntil: suppressedUntil));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) return;
      final remaining = suppressedUntil.difference(DateTime.now().toUtc());
      if (remaining <= Duration.zero) {
        _countdownTimer?.cancel();
        unawaited(loadState(cameraId));
        return;
      }
      emit(
        SuppressActive(cameraId: cameraId, suppressedUntil: suppressedUntil),
      );
    });
  }

  @override
  Future<void> close() async {
    _countdownTimer?.cancel();
    return super.close();
  }
}
