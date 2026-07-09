abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://c2-app-128-production.up.railway.app',
  );

  static const String googleSignInServerClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
    defaultValue:
        '804956207376-l4fp0vs97r8vjg1bcvru7ffub6bjctgn.apps.googleusercontent.com',
  );

  static const String imouBaseUrl = String.fromEnvironment(
    'IMOU_API_BASE_URL',
    defaultValue: 'https://openapi-sg.easy4ip.com/openapi',
  );

  static const String imouAppId = String.fromEnvironment(
    'IMOU_APP_ID',
    defaultValue: 'lc29325014155044ad',
  );

  static const String imouAppSecret = String.fromEnvironment(
    'IMOU_APP_SECRET',
    defaultValue: '201c43cf082041a48e5bd69be23cf4',
  );



  static const Duration networkTimeout = Duration(seconds: 15);
}
