abstract final class AppConfig {
  static const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA');

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const String googleServerClientId = String.fromEnvironment(
    '804956207376-l4fp0vs97r8vjg1bcvru7ffub6bjctgn.apps.googleusercontent.com',
  );

  static const String backendAuthToken = String.fromEnvironment(
    'BACKEND_AUTH_TOKEN',
  );

  static const String defaultOnvifUsername = String.fromEnvironment(
    'ONVIF_USERNAME',
  );

  static const String defaultOnvifPassword = String.fromEnvironment(
    'ONVIF_PASSWORD',
  );

  static const Duration networkTimeout = Duration(seconds: 15);
  static const Duration onvifDiscoveryTimeout = Duration(seconds: 6);
}
