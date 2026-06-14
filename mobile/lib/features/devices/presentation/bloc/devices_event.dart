// lib/features/devices/presentation/bloc/devices_event.dart

import 'package:equatable/equatable.dart';

sealed class DevicesEvent extends Equatable {
  const DevicesEvent();

  @override
  List<Object?> get props => [];
}

final class DevicesStarted extends DevicesEvent {
  const DevicesStarted();
}

final class DeviceDeleted extends DevicesEvent {
  const DeviceDeleted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

final class AccessoryToggled extends DevicesEvent {
  const AccessoryToggled(this.deviceId, this.accessoryIndex);

  final String deviceId;
  final int accessoryIndex;

  @override
  List<Object?> get props => [deviceId, accessoryIndex];
}
