import 'package:equatable/equatable.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';

sealed class DevicePairingState extends Equatable {
  const DevicePairingState();

  @override
  List<Object?> get props => [];
}

final class DevicePairingInitial extends DevicePairingState {
  const DevicePairingInitial();
}

final class DevicePairingScanning extends DevicePairingState {
  const DevicePairingScanning();
}

final class DevicePairingLoading extends DevicePairingState {
  const DevicePairingLoading(this.serialNumber);

  final String serialNumber;

  @override
  List<Object?> get props => [serialNumber];
}

final class DevicePairingSuccess extends DevicePairingState {
  const DevicePairingSuccess(this.device);

  final PairedDevice device;

  @override
  List<Object?> get props => [device];
}

final class DevicePairingError extends DevicePairingState {
  const DevicePairingError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
