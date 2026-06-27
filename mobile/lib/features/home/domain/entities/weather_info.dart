import 'package:equatable/equatable.dart';

class WeatherInfo extends Equatable {
  const WeatherInfo({
    required this.temperature,
    required this.city,
    required this.condition,
    required this.aqi,
    required this.humidity,
    required this.windSpeed,
  });

  final double temperature;
  final String city;
  final String condition;
  final int aqi;
  final double humidity;
  final double windSpeed;

  @override
  List<Object?> get props => [
    temperature,
    city,
    condition,
    aqi,
    humidity,
    windSpeed,
  ];
}
