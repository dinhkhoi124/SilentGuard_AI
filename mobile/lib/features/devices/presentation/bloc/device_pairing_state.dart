import 'package:equatable/equatable.dart';
import 'package:mobile/features/devices/domain/entities/imou_device_status.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';

sealed class DevicePairingState extends Equatable {
  const DevicePairingState();

  @override
  List<Object?> get props => [];
}

final class DevicePairingInitial extends DevicePairingState {
  const DevicePairingInitial();
}

final class DevicePairingPermissionDenied extends DevicePairingState {
  const DevicePairingPermissionDenied(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class DevicePairingScanning extends DevicePairingState {
  const DevicePairingScanning();
}

final class DevicePairingResolving extends DevicePairingState {
  const DevicePairingResolving();
}

final class DevicePairingCheckingImou extends DevicePairingState {
  const DevicePairingCheckingImou({required this.resolvedDevice});

  final ResolvedDevice resolvedDevice;

  @override
  List<Object?> get props => [resolvedDevice];
}

final class DevicePairingObtainingStream extends DevicePairingState {
  const DevicePairingObtainingStream({
    required this.resolvedDevice,
    required this.imouStatus,
  });

  final ResolvedDevice resolvedDevice;
  final ImouDeviceStatus imouStatus;

  @override
  List<Object?> get props => [resolvedDevice, imouStatus];
}

final class DevicePairingNameInput extends DevicePairingState {
  const DevicePairingNameInput({
    required this.resolvedDevice,
    required this.streamUrl,
  });

  final ResolvedDevice resolvedDevice;
  final String streamUrl;

  @override
  List<Object?> get props => [resolvedDevice, streamUrl];
}

final class DevicePairingPersisting extends DevicePairingState {
  const DevicePairingPersisting({
    required this.resolvedDevice,
    required this.streamUrl,
  });

  final ResolvedDevice resolvedDevice;
  final String streamUrl;

  @override
  List<Object?> get props => [resolvedDevice, streamUrl];
}

final class DevicePairingSuccess extends DevicePairingState {
  const DevicePairingSuccess(this.device, {this.warningMessage});

  final PairedDevice device;
  final String? warningMessage;

  @override
  List<Object?> get props => [device, warningMessage];
}

final class DevicePairingError extends DevicePairingState {
  const DevicePairingError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
