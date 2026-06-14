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
    on<AddDeviceTapped>((event, emit) {});
    on<NotificationTapped>((event, emit) {});
  }

  final GetDevices getDevices;
  final GetWeather getWeather;

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    final weatherResult = await getWeather();
    final devicesResult = await getDevices();

    weatherResult.fold(
      (failure) => emit(HomeError(failure)),
      (weather) => devicesResult.fold(
        (failure) => emit(HomeError(failure)),
        (devices) => emit(
          HomeLoaded(
            weather: weather,
            devices: devices,
            selectedRoom: 'Living Room',
          ),
        ),
      ),
    );
  }

  void _onRoomFilterChanged(RoomFilterChanged event, Emitter<HomeState> emit) {
    final currentState = state;
    if (currentState is! HomeLoaded) return;
    emit(
      HomeLoaded(
        weather: currentState.weather,
        devices: currentState.devices,
        selectedRoom: event.roomName,
      ),
    );
  }
}
