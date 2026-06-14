// lib/features/devices/presentation/bloc/devices_state.dart

import 'package:equatable/equatable.dart';
import 'package:mobile/features/devices/domain/entities/camera_device.dart';

sealed class DevicesState extends Equatable {
  const DevicesState();

  @override
  List<Object?> get props => [];
}

final class DevicesInitial extends DevicesState {
  const DevicesInitial();
}

final class DevicesLoaded extends DevicesState {
  const DevicesLoaded(this.devices);

  final List<CameraDevice> devices;

  @override
  List<Object?> get props => [devices];
}
