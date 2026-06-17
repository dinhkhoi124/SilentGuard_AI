abstract final class AppConfig {
  static const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA');

  static const String apiBaseUrl = String.fromEnvironment(
    'https://c2-app-128-production.up.railway.app',
    defaultValue: '',
  );

  static const String googleSignInServerClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
    defaultValue:
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
