import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
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
    on<HomeDevicePaired>(_onDevicePaired);
    on<CameraThumbnailCaptured>(_onCameraThumbnailCaptured);
    on<HomeAccessoryToggled>(_onAccessoryToggled);
    on<NotificationTapped>((event, emit) {});
  }

  final GetWeather getWeather;
  final GetCameraDevices getCameraDevices;
  final DeleteCameraDevice deleteCameraDevice;
  List<CameraDevice> _activeDevices = [];
  int _loadGeneration = 0;

  Future<void> _loadHome(Emitter<HomeState> emit) async {
    final generation = ++_loadGeneration;
    emit(const HomeLoading());

    final weatherFuture = getWeather();
    final deviceResult = await getCameraDevices();
    var devicesLoaded = false;
    deviceResult.fold((failure) => emit(HomeError(failure)), (devices) {
      devicesLoaded = true;
      _activeDevices = List.of(devices);
      emit(
        HomeLoaded(
          weather: null,
          devices: List.unmodifiable(_activeDevices),
          selectedRoom: 'All Rooms',
        ),
      );
    });

    if (!devicesLoaded || generation != _loadGeneration) return;

    final weatherResult = await weatherFuture;
    if (generation != _loadGeneration) return;

    weatherResult.fold((_) {}, (weather) {
      if (weather == null) return;
      final currentState = state;
      if (currentState is! HomeLoaded) return;
      emit(currentState.copyWith(weather: weather));
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

    emit(currentState.copyWith(openPairingFlow: true));
    emit(currentState.copyWith(openPairingFlow: false));
  }

  Future<void> _onDeviceDeleted(
    HomeDeviceDeleted event,
    Emitter<HomeState> emit,
  ) async {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    final result = await deleteCameraDevice(event.deviceId);
    var failed = false;
    result.fold((failure) {
      failed = true;
      emit(HomeError(failure));
    }, (_) {});
    if (failed) return;

    _activeDevices = _activeDevices
        .where((device) => device.id != event.deviceId)
        .toList();
    final thumbnails = Map<String, Uint8List>.of(currentState.cameraThumbnails)
      ..remove(event.deviceId);
    emit(
      currentState.copyWith(
        devices: List.unmodifiable(_activeDevices),
        cameraThumbnails: thumbnails,
      ),
    );
  }

  void _onDevicePaired(HomeDevicePaired event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    final deviceIndex = _activeDevices.indexWhere(
      (device) => device.id == event.device.id,
    );
    if (deviceIndex == -1) {
      _activeDevices = [..._activeDevices, event.device];
    } else {
      _activeDevices = List.of(_activeDevices);
      _activeDevices[deviceIndex] = event.device;
    }
    emit(currentState.copyWith(devices: List.unmodifiable(_activeDevices)));
  }

  void _onCameraThumbnailCaptured(
    CameraThumbnailCaptured event,
    Emitter<HomeState> emit,
  ) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;

    emit(
      currentState.copyWith(
        cameraThumbnails: {
          ...currentState.cameraThumbnails,
          event.deviceId: event.bytes,
        },
      ),
    );
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
