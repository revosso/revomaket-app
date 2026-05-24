import 'package:auth0_flutter/auth0_flutter.dart';

import '../../../config/env_config.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';

/// Encapsulates all Auth0 SDK interactions. The rest of the app talks to the
/// repository, not to this class directly.
class AuthService {
  AuthService({Auth0? auth0})
      : _auth0 = auth0 ??
            Auth0(
              EnvConfig.auth0Domain,
              EnvConfig.auth0ClientId,
            );

  final Auth0 _auth0;

  /// Triggers Auth0 Universal Login. Returns the resulting session.
  Future<AuthSession> login() async {
    if (!EnvConfig.hasAuth0Config) {
      throw const AuthException(
        'Auth0 is not configured. Set AUTH0_DOMAIN and AUTH0_CLIENT_ID.',
      );
    }

    try {
      final scheme = EnvConfig.auth0Scheme;
      final builder = _auth0.webAuthentication(scheme: scheme);
      final credentials = await builder.login(
        audience:
            EnvConfig.auth0Audience.isEmpty ? null : EnvConfig.auth0Audience,
        scopes: const {'openid', 'profile', 'email', 'offline_access'},
      );
      return _toSession(credentials);
    } on WebAuthenticationException catch (e, s) {
      AppLogger.e('Auth0 login failed', e, s);
      throw AuthException(
        e.message.isEmpty ? 'Login was cancelled or failed.' : e.message,
        cause: e,
        stackTrace: s,
      );
    } catch (e, s) {
      AppLogger.e('Auth0 login unexpected failure', e, s);
      throw AuthException('Login failed', cause: e, stackTrace: s);
    }
  }

  /// Clears the Auth0 SSO session.
  Future<void> logout() async {
    if (!EnvConfig.hasAuth0Config) return;
    try {
      await _auth0
          .webAuthentication(scheme: EnvConfig.auth0Scheme)
          .logout();
    } on WebAuthenticationException catch (e, s) {
      AppLogger.w('Auth0 logout returned an error', e, s);
    } catch (e, s) {
      AppLogger.w('Auth0 logout failed', e, s);
    }
  }

  /// Exchanges a refresh token for a fresh access/id token pair.
  Future<AuthSession> refresh(String refreshToken) async {
    try {
      final credentials = await _auth0.api.renewCredentials(
        refreshToken: refreshToken,
      );
      return _toSession(credentials);
    } on ApiException catch (e, s) {
      AppLogger.e('Auth0 token refresh failed', e, s);
      throw AuthException('Session expired, please sign in again.',
          cause: e, stackTrace: s);
    } catch (e, s) {
      AppLogger.e('Auth0 token refresh error', e, s);
      throw AuthException('Could not refresh session',
          cause: e, stackTrace: s);
    }
  }

  AuthSession _toSession(Credentials credentials) {
    final profile = credentials.user;
    final user = AuthUser(
      id: profile.sub,
      email: profile.email,
      name: profile.name ?? profile.nickname ?? profile.email,
      pictureUrl: profile.pictureUrl?.toString(),
      emailVerified: profile.isEmailVerified ?? false,
    );

    return AuthSession(
      accessToken: credentials.accessToken,
      idToken: credentials.idToken,
      refreshToken: credentials.refreshToken,
      expiresAt: credentials.expiresAt,
      user: user,
    );
  }
}
