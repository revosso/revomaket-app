import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../config/env_config.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';

/// Encapsulates all Auth0 SDK interactions. The rest of the app talks to the
/// repository, not to this class directly.
///
/// Uses [FlutterAppAuth] (a generic AppAuth OIDC client) against the Auth0
/// `/authorize`, `/oauth/token` and `/oidc/logout` endpoints. Auth0 advertises
/// these via its OIDC discovery doc at `${issuer}/.well-known/openid-configuration`.
class AuthService {
  AuthService({FlutterAppAuth? appAuth})
      : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  static const List<String> _scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  /// Triggers Auth0 Universal Login via the system browser and exchanges the
  /// resulting authorization code for tokens.
  Future<AuthSession> login() async {
    if (!EnvConfig.hasAuth0Config) {
      throw const AuthException(
        'Auth0 is not configured. Set AUTH0_DOMAIN and AUTH0_CLIENT_ID.',
      );
    }

    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          EnvConfig.auth0ClientId,
          EnvConfig.auth0RedirectUrl,
          issuer: EnvConfig.auth0Issuer,
          scopes: _scopes,
          additionalParameters: EnvConfig.auth0Audience.isEmpty
              ? null
              : <String, String>{'audience': EnvConfig.auth0Audience},
          promptValues: const ['login'],
        ),
      );
      return _sessionFromTokens(
        accessToken: result.accessToken,
        idToken: result.idToken,
        refreshToken: result.refreshToken,
        expiresAt: result.accessTokenExpirationDateTime,
      );
    } catch (e, s) {
      AppLogger.e('Auth login failed', e, s);
      throw AuthException(_humanMessage(e), cause: e, stackTrace: s);
    }
  }

  /// Clears the Auth0 SSO session via the OIDC end-session endpoint. The
  /// [idToken] hint lets Auth0 skip the logout confirmation prompt.
  Future<void> logout({String? idToken}) async {
    if (!EnvConfig.hasAuth0Config) return;
    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idToken,
          issuer: EnvConfig.auth0Issuer,
          postLogoutRedirectUrl: EnvConfig.auth0RedirectUrl,
        ),
      );
    } catch (e, s) {
      // Logout is best-effort: even if the IdP roundtrip fails, the caller
      // still wipes local credentials.
      AppLogger.w('Auth logout failed', e, s);
    }
  }

  /// Exchanges a refresh token for a fresh access/id token pair.
  Future<AuthSession> refresh(String refreshToken) async {
    try {
      final result = await _appAuth.token(
        TokenRequest(
          EnvConfig.auth0ClientId,
          EnvConfig.auth0RedirectUrl,
          issuer: EnvConfig.auth0Issuer,
          refreshToken: refreshToken,
          scopes: _scopes,
          additionalParameters: EnvConfig.auth0Audience.isEmpty
              ? null
              : <String, String>{'audience': EnvConfig.auth0Audience},
        ),
      );
      return _sessionFromTokens(
        accessToken: result.accessToken,
        idToken: result.idToken,
        refreshToken: result.refreshToken ?? refreshToken,
        expiresAt: result.accessTokenExpirationDateTime,
      );
    } catch (e, s) {
      AppLogger.e('Auth token refresh failed', e, s);
      throw AuthException(
        'Session expired, please sign in again.',
        cause: e,
        stackTrace: s,
      );
    }
  }

  AuthSession _sessionFromTokens({
    required String? accessToken,
    required String? idToken,
    required String? refreshToken,
    required DateTime? expiresAt,
  }) {
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('Auth response missing access token.');
    }
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Auth response missing id token.');
    }

    final claims = JwtDecoder.decode(idToken);
    final user = AuthUser(
      id: (claims['sub'] as String?) ?? '',
      email: claims['email'] as String?,
      name: (claims['name'] as String?) ??
          (claims['nickname'] as String?) ??
          (claims['email'] as String?),
      pictureUrl: claims['picture'] as String?,
      emailVerified: (claims['email_verified'] as bool?) ?? false,
    );

    return AuthSession(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
      user: user,
    );
  }

  String _humanMessage(Object e) {
    final raw = e.toString();
    if (raw.contains('cancel') || raw.contains('CANCELED')) {
      return 'Login was cancelled.';
    }
    // FlutterAppAuthPlatformException carries a useful `error_description` but
    // its plain toString() is noisy. Surface just the first short line.
    final firstLine = raw.split('\n').first;
    if (firstLine.length > 200) return 'Login failed.';
    return firstLine;
  }
}
