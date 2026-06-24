import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/devices/domain/entities/imou_device_status.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';
import 'package:mobile/features/devices/domain/failures/imou_stream_failure.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:mobile/features/devices/domain/repositories/imou_stream_repository.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_event.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_state.dart';
import 'package:mobile/features/devices/domain/utils/qr_parser.dart';

class DevicePairingBloc extends Bloc<DevicePairingEvent, DevicePairingState> {
  DevicePairingBloc({
    required DeviceRepository deviceRepository,
    required ImouStreamRepository imouStreamRepository,
  }) : _deviceRepository = deviceRepository,
       _imouStreamRepository = imouStreamRepository,
       super(const DevicePairingInitial()) {
    on<DevicePairingStarted>(_onStarted);
    on<DevicePairingRetryRequested>(_onRetryRequested);
    on<DevicePairingOpenSettingsRequested>(_onOpenSettingsRequested);
    on<DevicePairingGalleryQrRequested>(_onGalleryQrRequested);
    on<DevicePairingLiveQrDetected>(_onLiveQrDetected);
    on<DevicePairingNameSubmitted>(_onNameSubmitted);
  }

  final DeviceRepository _deviceRepository;
  final ImouStreamRepository _imouStreamRepository;

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

  Future<void> _pairDevice({
    required String rawQr,
    required Emitter<DevicePairingState> emit,
  }) async {
    try {
      emit(const DevicePairingResolving());
      final serialNumber = parseSerialNumber(rawQr);
      if (serialNumber == null) {
        emit(
          const DevicePairingError(
            'Không đọc được mã serial từ QR. Vui lòng thử lại.',
          ),
        );
        return;
      }

      final resolvedResult = await _deviceRepository.resolveDeviceQr(rawQr);
      final resolvedDevice = _valueOrError(
        resolvedResult,
        (failure) => emit(DevicePairingError(failure)),
      );
      if (resolvedDevice == null) return;

      await _verifyImouAndPersist(resolvedDevice: resolvedDevice, emit: emit);
    } catch (error) {
      developer.log('Pairing failed.', name: 'DevicePairingBloc', error: error);
      rethrow;
    }
  }

  Future<void> _verifyImouAndPersist({
    required ResolvedDevice resolvedDevice,
    required Emitter<DevicePairingState> emit,
  }) async {
    emit(DevicePairingCheckingImou(resolvedDevice: resolvedDevice));

    String streamUrl = '';

    try {
      final statusResult = await _imouStreamRepository.checkDeviceStatus(
        resolvedDevice.serialNumber,
      );
      final imouStatus = statusResult.fold((_) => null, (status) => status);

      emit(
        DevicePairingObtainingStream(
          resolvedDevice: resolvedDevice,
          imouStatus:
              imouStatus ??
              ImouDeviceStatus(
                serialNumber: resolvedDevice.serialNumber,
                isBound: false,
                isMine: false,
                isOnline: false,
                deviceName: null,
                channelCount: null,
              ),
        ),
      );

      if (imouStatus != null) {
        final streamResult = await _imouStreamRepository.getStreamUrl(
          resolvedDevice.serialNumber,
        );
        streamUrl = streamResult.fold((_) => '', (url) => url);
      }
    } catch (_) {
      // Imou is non-fatal: device can be saved without a stream URL.
    }

    emit(
      DevicePairingNameInput(
        resolvedDevice: resolvedDevice,
        streamUrl: streamUrl,
      ),
    );
  }

  Future<void> _onNameSubmitted(
    DevicePairingNameSubmitted event,
    Emitter<DevicePairingState> emit,
  ) async {
    final resolvedDevice = ResolvedDevice(
      deviceId: event.resolvedDevice.deviceId,
      displayName: event.name.trim(),
      serialNumber: event.serialNumber,
      model: event.resolvedDevice.model,
      productId: event.resolvedDevice.productId,
      location: event.resolvedDevice.location,
      metadata: event.resolvedDevice.metadata,
    );

    final streamUrl = (state as DevicePairingNameInput).streamUrl;

    emit(
      DevicePairingPersisting(
        resolvedDevice: resolvedDevice,
        streamUrl: streamUrl,
      ),
    );

    final saveResult = await _deviceRepository.savePairedDevice(
      resolvedDevice: resolvedDevice,
      ipAddress: 'imou-cloud',
      rtspUrl: streamUrl,
    );
    final pairedDevice = _valueOrError(
      saveResult,
      (failure) => emit(DevicePairingError(failure)),
    );
    if (pairedDevice == null) return;

    emit(DevicePairingSuccess(pairedDevice, warningMessage: null));
  }

  T? _valueOrError<T>(
    Either<String, T> result,
    void Function(String failure) onFailure,
  ) {
    T? value;
    result.fold((failure) {
      developer.log('Pairing failed: $failure', name: 'DevicePairingBloc');
      onFailure(failure);
    }, (right) => value = right);
    return value;
  }

  // Kept for compatibility with the existing bloc structure.
  // ignore: unused_element
  T? _valueOrImouError<T>(
    Either<ImouStreamFailure, T> result,
    void Function(ImouStreamFailure failure) onFailure,
  ) {
    T? value;
    result.fold((failure) {
      developer.log(
        'Pairing failed: ${failure.message}',
        name: 'DevicePairingBloc',
      );
      onFailure(failure);
    }, (right) => value = right);
    return value;
  }
}
