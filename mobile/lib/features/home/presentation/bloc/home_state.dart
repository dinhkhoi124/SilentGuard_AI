// lib/features/home/presentation/bloc/home_state.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
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

final class HomeBackendWarmingUp extends HomeState {
  // FIX: represent Render cold-start separately from an error.
  const HomeBackendWarmingUp();
}

final class HomeUnauthorized extends HomeState {
  // FIX: show session-expired UI only for definitive auth failures.
  const HomeUnauthorized(this.message);

  final String message;

  @override
  List<Object?> get props => [message]; // FIX: keep unauthorized state comparable.
}

final class HomeLoaded extends HomeState {
  const HomeLoaded({
    required this.weather,
    required this.devices,
    required this.selectedRoom,
    this.cameraThumbnails = const {},
    this.openPairingFlow = false,
  });

  final WeatherInfo? weather;
  final List<CameraDevice> devices;
  final String selectedRoom;
  final Map<String, Uint8List> cameraThumbnails;
  final bool openPairingFlow;

  HomeLoaded copyWith({
    WeatherInfo? weather,
    List<CameraDevice>? devices,
    String? selectedRoom,
    Map<String, Uint8List>? cameraThumbnails,
    bool? openPairingFlow,
  }) {
    return HomeLoaded(
      weather: weather ?? this.weather,
      devices: devices ?? this.devices,
      selectedRoom: selectedRoom ?? this.selectedRoom,
      cameraThumbnails: cameraThumbnails ?? this.cameraThumbnails,
      openPairingFlow: openPairingFlow ?? this.openPairingFlow,
    );
  }

  @override
  List<Object?> get props => [
    weather,
    devices,
    selectedRoom,
    cameraThumbnails,
    openPairingFlow,
  ];
}

final class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
