import 'package:flutter/foundation.dart';

import '../../../../config/env_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/auth_repository.dart';
import '../../data/models/auth_session.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, authenticating }

/// The single source of truth for authentication state in the UI.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  AuthSession? _session;
  String? _lastError;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  String? get lastError => _lastError;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAuthenticating => _status == AuthStatus.authenticating;
  bool get authConfigured => EnvConfig.hasAuth0Config;

  /// Called once at startup to determine the initial route.
  Future<void> bootstrap() async {
    if (!EnvConfig.hasAuth0Config) {
      // Auth0 has not been wired - skip auth and go straight to the WebView.
      AppLogger.w(
        'AUTH0_DOMAIN / AUTH0_CLIENT_ID are not set. Skipping auth gate.',
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    try {
      final session = await _repository.restoreSession();
      if (session != null) {
        _session = session;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e, s) {
      AppLogger.e('Auth bootstrap failed', e, s);
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login() async {
    _status = AuthStatus.authenticating;
    _lastError = null;
    notifyListeners();
    try {
      final session = await _repository.login();
      _session = session;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _lastError = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e, s) {
      AppLogger.e('Login failed', e, s);
      _lastError = 'Unexpected error during login.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<String?> accessToken() => _repository.currentAccessToken();
}
