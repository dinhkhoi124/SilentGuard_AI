// lib/features/devices/presentation/bloc/devices_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/devices/data/mock_devices.dart';
import 'package:mobile/features/devices/domain/entities/camera_device.dart';
import 'package:mobile/features/devices/presentation/bloc/devices_event.dart';
import 'package:mobile/features/devices/presentation/bloc/devices_state.dart';

class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  DevicesBloc() : super(const DevicesInitial()) {
    on<DevicesStarted>(_onStarted);
    on<DeviceDeleted>(_onDeleted);
    on<AccessoryToggled>(_onToggle);
  }

  List<CameraDevice> _devices = List.of(mockCameraDevices);

  void _onStarted(DevicesStarted event, Emitter<DevicesState> emit) {
    _devices = List.of(mockCameraDevices);
    emit(DevicesLoaded(List.unmodifiable(_devices)));
  }

  void _onDeleted(DeviceDeleted event, Emitter<DevicesState> emit) {
    _devices.removeWhere((device) => device.id == event.deviceId);
    emit(DevicesLoaded(List.unmodifiable(_devices)));
  }

  void _onToggle(AccessoryToggled event, Emitter<DevicesState> emit) {
    final deviceIndex = _devices.indexWhere(
      (device) => device.id == event.deviceId,
    );
    if (deviceIndex == -1) return;

    final device = _devices[deviceIndex];
    if (event.accessoryIndex < 0 ||
        event.accessoryIndex >= device.accessoryStates.length) {
      return;
    }

    final states = List<bool>.of(device.accessoryStates);
    states[event.accessoryIndex] = !states[event.accessoryIndex];
    _devices[deviceIndex] = device.copyWith(accessoryStates: states);
    emit(DevicesLoaded(List.unmodifiable(_devices)));
  }
}
