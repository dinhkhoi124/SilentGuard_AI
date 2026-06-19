// lib/features/home/presentation/bloc/home_state.dart

import 'package:equatable/equatable.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';

sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

final class HomeInitial extends HomeState {
  const HomeInitial();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  const HomeLoaded({
    required this.weather,
    required this.devices,
    required this.selectedRoom,
    this.openPairingFlow = false,
  });

  final WeatherInfo? weather;
  final List<CameraDevice> devices;
  final String selectedRoom;
  final bool openPairingFlow;

  HomeLoaded copyWith({
    WeatherInfo? weather,
    List<CameraDevice>? devices,
    String? selectedRoom,
    bool? openPairingFlow,
  }) {
    return HomeLoaded(
      weather: weather ?? this.weather,
      devices: devices ?? this.devices,
      selectedRoom: selectedRoom ?? this.selectedRoom,
      openPairingFlow: openPairingFlow ?? this.openPairingFlow,
    );
  }

  @override
  List<Object?> get props => [weather, devices, selectedRoom, openPairingFlow];
}

final class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
