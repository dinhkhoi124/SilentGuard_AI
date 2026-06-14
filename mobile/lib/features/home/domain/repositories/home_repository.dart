import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/device.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';

abstract interface class HomeRepository {
  Future<Either<String, List<Device>>> getDevices();
  Future<Either<String, WeatherInfo>> getWeather();
}
