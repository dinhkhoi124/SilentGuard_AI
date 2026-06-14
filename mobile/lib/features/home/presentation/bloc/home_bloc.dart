// lib/features/home/presentation/bloc/home_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/devices/data/mock_devices.dart';
import 'package:mobile/features/devices/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required this.getWeather}) : super(const HomeInitial()) {
    on<HomeStarted>(_onStarted);
    on<RoomFilterChanged>(_onRoomFilterChanged);
    on<AddDeviceTapped>(_onAddDeviceTapped);
    on<HomeDeviceDeleted>(_onDeviceDeleted);
    on<HomeAccessoryToggled>(_onAccessoryToggled);
    on<NotificationTapped>((event, emit) {});
  }

  final GetWeather getWeather;
  List<CameraDevice> _activeDevices = [];

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    final weatherResult = await getWeather();

    weatherResult.fold((failure) => emit(HomeError(failure)), (weather) {
      _activeDevices = [];
      emit(
        HomeLoaded(
          weather: weather,
          devices: const [],
          selectedRoom: 'Living Room',
        ),
      );
    });
  }

  void _onRoomFilterChanged(RoomFilterChanged event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    emit(currentState.copyWith(selectedRoom: event.roomName));
  }

  void _onAddDeviceTapped(AddDeviceTapped event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    final activeIds = _activeDevices.map((device) => device.id).toSet();
    final available = mockCameraDevices.where(
      (device) => !activeIds.contains(device.id),
    );
    if (available.isEmpty) return;

    _activeDevices = [..._activeDevices, available.first];
    emit(currentState.copyWith(devices: List.unmodifiable(_activeDevices)));
  }

  void _onDeviceDeleted(HomeDeviceDeleted event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    _activeDevices = _activeDevices
        .where((device) => device.id != event.deviceId)
        .toList();
    emit(currentState.copyWith(devices: List.unmodifiable(_activeDevices)));
  }

  void _onAccessoryToggled(
    HomeAccessoryToggled event,
    Emitter<HomeState> emit,
  ) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    final deviceIndex = _activeDevices.indexWhere(
      (device) => device.id == event.deviceId,
    );
    if (deviceIndex == -1) return;

    final device = _activeDevices[deviceIndex];
    if (event.accessoryIndex < 0 ||
        event.accessoryIndex >= device.accessoryStates.length) {
      return;
    }

    final states = List<bool>.of(device.accessoryStates);
    states[event.accessoryIndex] = !states[event.accessoryIndex];
    _activeDevices = List.of(_activeDevices);
    _activeDevices[deviceIndex] = device.copyWith(accessoryStates: states);
    emit(currentState.copyWith(devices: List.unmodifiable(_activeDevices)));
  }
}
