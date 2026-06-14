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

final class NotificationTapped extends HomeEvent {
  const NotificationTapped();
}
