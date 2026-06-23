import 'dart:async'; // FIX: HomeBloc needs a timer for silent backend warm-up retries.
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/usecases/delete_camera_device.dart';
import 'package:mobile/features/home/domain/usecases/get_camera_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';
import 'package:mobile/features/session/domain/failures/session_failure.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required this.getWeather,
    required this.getCameraDevices,
    required this.deleteCameraDevice,
    required this.sessionRepository,
  }) : super(const HomeInitial()) {
    on<HomeStarted>((event, emit) => _loadHome(emit));
    on<HomeRetryRequested>(
      (event, emit) => _loadHome(
        emit,
        silent: event.silent,
      ), // FIX: silent retries keep the warming-up UI stable.
    );
    on<RoomFilterChanged>(_onRoomFilterChanged);
    on<AddDeviceTapped>(_onAddDeviceTapped);
    on<HomeDeviceDeleted>(_onDeviceDeleted);
    on<HomeDevicePaired>(_onDevicePaired);
    on<CameraThumbnailCaptured>(_onCameraThumbnailCaptured);
    on<HomeAccessoryToggled>(_onAccessoryToggled);
    on<NotificationTapped>((event, emit) {});
  }

  final GetWeather getWeather;
  final GetCameraDevices getCameraDevices;
  final DeleteCameraDevice deleteCameraDevice;
  final SessionRepository
  sessionRepository; // FIX: Home reads the session cache populated by AuthNotifier.
  List<CameraDevice> _activeDevices = [];
  int _loadGeneration = 0;
  Timer?
  _backendRetryTimer; // FIX: auto-retry backend availability without user interaction.

  Future<void> _loadHome(
    Emitter<HomeState> emit, {
    bool silent =
        false, // FIX: backend warm-up retries should not replace the warming UI with HomeLoading.
  }) async {
    final generation = ++_loadGeneration;
    _backendRetryTimer
        ?.cancel(); // FIX: each load attempt owns the next retry decision.
    _backendRetryTimer = null; // FIX: prevent duplicate retry timers.
    if (!silent) {
      emit(
        const HomeLoading(),
      ); // FIX: manual loads still show the normal loading state.
    }

    final sessionReady = await _ensureSessionReady(emit);
    if (!sessionReady || generation != _loadGeneration) {
      return; // FIX: stop before data calls when backend session is still warming or auth failed.
    }

    final weatherFuture = getWeather();
    final deviceResult = await getCameraDevices();
    var devicesLoaded = false;
    deviceResult.fold(
      (failure) {
        if (_isBackendUnavailable(failure)) {
          // FIX: network/timeout/5xx should warm up and auto-retry.
          emit(const HomeBackendWarmingUp()); // FIX: show non-error waiting UI.
          _scheduleBackendRetry(); // FIX: retry every 5 seconds silently.
          return;
        }
        if (_isUnauthorized(failure)) {
          // FIX: only definitive auth failures show session-expired UI.
          emit(HomeUnauthorized(failure));
          return;
        }
        emit(
          HomeError(failure),
        ); // FIX: preserve generic error handling for non-auth/non-warm-up failures.
      },
      (devices) {
        devicesLoaded = true;
        _activeDevices = List.of(devices);
        emit(
          HomeLoaded(
            weather: null,
            devices: List.unmodifiable(_activeDevices),
            selectedRoom: 'All Rooms',
          ),
        );
      },
    );

    if (!devicesLoaded || generation != _loadGeneration) return;

    final weatherResult = await weatherFuture;
    if (generation != _loadGeneration) return;

    weatherResult.fold((_) {}, (weather) {
      if (weather == null) return;
      final currentState = state;
      if (currentState is! HomeLoaded) return;
      emit(currentState.copyWith(weather: weather));
    });
  }

  Future<bool> _ensureSessionReady(Emitter<HomeState> emit) async {
    if (sessionRepository.currentSession != null) {
      return true; // FIX: cached session is enough; do not call backend login again.
    }

    final sessionResult = await sessionRepository
        .provisionSession(); // FIX: reuse the repository in-flight login instead of starting a second round-trip.
    var sessionReady = false;
    sessionResult.fold(
      (failure) {
        if (failure.kind == SessionFailureKind.backendUnavailable) {
          emit(
            const HomeBackendWarmingUp(),
          ); // FIX: Render cold start is a waiting state, not session expiration.
          _scheduleBackendRetry(); // FIX: retry every 5 seconds silently while backend wakes.
          return;
        }
        if (failure.kind == SessionFailureKind.unauthorized ||
            failure.kind == SessionFailureKind.forbidden) {
          emit(
            HomeUnauthorized(failure.message),
          ); // FIX: only 401/403 should show the expired-session UI.
          return;
        }
        emit(
          HomeError(failure.message),
        ); // FIX: non-auth/non-warm-up session failures remain generic errors.
      },
      (_) {
        sessionReady =
            true; // FIX: cache is now populated for downstream home usecases.
      },
    );
    return sessionReady;
  }

  void _scheduleBackendRetry() {
    if (_backendRetryTimer?.isActive ?? false) {
      return; // FIX: avoid stacking retries while backend is cold.
    }
    _backendRetryTimer = Timer(const Duration(seconds: 5), () {
      // FIX: auto-retry backend warm-up every 5 seconds.
      add(
        const HomeRetryRequested(silent: true),
      ); // FIX: retry without showing a dismissable error or button.
    });
  }

  bool _isBackendUnavailable(String failure) {
    final normalized = failure.toLowerCase();
    return normalized.contains(
          'máy chủ đang gặp lỗi',
        ) || // FIX: classify 5xx as backend unavailable.
        normalized.contains('may chu dang gap loi') ||
        normalized.contains(
          'không thể kết nối',
        ) || // FIX: classify network errors as backend unavailable.
        normalized.contains('khong the ket noi') ||
        normalized.contains(
          'quá thời gian',
        ) || // FIX: classify timeout as backend unavailable.
        normalized.contains('qua thoi gian') ||
        normalized.contains('network') ||
        normalized.contains('timeout');
  }

  bool _isUnauthorized(String failure) {
    final normalized = failure.toLowerCase();
    return normalized.contains(
          'phiên đăng nhập',
        ) || // FIX: classify localized session-expired failures as unauthorized.
        normalized.contains('phien dang nhap') ||
        normalized.contains('chưa được thiết lập') ||
        normalized.contains('chua duoc thiet lap') ||
        normalized.contains('unauthorized') ||
        normalized.contains('401') ||
        normalized.contains('403');
  }

  void _onRoomFilterChanged(RoomFilterChanged event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    emit(currentState.copyWith(selectedRoom: event.roomName));
  }

  void _onAddDeviceTapped(AddDeviceTapped event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    emit(currentState.copyWith(openPairingFlow: true));
    emit(currentState.copyWith(openPairingFlow: false));
  }

  Future<void> _onDeviceDeleted(
    HomeDeviceDeleted event,
    Emitter<HomeState> emit,
  ) async {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    final result = await deleteCameraDevice(event.deviceId);
    var failed = false;
    result.fold((failure) {
      failed = true;
      emit(HomeError(failure));
    }, (_) {});
    if (failed) return;

    _activeDevices = _activeDevices
        .where((device) => device.id != event.deviceId)
        .toList();
    final thumbnails = Map<String, Uint8List>.of(currentState.cameraThumbnails)
      ..remove(event.deviceId);
    emit(
      currentState.copyWith(
        devices: List.unmodifiable(_activeDevices),
        cameraThumbnails: thumbnails,
      ),
    );
  }

  void _onDevicePaired(HomeDevicePaired event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    final deviceIndex = _activeDevices.indexWhere(
      (device) => device.id == event.device.id,
    );
    if (deviceIndex == -1) {
      _activeDevices = [..._activeDevices, event.device];
    } else {
      _activeDevices = List.of(_activeDevices);
      _activeDevices[deviceIndex] = event.device;
    }
    emit(currentState.copyWith(devices: List.unmodifiable(_activeDevices)));
  }

  void _onCameraThumbnailCaptured(
    CameraThumbnailCaptured event,
    Emitter<HomeState> emit,
  ) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    emit(
      currentState.copyWith(
        cameraThumbnails: {
          ...currentState.cameraThumbnails,
          event.deviceId: event.bytes,
        },
      ),
    );
  }

  void _onAccessoryToggled(
    HomeAccessoryToggled event,
    Emitter<HomeState> emit,
  ) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    final deviceIndex = _activeDevices.indexWhere(
      (device) => device.id == event.deviceId,
    );
    if (deviceIndex == -1) return;

    final device = _activeDevices[deviceIndex];
    if (event.accessoryIndex < 0 ||
        event.accessoryIndex >= device.accessoryStates.length) {
      return;
    }

    final states = List<bool>.of(device.accessoryStates);
    states[event.accessoryIndex] = !states[event.accessoryIndex];
    _activeDevices = List.of(_activeDevices);
    _activeDevices[deviceIndex] = device.copyWith(accessoryStates: states);
    emit(currentState.copyWith(devices: List.unmodifiable(_activeDevices)));
  }

  @override
  Future<void> close() {
    _backendRetryTimer
        ?.cancel(); // FIX: stop silent retries when HomeBloc is disposed.
    return super.close();
  }
}
