import 'package:equatable/equatable.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';

sealed class DevicePairingEvent extends Equatable {
  const DevicePairingEvent();

  @override
  List<Object?> get props => [];
}

final class DevicePairingStarted extends DevicePairingEvent {
  const DevicePairingStarted();
}

final class DevicePairingRetryRequested extends DevicePairingEvent {
  const DevicePairingRetryRequested();
}

final class DevicePairingOpenSettingsRequested extends DevicePairingEvent {
  const DevicePairingOpenSettingsRequested();
}

final class DevicePairingGalleryQrRequested extends DevicePairingEvent {
  const DevicePairingGalleryQrRequested();
}

final class DevicePairingLiveQrDetected extends DevicePairingEvent {
  const DevicePairingLiveQrDetected(this.rawQr);

  final String rawQr;

  @override
  List<Object?> get props => [rawQr];
}

final class DevicePairingNameSubmitted extends DevicePairingEvent {
  const DevicePairingNameSubmitted(
    this.name,
    this.resolvedDevice,
    this.serialNumber,
  );

  final String name;
  final ResolvedDevice resolvedDevice;
  final String serialNumber;

  @override
  List<Object?> get props => [name, resolvedDevice, serialNumber];
}
