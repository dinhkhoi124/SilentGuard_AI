import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:mobile/features/home/domain/entities/weather_info.dart';

abstract interface class WeatherRemoteDataSource {
  Future<WeatherInfo?> getCurrentWeather();
}

class OpenMeteoWeatherRemoteDataSource implements WeatherRemoteDataSource {
  OpenMeteoWeatherRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  static final Uri _weatherUri = Uri.parse(
    'https://api.open-meteo.com/v1/forecast'
    '?latitude=21.0285'
    '&longitude=105.8542'
    '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
    '&temperature_unit=celsius'
    '&wind_speed_unit=ms'
    '&timezone=Asia%2FBangkok',
  );

  static final Uri _airQualityUri = Uri.parse(
    'https://air-quality-api.open-meteo.com/v1/air-quality'
    '?latitude=21.0285'
    '&longitude=105.8542'
    '&current=us_aqi'
    '&timezone=Asia%2FBangkok',
  );

  static const _cityName = 'Hà Nội';
  static const _timeout = Duration(seconds: 9);

  final http.Client _client;

  @override
  Future<WeatherInfo?> getCurrentWeather() async {
    try {
      final responses = await Future.wait([
        _client.get(_weatherUri).timeout(_timeout),
        _client.get(_airQualityUri).timeout(_timeout),
      ]);

      final weatherResponse = responses[0];
      final airQualityResponse = responses[1];
      if (weatherResponse.statusCode != 200 ||
          airQualityResponse.statusCode != 200) {
        developer.log(
          'Open-Meteo returned non-success status: '
          'weather=${weatherResponse.statusCode}, '
          'airQuality=${airQualityResponse.statusCode}.',
          name: 'OpenMeteoWeatherRemoteDataSource',
        );
        return null;
      }

      final weatherJson = _decodeObject(weatherResponse.body);
      final airQualityJson = _decodeObject(airQualityResponse.body);
      if (weatherJson == null || airQualityJson == null) return null;

      final currentWeather = _readObject(weatherJson['current']);
      final currentAirQuality = _readObject(airQualityJson['current']);
      if (currentWeather == null || currentAirQuality == null) return null;

      final temperature = _readDouble(currentWeather['temperature_2m']);
      final humidity = _readDouble(currentWeather['relative_humidity_2m']);
      final weatherCode = _readInt(currentWeather['weather_code']);
      final windSpeed = _readDouble(currentWeather['wind_speed_10m']);
      final aqi = _readInt(currentAirQuality['us_aqi']);

      if (temperature == null ||
          humidity == null ||
          weatherCode == null ||
          windSpeed == null ||
          aqi == null) {
        developer.log(
          'Open-Meteo response missed required current weather fields.',
          name: 'OpenMeteoWeatherRemoteDataSource',
        );
        return null;
      }

      return WeatherInfo(
        temperature: temperature,
        city: _cityName,
        condition: _mapWeatherCodeToVietnamese(weatherCode),
        aqi: aqi,
        humidity: humidity,
        windSpeed: windSpeed,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Open-Meteo weather fetch failed.',
        name: 'OpenMeteoWeatherRemoteDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic>? _readObject(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _readInt(Object? value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _mapWeatherCodeToVietnamese(int code) {
    return switch (code) {
      0 => 'Trời quang',
      1 => 'Ít mây',
      2 => 'Có mây',
      3 => 'Nhiều mây',
      45 || 48 => 'Sương mù',
      51 || 53 || 55 => 'Mưa phùn',
      56 || 57 => 'Mưa phùn lạnh',
      61 || 63 || 65 => 'Mưa',
      66 || 67 => 'Mưa lạnh',
      71 || 73 || 75 => 'Tuyết rơi',
      77 => 'Hạt tuyết',
      80 || 81 || 82 => 'Mưa rào',
      85 || 86 => 'Mưa tuyết',
      95 => 'Dông',
      96 || 99 => 'Dông kèm mưa đá',
      _ => 'Thời tiết hiện tại',
    };
  }
}
