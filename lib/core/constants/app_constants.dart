/// Static, compile-time application constants.
///
/// Anything that depends on the build environment (Auth0 keys, Firebase
/// settings, etc.) belongs in [EnvConfig] (see `lib/config/env_config.dart`).
class AppConstants {
  const AppConstants._();

  // ---------------------------------------------------------------------------
  // App identity
  // ---------------------------------------------------------------------------
  static const String appName = 'Revomaket';
  static const String packageId = 'com.revosso.revomaket';
  static const String supportEmail = 'support@revomaket.com';

  // ---------------------------------------------------------------------------
  // Web targets
  // ---------------------------------------------------------------------------
  static const String webBaseUrl = 'https://revomaket.com';
  static const String webHost = 'revomaket.com';
  static const List<String> allowedHosts = <String>[
    'revomaket.com',
    'www.revomaket.com',
    'app.revomaket.com',
    'api.revomaket.com',
    'cdn.revomaket.com',
  ];

  // ---------------------------------------------------------------------------
  // Deep linking
  // ---------------------------------------------------------------------------
  static const String deepLinkScheme = 'revomaket';
  static const String universalLinkHost = 'revomaket.com';

  // ---------------------------------------------------------------------------
  // Secure storage keys
  // ---------------------------------------------------------------------------
  static const String kAccessToken = 'auth.access_token';
  static const String kRefreshToken = 'auth.refresh_token';
  static const String kIdToken = 'auth.id_token';
  static const String kUserProfile = 'auth.user_profile';
  static const String kTokenExpiresAt = 'auth.expires_at';
  static const String kBiometricEnabled = 'auth.biometric_enabled';
  static const String kLastVisitedUrl = 'webview.last_url';
  static const String kFcmToken = 'push.fcm_token';

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------
  static const String notificationChannelId = 'revomaket_default_channel';
  static const String notificationChannelName = 'Revomaket Notifications';
  static const String notificationChannelDescription =
      'General notifications from Revomaket.';

  // ---------------------------------------------------------------------------
  // Timing
  // ---------------------------------------------------------------------------
  static const Duration splashMinDuration = Duration(milliseconds: 1200);
  static const Duration connectivityRetry = Duration(seconds: 3);
  static const Duration httpTimeout = Duration(seconds: 30);
}
