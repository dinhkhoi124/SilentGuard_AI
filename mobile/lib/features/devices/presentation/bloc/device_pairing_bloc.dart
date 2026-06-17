import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/devices/domain/entities/device_credentials.dart';
import 'package:mobile/features/devices/domain/entities/onvif_discovery_result.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_event.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_state.dart';

class DevicePairingBloc extends Bloc<DevicePairingEvent, DevicePairingState> {
  DevicePairingBloc({required DeviceRepository deviceRepository})
    : _deviceRepository = deviceRepository,
      super(const DevicePairingInitial()) {
    on<DevicePairingStarted>(_onStarted);
    on<DevicePairingRetryRequested>(_onRetryRequested);
    on<DevicePairingOpenSettingsRequested>(_onOpenSettingsRequested);
    on<DevicePairingGalleryQrRequested>(_onGalleryQrRequested);
    on<DevicePairingLiveQrDetected>(_onLiveQrDetected);
    on<DevicePairingCredentialsSubmitted>(_onCredentialsSubmitted);
  }

  final DeviceRepository _deviceRepository;

  Future<void> _onStarted(
    DevicePairingStarted event,
    Emitter<DevicePairingState> emit,
  ) async {
    emit(const DevicePairingInitial());
    final result = await _deviceRepository.requestCameraPermission();
    result.fold(
      (failure) => emit(DevicePairingError(failure)),
      (granted) => emit(
        granted
            ? const DevicePairingScanning()
            : const DevicePairingPermissionDenied(
                'Cần quyền camera để quét mã QR trên thiết bị.',
              ),
      ),
    );
  }

  void _onRetryRequested(
    DevicePairingRetryRequested event,
    Emitter<DevicePairingState> emit,
  ) {
    add(const DevicePairingStarted());
  }

  Future<void> _onOpenSettingsRequested(
    DevicePairingOpenSettingsRequested event,
    Emitter<DevicePairingState> emit,
  ) async {
    await _deviceRepository.openAppSettings();
  }

  Future<void> _onGalleryQrRequested(
    DevicePairingGalleryQrRequested event,
    Emitter<DevicePairingState> emit,
  ) async {
    final permissionResult = await _deviceRepository
        .requestPhotoLibraryPermission();
    final permissionGranted = _valueOrError(
      permissionResult,
      (failure) => emit(DevicePairingError(failure)),
    );
    if (permissionGranted == null) return;
    if (!permissionGranted) {
      emit(
        const DevicePairingPermissionDenied(
          'Cần quyền thư viện ảnh để chọn ảnh mã QR.',
        ),
      );
      return;
    }

    final imageResult = await _deviceRepository.pickQrImagePath();
    String? imagePath;
    var pickFailed = false;
    imageResult.fold((failure) {
      pickFailed = true;
      emit(DevicePairingError(failure));
    }, (path) => imagePath = path);
    if (pickFailed) return;
    if (imagePath == null) {
      emit(const DevicePairingScanning());
      return;
    }

    emit(const DevicePairingResolving());
    final qrResult = await _deviceRepository.decodeQrImageFile(imagePath!);
    final rawQr = _valueOrError(
      qrResult,
      (failure) => emit(DevicePairingError(failure)),
    );
    if (rawQr == null) return;
    await _pairDevice(rawQr: rawQr, emit: emit);
  }

  Future<void> _onLiveQrDetected(
    DevicePairingLiveQrDetected event,
    Emitter<DevicePairingState> emit,
  ) async {
    if (state is! DevicePairingScanning) return;
    await _pairDevice(rawQr: event.rawQr, emit: emit);
  }

  Future<void> _onCredentialsSubmitted(
    DevicePairingCredentialsSubmitted event,
    Emitter<DevicePairingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! DevicePairingCredentialsRequired) return;

