// lib/features/home/presentation/bloc/home_bloc.dart

import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/home/data/mock_devices.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/usecases/delete_camera_device.dart';
import 'package:mobile/features/home/domain/usecases/get_camera_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required this.getWeather,
    required this.getCameraDevices,
    required this.deleteCameraDevice,
  }) : super(const HomeInitial()) {
    on<HomeStarted>((event, emit) => _loadHome(emit));
    on<HomeRetryRequested>((event, emit) => _loadHome(emit));
    on<RoomFilterChanged>(_onRoomFilterChanged);
    on<AddDeviceTapped>(_onAddDeviceTapped);
    on<HomeDeviceDeleted>(_onDeviceDeleted);
    on<HomeAccessoryToggled>(_onAccessoryToggled);
    on<NotificationTapped>((event, emit) {});
  }

  final GetWeather getWeather;
  final GetCameraDevices getCameraDevices;
  final DeleteCameraDevice deleteCameraDevice;
  static bool _debugTokenLogged = false;
  List<CameraDevice> _activeDevices = [];

  Future<void> _loadHome(Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    await _logDebugTokenOnce();
    final weatherResult = await getWeather();

    await weatherResult.fold((failure) async => emit(HomeError(failure)), (
      weather,
    ) async {
      final deviceResult = await getCameraDevices();
      deviceResult.fold((failure) => emit(HomeError(failure)), (devices) {
        _activeDevices = List.of(devices);
        emit(
          HomeLoaded(
            weather: weather,
            devices: List.unmodifiable(_activeDevices),
            selectedRoom: 'All Rooms',
          ),
        );
      });
    });
  }

  Future<void> _logDebugTokenOnce() async {
    if (_debugTokenLogged) return;
    _debugTokenLogged = true;

    // TODO: remove debug token print before shipping.
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    developer.log('[DEBUG_TOKEN] $token', name: 'DebugToken');
  }

  void _onRoomFilterChanged(RoomFilterChanged event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    emit(currentState.copyWith(selectedRoom: event.roomName));
  }

  void _onAddDeviceTapped(AddDeviceTapped event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    if (!AppConfig.useMockData) {
      emit(currentState.copyWith(openPairingFlow: true));
      emit(currentState.copyWith(openPairingFlow: false));
      return;
    }

    final activeIds = _activeDevices.map((device) => device.id).toSet();
    final available = mockCameraDevices.where(
      (device) => !activeIds.contains(device.id),
    );
    if (available.isEmpty) return;

    _activeDevices = [..._activeDevices, available.first];
    emit(currentState.copyWith(devices: List.unmodifiable(_activeDevices)));
  }

  Future<void> _onDeviceDeleted(
    HomeDeviceDeleted event,
    Emitter<HomeState> emit,
  ) async {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    if (!AppConfig.useMockData) {
      final result = await deleteCameraDevice(event.deviceId);
      var failed = false;
      result.fold((failure) {
        failed = true;
        emit(HomeError(failure));
      }, (_) {});
      if (failed) return;
    }

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
