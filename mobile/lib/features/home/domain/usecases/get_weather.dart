import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

class GetWeather {
  const GetWeather(this.repository);

  final HomeRepository repository;

  Future<Either<String, WeatherInfo?>> call() => repository.getWeather();
}
