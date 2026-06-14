// lib/features/home/presentation/bloc/home_event.dart

import 'package:equatable/equatable.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

final class HomeStarted extends HomeEvent {
  const HomeStarted();
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
