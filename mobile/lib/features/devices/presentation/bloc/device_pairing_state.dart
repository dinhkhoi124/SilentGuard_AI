import 'package:equatable/equatable.dart';
import 'package:mobile/features/devices/domain/entities/onvif_discovery_result.dart';
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

final class DevicePairingDiscovering extends DevicePairingState {
  const DevicePairingDiscovering({required this.resolvedDevice});

  final ResolvedDevice resolvedDevice;

  @override
  List<Object?> get props => [resolvedDevice];
}

final class DevicePairingMatching extends DevicePairingState {
  const DevicePairingMatching({
    required this.resolvedDevice,
    required this.discoveredDevices,
  });

  final ResolvedDevice resolvedDevice;
  final List<OnvifDiscoveryResult> discoveredDevices;

  @override
  List<Object?> get props => [resolvedDevice, discoveredDevices];
}

final class DevicePairingObtainingStream extends DevicePairingState {
  const DevicePairingObtainingStream({
    required this.resolvedDevice,
    required this.discoveryResult,
  });

  final ResolvedDevice resolvedDevice;
  final OnvifDiscoveryResult discoveryResult;

  @override
  List<Object?> get props => [resolvedDevice, discoveryResult];
}

final class DevicePairingCredentialsRequired extends DevicePairingState {
  const DevicePairingCredentialsRequired({
    required this.resolvedDevice,
    required this.discoveryResult,
    required this.message,
  });

  final ResolvedDevice resolvedDevice;
  final OnvifDiscoveryResult discoveryResult;
  final String message;

  @override
  List<Object?> get props => [resolvedDevice, discoveryResult, message];
}

final class DevicePairingPersisting extends DevicePairingState {
  const DevicePairingPersisting({
    required this.resolvedDevice,
    required this.discoveryResult,
    required this.rtspUrl,
  });

  final ResolvedDevice resolvedDevice;
  final OnvifDiscoveryResult discoveryResult;
  final String rtspUrl;

  @override
  List<Object?> get props => [resolvedDevice, discoveryResult, rtspUrl];
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
