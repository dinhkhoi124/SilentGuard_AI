import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/domain/usecases/get_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required this.getDevices, required this.getWeather})
    : super(const HomeInitial()) {
    on<HomeStarted>(_onStarted);
    on<RoomFilterChanged>(_onRoomFilterChanged);
    on<AddDeviceTapped>(_onAddDeviceTapped);
    on<NotificationTapped>((event, emit) {});
  }

  final GetDevices getDevices;
  final GetWeather getWeather;
  HomeLoaded? _lastLoaded;

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    final weatherResult = await getWeather();
    final devicesResult = await getDevices();

    weatherResult.fold(
      (failure) => emit(HomeError(failure)),
      (weather) =>
          devicesResult.fold((failure) => emit(HomeError(failure)), (devices) {
            _lastLoaded = HomeLoaded(
              weather: weather,
              devices: devices,
              selectedRoom: 'Living Room',
            );
            emit(_lastLoaded!);
          }),
    );
  }

  void _onRoomFilterChanged(RoomFilterChanged event, Emitter<HomeState> emit) {
    final currentState = _lastLoaded;
    if (currentState == null) return;
    _lastLoaded = HomeLoaded(
      weather: currentState.weather,
      devices: currentState.devices,
      selectedRoom: event.roomName,
    );
    emit(_lastLoaded!);
  }

  void _onAddDeviceTapped(AddDeviceTapped event, Emitter<HomeState> emit) {
    final currentState = _lastLoaded;
    if (currentState == null) return;
    emit(const HomeNavigateToDevices());
    emit(currentState);
  }
}
