import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:mobile/features/devices/domain/utils/qr_parser.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_event.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_state.dart';

class DevicePairingBloc extends Bloc<DevicePairingEvent, DevicePairingState> {
  DevicePairingBloc({required DeviceRepository deviceRepository})
    : _deviceRepository = deviceRepository,
      super(const DevicePairingInitial()) {
    on<DevicePairingStarted>(_onStarted);
    on<DevicePairingRetryRequested>(_onRetryRequested);
    on<DevicePairingLiveQrDetected>(_onLiveQrDetected);
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
            : const DevicePairingError(
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

  Future<void> _onLiveQrDetected(
    DevicePairingLiveQrDetected event,
    Emitter<DevicePairingState> emit,
  ) async {
    if (state is! DevicePairingScanning) return;

    final serialNumber = parseSerialNumber(event.rawQr);
    if (serialNumber == null || serialNumber.trim().isEmpty) {
      emit(
        const DevicePairingError(
          'Không đọc được mã serial từ QR. Vui lòng thử lại.',
        ),
      );
      return;
    }

    final normalizedSerial = serialNumber.trim();
    emit(DevicePairingLoading(normalizedSerial));

    final result = await _deviceRepository.savePairedDevice(
      resolvedDevice: ResolvedDevice(
        deviceId: normalizedSerial,
        displayName: 'Camera $normalizedSerial',
        serialNumber: normalizedSerial,
      ),
    );
    final pairedDevice = _valueOrError(
      result,
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
    result.fold((failure) {
      developer.log('Pairing failed: $failure', name: 'DevicePairingBloc');
      onFailure(failure);
    }, (right) => value = right);
    return value;
  }
}
