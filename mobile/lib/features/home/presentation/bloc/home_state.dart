import 'package:equatable/equatable.dart';
import 'package:mobile/features/home/domain/entities/device.dart';
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
  });

  final WeatherInfo weather;
  final List<Device> devices;
  final String selectedRoom;

  @override
  List<Object?> get props => [weather, devices, selectedRoom];
}

final class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
