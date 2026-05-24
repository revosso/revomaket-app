import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised access to environment-dependent configuration.
///
/// Values are sourced (in order):
///   1. `--dart-define` compile-time variables (used in CI / release builds).
///   2. `.env` file bundled at runtime (used in local development).
///
/// `.env` is gitignored. See `.env.example` for the expected keys.
class EnvConfig {
  const EnvConfig._();

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Missing `.env` is fine for release builds that rely on --dart-define.
    }
  }

  static String _read(String key, {String fallback = ''}) {
    const compile = String.fromEnvironment('PLACEHOLDER');
    final defines = <String, String>{
      'AUTH0_DOMAIN': const String.fromEnvironment('AUTH0_DOMAIN'),
      'AUTH0_CLIENT_ID': const String.fromEnvironment('AUTH0_CLIENT_ID'),
      'AUTH0_AUDIENCE': const String.fromEnvironment('AUTH0_AUDIENCE'),
      'AUTH0_SCHEME': const String.fromEnvironment('AUTH0_SCHEME'),
      'WEB_BASE_URL': const String.fromEnvironment('WEB_BASE_URL'),
      'FIREBASE_VAPID_KEY': const String.fromEnvironment('FIREBASE_VAPID_KEY'),
    };

    final fromDefines = defines[key];
    if (fromDefines != null && fromDefines.isNotEmpty) return fromDefines;
    final fromDotenv = dotenv.maybeGet(key);
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    if (compile.isNotEmpty) return compile;
    return fallback;
  }

  // ---------------------------------------------------------------------------
  // Auth0
  // ---------------------------------------------------------------------------
  static String get auth0Domain => _read('AUTH0_DOMAIN');
  static String get auth0ClientId => _read('AUTH0_CLIENT_ID');
  static String get auth0Audience => _read('AUTH0_AUDIENCE');
  static String get auth0Scheme =>
      _read('AUTH0_SCHEME', fallback: 'com.brackstechnologies.revomaket');

  // ---------------------------------------------------------------------------
  // WebView
  // ---------------------------------------------------------------------------
  static String get webBaseUrl =>
      _read('WEB_BASE_URL', fallback: 'https://revomaket.com');

  // ---------------------------------------------------------------------------
  // Firebase (only used on web; mobile uses native config files)
  // ---------------------------------------------------------------------------
  static String get firebaseVapidKey => _read('FIREBASE_VAPID_KEY');

  /// True if all required Auth0 settings are present. Used to gate the auth UI
  /// while developers are still wiring credentials.
  static bool get hasAuth0Config =>
      auth0Domain.isNotEmpty && auth0ClientId.isNotEmpty;
}
