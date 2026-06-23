// lib/features/home/presentation/bloc/home_event.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

final class HomeStarted extends HomeEvent {
  const HomeStarted();
}

final class HomeRetryRequested extends HomeEvent {
  const HomeRetryRequested({
    this.silent = false,
  }); // FIX: auto-retry backend warm-up without flashing the loading screen.

  final bool
  silent; // FIX: distinguish user retry from silent 5s backend retry.

  @override
  List<Object?> get props => [silent]; // FIX: include retry mode in event equality.
}

final class RoomFilterChanged extends HomeEvent {
  const RoomFilterChanged(this.roomName);

  final String roomName;

  @override
  List<Object?> get props => [roomName];
}

final class AddDeviceTapped extends HomeEvent {
  const AddDeviceTapped();
}

final class HomeDeviceDeleted extends HomeEvent {
  const HomeDeviceDeleted(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

final class HomeDevicePaired extends HomeEvent {
  const HomeDevicePaired(this.device);

  final CameraDevice device;

  @override
  List<Object?> get props => [device];
}

final class CameraThumbnailCaptured extends HomeEvent {
  const CameraThumbnailCaptured({required this.deviceId, required this.bytes});

  final String deviceId;
  final Uint8List bytes;

  @override
  List<Object?> get props => [deviceId, bytes];
}

final class CameraStreamUrlRequested extends HomeEvent {
  const CameraStreamUrlRequested({
    required this.cameraId,
    required this.serialNumber,
  });

  final String cameraId;
  final String serialNumber;

  @override
  List<Object?> get props => [cameraId, serialNumber];
}

final class HomeAccessoryToggled extends HomeEvent {
  const HomeAccessoryToggled(this.deviceId, this.accessoryIndex);

  final String deviceId;
  final int accessoryIndex;

  @override
  List<Object?> get props => [deviceId, accessoryIndex];
}

final class NotificationTapped extends HomeEvent {
  const NotificationTapped();
}
