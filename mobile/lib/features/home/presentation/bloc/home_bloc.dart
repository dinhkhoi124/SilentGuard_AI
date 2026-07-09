import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/devices/data/models/imou_models.dart';
import 'package:mobile/features/devices/domain/repositories/imou_stream_repository.dart';
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
    required this.imouStreamRepository,
  }) : super(const HomeInitial()) {
    // Đăng ký các sự kiện (events) với các hàm xử lý tương ứng
    on<HomeStarted>((event, emit) => _loadHome(emit));
    on<HomeRetryRequested>(
      (event, emit) => _loadHome(emit, silent: event.silent),
    );
    on<RoomFilterChanged>(_onRoomFilterChanged);
    on<AddDeviceTapped>(_onAddDeviceTapped);
    on<HomeDeviceDeleted>(_onDeviceDeleted);
    on<HomeDevicePaired>(_onDevicePaired);
    on<CameraThumbnailCaptured>(_onCameraThumbnailCaptured);
    on<ResetCameraStreamUrlEvent>(_onResetCameraStreamUrl);
    on<CameraStreamUrlRequested>(_onCameraStreamUrlRequested);
    on<CameraDetailClosed>(_onCameraDetailClosed);
    on<CameraStreamPlaybackFailed>(_onCameraStreamPlaybackFailed);
    on<HomeAccessoryToggled>(_onAccessoryToggled);
    on<NotificationTapped>((event, emit) {});
  }

  final GetWeather getWeather;
  final GetCameraDevices getCameraDevices;
  final DeleteCameraDevice deleteCameraDevice;
  final ImouStreamRepository imouStreamRepository;
  final SessionRepository sessionRepository;

  String? lastKnownStreamUrl;
  List<CameraDevice> _activeDevices = [];
  int _loadGeneration = 0;
  Timer? _backendRetryTimer;
  final Map<String, int> _streamRequestGenerations = {};
  final Set<String> _closedStreamSerials = {};

  /// Tải dữ liệu chính cho trang chủ bao gồm thời tiết, danh sách camera, và kiểm tra session
  Future<void> _loadHome(Emitter<HomeState> emit, {bool silent = false}) async {
    final generation = ++_loadGeneration;
    _backendRetryTimer?.cancel();
    _backendRetryTimer = null;

    if (!silent) {
      emit(const HomeLoading());
    }

    final sessionReady = await _ensureSessionReady(emit);
    if (!sessionReady || generation != _loadGeneration) {
      return;
    }

    final weatherFuture = getWeather();
    final deviceResult = await getCameraDevices();
    var devicesLoaded = false;

    deviceResult.fold(
      (failure) {
        if (_isBackendUnavailable(failure)) {
          emit(const HomeBackendWarmingUp());
          _scheduleBackendRetry();
          return;
        }
        if (_isUnauthorized(failure)) {
          emit(HomeUnauthorized(failure));
          return;
        }
        emit(HomeError(failure));
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

  /// Đảm bảo phiên đăng nhập với backend đã sẵn sàng
  Future<bool> _ensureSessionReady(Emitter<HomeState> emit) async {
    if (sessionRepository.currentSession != null) {
      return true;
    }

    final sessionResult = await sessionRepository.provisionSession();
    var sessionReady = false;

    sessionResult.fold(
      (failure) {
        if (failure.kind == SessionFailureKind.backendUnavailable) {
          emit(const HomeBackendWarmingUp());
          _scheduleBackendRetry();
          return;
        }
        if (failure.kind == SessionFailureKind.unauthorized ||
            failure.kind == SessionFailureKind.forbidden) {
          emit(HomeUnauthorized(failure.message));
          return;
        }
        emit(HomeError(failure.message));
      },
      (_) {
        sessionReady = true;
      },
    );
    return sessionReady;
  }

  /// Lên lịch thử lại (retry) khi backend chưa sẵn sàng
  void _scheduleBackendRetry() {
    if (_backendRetryTimer?.isActive ?? false) {
      return;
    }
    _backendRetryTimer = Timer(const Duration(seconds: 5), () {
      add(const HomeRetryRequested(silent: true));
    });
  }

  /// Kiểm tra xem lỗi có phải do máy chủ không phản hồi hay không
  bool _isBackendUnavailable(String failure) {
    final normalized = failure.toLowerCase();
    return normalized.contains('máy chủ đang gặp lỗi') ||
        normalized.contains('may chu dang gap loi') ||
        normalized.contains('không thể kết nối') ||
        normalized.contains('khong the ket noi') ||
        normalized.contains('quá thời gian') ||
        normalized.contains('qua thoi gian') ||
        normalized.contains('network') ||
        normalized.contains('timeout');
  }

  /// Kiểm tra xem lỗi có phải do chưa xác thực / hết phiên đăng nhập hay không
  bool _isUnauthorized(String failure) {
    final normalized = failure.toLowerCase();
    return normalized.contains('phiên đăng nhập') ||
        normalized.contains('phien dang nhap') ||
        normalized.contains('chưa được thiết lập') ||
        normalized.contains('chua duoc thiet lap') ||
        normalized.contains('unauthorized') ||
        normalized.contains('401') ||
        normalized.contains('403');
  }

  /// Xử lý sự kiện khi người dùng thay đổi bộ lọc phòng
  void _onRoomFilterChanged(RoomFilterChanged event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    emit(currentState.copyWith(selectedRoom: event.roomName));
  }

  /// Xử lý sự kiện khi bấm nút thêm thiết bị mới
  void _onAddDeviceTapped(AddDeviceTapped event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    emit(currentState.copyWith(openPairingFlow: true));
    emit(currentState.copyWith(openPairingFlow: false));
  }

  /// Xử lý xoá thiết bị camera
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

  /// Cập nhật lại danh sách sau khi thiết bị mới được ghép nối
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

  /// Xử lý sự kiện khi chụp và lưu trữ ảnh thumbnail của camera
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

  /// Yêu cầu lấy URL luồng phát trực tiếp (live stream) từ dịch vụ Imou
  void _onResetCameraStreamUrl(
    ResetCameraStreamUrlEvent event,
    Emitter<HomeState> emit,
  ) {
    emit(const CameraStreamUrlInitial());
  }

  Future<void> _onCameraStreamUrlRequested(
    CameraStreamUrlRequested event,
    Emitter<HomeState> emit,
  ) async {
    debugPrint(
      '[HomeBloc] state reset to initial? ${state is HomeInitial} '
      'currentState: ${state.runtimeType}',
    );
    final serialNumber = event.serialNumber.trim();
    if (serialNumber.isEmpty) {
      emit(
        CameraStreamUrlFailure(
          cameraId: event.cameraId,
          message: 'Không tìm thấy mã thiết bị để lấy luồng phát.',
        ),
      );
      return;
    }

    final requestGeneration =
        (_streamRequestGenerations[serialNumber] ?? 0) + 1;
    _streamRequestGenerations[serialNumber] = requestGeneration;
    _closedStreamSerials.remove(serialNumber);

    emit(CameraStreamUrlLoading(event.cameraId));
    try {
      final streamUrl = await imouStreamRepository.getStreamUrl(serialNumber);
      if (_isStreamRequestStale(serialNumber, requestGeneration)) {
        debugPrint(
          '[HomeBloc] ignored stale stream URL for serial=${_maskSerial(serialNumber)}',
        );
        return;
      }
      final trimmedUrl = streamUrl.trim();
      if (!_isPlayableCloudUrl(trimmedUrl)) {
        emit(
          CameraStreamUrlFailure(
            cameraId: event.cameraId,
            message:
                'Không tìm thấy luồng trực tiếp tương thích từ Imou Cloud. Vui lòng thử lại sau.',
          ),
        );
        return;
      }
      lastKnownStreamUrl = trimmedUrl;
      emit(
        CameraStreamUrlLoaded(cameraId: event.cameraId, streamUrl: trimmedUrl),
      );
    } on LiveStartCancelledException catch (error) {
      debugPrint('[HomeBloc] stream request cancelled: $error');
      if (!_isStreamRequestStale(serialNumber, requestGeneration)) {
        emit(const CameraStreamUrlInitial());
      }
    } on ImouApiException catch (error) {
      if (_isStreamRequestStale(serialNumber, requestGeneration)) return;
      emit(
        CameraStreamUrlFailure(
          cameraId: event.cameraId,
          message: _messageForImouStreamError(error),
        ),
      );
    } catch (error) {
      debugPrint('[HomeBloc] stream request failed: $error');
      if (_isStreamRequestStale(serialNumber, requestGeneration)) return;
      emit(
        CameraStreamUrlFailure(
          cameraId: event.cameraId,
          message:
              'Không thể lấy luồng trực tiếp từ Imou Cloud. Vui lòng thử lại sau.',
        ),
      );
    }
  }

  Future<void> _onCameraDetailClosed(
    CameraDetailClosed event,
    Emitter<HomeState> emit,
  ) async {
    final serialNumber = event.serialNumber.trim();
    if (serialNumber.isEmpty) return;

    _closedStreamSerials.add(serialNumber);
    _streamRequestGenerations[serialNumber] =
        (_streamRequestGenerations[serialNumber] ?? 0) + 1;
    debugPrint(
      '[HomeBloc] camera detail closed, stream request generation invalidated '
      'serial=${_maskSerial(serialNumber)}',
    );
    lastKnownStreamUrl = null;
    try {
      await imouStreamRepository.releaseStreamSession(serialNumber);
    } catch (error) {
      debugPrint('[HomeBloc] release stream session failed: $error');
    }
  }

  void _onCameraStreamPlaybackFailed(
    CameraStreamPlaybackFailed event,
    Emitter<HomeState> emit,
  ) {
    debugPrint('[HomeBloc] playback failed: ${event.error}');
    emit(
      CameraPlaybackFailure(
        cameraId: event.cameraId,
        message: 'Không phát được livestream sau nhiều lần thử.',
        error: event.error,
      ),
    );
  }

  String _messageForImouStreamError(ImouApiException error) {
    return switch (error.code) {
      'DEVICE_OFFLINE' =>
        'Camera đang offline. Vui lòng kiểm tra kết nối thiết bị.',
      'NO_STREAM_URL' => 'Không lấy được stream. Vui lòng thử lại.',
      '12012' => 'Mất kết nối internet (Camera không phản hồi).',
      _ => 'Lỗi kết nối: ${error.message}',
    };
  }

  bool _isPlayableCloudUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;

    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8') || path.endsWith('.flv');
  }

  bool _isStreamRequestStale(String serialNumber, int requestGeneration) {
    return _closedStreamSerials.contains(serialNumber) ||
        _streamRequestGenerations[serialNumber] != requestGeneration;
  }

  String _maskSerial(String serialNumber) {
    final value = serialNumber.trim();
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }

  /// Chuyển đổi trạng thái bật/tắt (toggle) của các phụ kiện đi kèm camera
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

  /// Hủy và dọn dẹp các tài nguyên (như timer) khi bloc đóng
  @override
  Future<void> close() {
    _backendRetryTimer?.cancel();
    return super.close();
  }
}
