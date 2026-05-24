import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import 'models/auth_session.dart';

/// Coordinates [AuthService] (network) and [SessionManager] (persistence).
///
/// This is the only Auth-facing API consumers should depend on. It enforces
/// the rule that the persisted session is always the source of truth.
class AuthRepository {
  AuthRepository({
    AuthService? authService,
    SessionManager? sessionManager,
  })  : _authService = authService ?? AuthService(),
        _sessionManager = sessionManager ?? SessionManager();

  final AuthService _authService;
  final SessionManager _sessionManager;

  /// Restores the persisted session, refreshing it if necessary.
  /// Returns `null` if the user is not signed in.
  Future<AuthSession?> restoreSession() async {
    final stored = await _sessionManager.load();
    if (stored == null) return null;

    if (!stored.isAboutToExpire) {
      AppLogger.i('Auth: restored session for ${stored.user.id}');
      return stored;
    }

    final refreshToken = stored.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      AppLogger.w('Auth: no refresh token, clearing session.');
      await _sessionManager.clear();
      return null;
    }

    try {
      final refreshed = await _authService.refresh(refreshToken);
      await _sessionManager.save(refreshed);
      AppLogger.i('Auth: refreshed session for ${refreshed.user.id}');
      return refreshed;
    } on AuthException catch (e) {
      AppLogger.w('Auth: refresh failed, clearing session - ${e.message}');
      await _sessionManager.clear();
      return null;
    }
  }

  Future<AuthSession> login() async {
    final session = await _authService.login();
    await _sessionManager.save(session);
    return session;
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } finally {
      await _sessionManager.clear();
    }
  }

  Future<String?> currentAccessToken() =>
      _sessionManager.currentAccessToken();
}