    final credentials = DeviceCredentials(
      username: event.username.trim(),
      password: event.password,
    );
    if (credentials.username.isEmpty) {
      emit(
        DevicePairingCredentialsRequired(
          resolvedDevice: currentState.resolvedDevice,
          discoveryResult: currentState.discoveryResult,
          message: 'Vui lòng nhập tài khoản ONVIF của camera.',
        ),
      );
      return;
    }

    await _obtainStreamAndPersist(
      resolvedDevice: currentState.resolvedDevice,
      discoveryResult: currentState.discoveryResult,
      credentials: credentials,
      emit: emit,
    );
  }

  Future<void> _pairDevice({
    required String rawQr,
    required Emitter<DevicePairingState> emit,
  }) async {
    emit(const DevicePairingResolving());
    final resolvedResult = await _deviceRepository.resolveDeviceQr(rawQr);
    final resolvedDevice = _valueOrError(
      resolvedResult,
      (failure) => emit(DevicePairingError(failure)),
    );
    if (resolvedDevice == null) return;

    emit(DevicePairingDiscovering(resolvedDevice: resolvedDevice));
    final discoveryResult = await _deviceRepository.discoverOnvifDevices();
    final discoveredDevices = _valueOrError(
      discoveryResult,
      (failure) => emit(DevicePairingError(failure)),
    );
    if (discoveredDevices == null) return;
    if (discoveredDevices.isEmpty) {
      emit(
        const DevicePairingError(
          'Không tìm thấy camera ONVIF nào trên mạng nội bộ.',
        ),
      );
      return;
    }

    emit(
      DevicePairingMatching(
        resolvedDevice: resolvedDevice,
        discoveredDevices: discoveredDevices,
      ),
    );
    final matchResult = await _deviceRepository.matchDiscoveredDevice(
      devices: discoveredDevices,
      serialNumber: resolvedDevice.serialNumber,
    );
    final matchedDevice = _valueOrError(
      matchResult,
      (failure) => emit(DevicePairingError(failure)),
    );
    if (matchedDevice == null) return;

    await _obtainStreamAndPersist(
      resolvedDevice: resolvedDevice,
      discoveryResult: matchedDevice,
      emit: emit,
    );
  }

  Future<void> _obtainStreamAndPersist({
    required ResolvedDevice resolvedDevice,
    required OnvifDiscoveryResult discoveryResult,
    DeviceCredentials? credentials,
    required Emitter<DevicePairingState> emit,
  }) async {
    emit(
      DevicePairingObtainingStream(
        resolvedDevice: resolvedDevice,
        discoveryResult: discoveryResult,
      ),
    );

    final rtspResult = await _deviceRepository.getRtspStreamUri(
      device: discoveryResult,
      credentials: credentials,
    );
    String? rtspUrl;
    var failedMessage = '';
    rtspResult.fold(
      (failure) => failedMessage = failure,
      (url) => rtspUrl = url,
    );

    if (rtspUrl == null) {
      if (credentials == null) {
        emit(
          DevicePairingCredentialsRequired(
            resolvedDevice: resolvedDevice,
            discoveryResult: discoveryResult,
            message: failedMessage.isEmpty
                ? 'Camera yêu cầu tài khoản ONVIF.'
                : failedMessage,
          ),
        );
      } else {
        emit(DevicePairingError(failedMessage));
      }
      return;
    }

    emit(
      DevicePairingPersisting(
        resolvedDevice: resolvedDevice,
        discoveryResult: discoveryResult,
        rtspUrl: rtspUrl!,
      ),
    );
    final saveResult = await _deviceRepository.savePairedDevice(
      resolvedDevice: resolvedDevice,
      ipAddress: discoveryResult.ipAddress,
      rtspUrl: rtspUrl!,
    );
    final pairedDevice = _valueOrError(
      saveResult,
      (failure) => emit(DevicePairingError(failure)),
    );
    if (pairedDevice == null) return;

    emit(DevicePairingSuccess(pairedDevice));
  }

  T? _valueOrError<T>(
    Either<String, T> result,
    void Function(String failure) onFailure,
  ) {
    T? value;
    result.fold(onFailure, (right) => value = right);
    return value;
  }
}
