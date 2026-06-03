import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/webview_session_service.dart';
import '../services/webview_session_storage.dart';
import 'models/auth_session.dart';
import 'models/webview_session.dart';

/// Coordinates [AuthService] (network), [SessionManager] (persistence) and the
/// nuvannapi WebView session bridge.
///
/// This is the only Auth-facing API consumers should depend on. It enforces
/// the rule that the persisted session is always the source of truth.
class AuthRepository {
  AuthRepository({
    AuthService? authService,
    SessionManager? sessionManager,
    WebviewSessionService? webviewSessionService,
    WebviewSessionStorage? webviewSessionStorage,
  })  : _authService = authService ?? AuthService(),
        _sessionManager = sessionManager ?? SessionManager(),
        _webviewSessionService =
            webviewSessionService ?? WebviewSessionService(),
        _webviewSessionStorage =
            webviewSessionStorage ?? WebviewSessionStorage();

  final AuthService _authService;
  final SessionManager _sessionManager;
  final WebviewSessionService _webviewSessionService;
  final WebviewSessionStorage _webviewSessionStorage;

  WebviewSession? _webviewSession;

  /// The WebView session minted by nuvannapi for the current user, if any.
  /// Populated by [restoreSession] and [login]; cleared by [logout].
  WebviewSession? get webviewSession => _webviewSession;

  /// Restores the persisted session, refreshing it if necessary.
  /// Returns `null` if the user is not signed in.
  Future<AuthSession?> restoreSession() async {
    final stored = await _sessionManager.load();
    if (stored == null) {
      _webviewSession = null;
      await _webviewSessionStorage.clear();
      return null;
    }

    final auth = await _refreshIfNeeded(stored);
    if (auth == null) {
      _webviewSession = null;
      await _webviewSessionStorage.clear();
      return null;
    }

    _webviewSession = await _restoreOrBridgeWebviewSession(auth);
    return auth;
  }

  Future<AuthSession> login() async {
    final session = await _authService.login();
    await _sessionManager.save(session);
    _webviewSession = await _bridgeAndPersist(session);
    return session;
  }

  Future<void> logout() async {
    try {
      final stored = await _sessionManager.load();
      await _authService.logout(idToken: stored?.idToken);
    } finally {
      final webview = _webviewSession ?? await _webviewSessionStorage.load();
      if (webview != null) {
        await _webviewSessionService.revoke(webview.sessionToken);
      }
      await Future.wait([
        _sessionManager.clear(),
        _webviewSessionStorage.clear(),
      ]);
      _webviewSession = null;
    }
  }

  Future<String?> currentAccessToken() =>
      _sessionManager.currentAccessToken();

  /// Returns a valid Auth0 access token, refreshing the session if needed.
  Future<String?> getValidAccessToken() async {
    final stored = await _sessionManager.load();
    if (stored == null) return null;
    final auth = await _refreshIfNeeded(stored);
    return auth?.accessToken;
  }

  /// Re-mints the nuvannapi WebView session from the current Auth0 id_token.
  ///
  /// Called when the SPA's profile fetch keeps failing — re-injecting the
  /// previous cookie is not enough if the server-side session expired.
  Future<WebviewSession?> remintWebviewSession() async {
    AppLogger.i('[Auth] remintWebviewSession start');
    final stored = await _sessionManager.load();
    if (stored == null) {
      AppLogger.w('[Auth] remintWebviewSession — no stored Auth0 session');
      _webviewSession = null;
      await _webviewSessionStorage.clear();
      return null;
    }

    final auth = await _refreshIfNeeded(stored);
    if (auth == null) {
      AppLogger.w('[Auth] remintWebviewSession — Auth0 refresh failed');
      _webviewSession = null;
      await _webviewSessionStorage.clear();
      return null;
    }

    final previous = _webviewSession ?? await _webviewSessionStorage.load();
    AppLogger.i(
      '[Auth] remintWebviewSession bridging id_token for ${auth.user.id}',
    );
    final reminted = await _bridgeAndPersist(auth);
    if (reminted == null) {
      AppLogger.w('[Auth] remintWebviewSession — POST /webview/session failed');
      return null;
    }

    _webviewSession = reminted;
    if (previous != null && previous.sessionToken != reminted.sessionToken) {
      AppLogger.i('[Auth] remintWebviewSession revoking previous token');
      await _webviewSessionService.revoke(previous.sessionToken);
    }
    AppLogger.i(
      '[Auth] remintWebviewSession OK cookieDomain=${reminted.cookieDomain}',
    );
    return _webviewSession;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<AuthSession?> _refreshIfNeeded(AuthSession stored) async {
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

  /// On app launch, prefer the persisted WebView session token. If it's gone
  /// (e.g. fresh install with a migrated Auth0 session, or a corrupted
  /// keystore entry) re-bridge transparently using the current id_token so
  /// the user never has to re-login just to get a cookie.
  Future<WebviewSession?> _restoreOrBridgeWebviewSession(
      AuthSession auth) async {
    final stored = await _webviewSessionStorage.load();
    if (stored != null) {
      return stored;
    }
    return _bridgeAndPersist(auth);
  }

  Future<WebviewSession?> _bridgeAndPersist(AuthSession auth) async {
    try {
      final webview = await _webviewSessionService.create(auth.idToken);
      await _webviewSessionStorage.save(webview);
      return webview;
    } catch (e, s) {
      // The Auth0 portion of the login succeeded; downgrading the WebView
      // bridge failure to a warning lets the user still browse the SPA
      // (it will prompt for sign-in there). Re-bridge happens on next launch.
      AppLogger.w(
        'Auth: webview session bridge failed; SPA will prompt for login.',
        e,
        s,
      );
      return null;
    }
  }
}
