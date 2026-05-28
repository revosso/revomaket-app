import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../data/models/webview_session.dart';

/// Bridges the Auth0 PKCE id_token into a server-side opaque session on
/// nuvannapi.
///
/// The SPA running inside the embedded WebView authenticates with the
/// `webview_session` HttpOnly cookie (set by [WebViewScreen] from
/// [WebviewSession.sessionToken]); the SPA never needs to know about the
/// Auth0 access token / id token directly.
///
/// Mirrors `rechajem-app/lib/auth/auth0_oauth_service.dart#_createWebviewSession`.
class WebviewSessionService {
  WebviewSessionService({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? AppConstants.httpTimeout;

  final http.Client _client;
  final Duration _timeout;

  /// POST `id_token` to nuvannapi and return the minted session descriptor.
  Future<WebviewSession> create(String idToken) async {
    final url = Uri.parse(EnvConfig.webviewSessionUrl);
    AppLogger.i('[WebviewSession] POST $url');

    try {
      final response = await _client
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.w(
          '[WebviewSession] create failed status=${response.statusCode} '
          'body=${_truncate(response.body)}',
        );
        throw AuthException(
          'Could not establish WebView session (HTTP ${response.statusCode}).',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['sessionToken'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthException(
          'WebView session response is missing sessionToken.',
        );
      }
      return WebviewSession(
        sessionToken: token,
        cookieName: (body['cookieName'] as String?) ?? 'webview_session',
        cookieDomain: (body['cookieDomain'] as String?) ?? '',
        user: (body['user'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    } on AuthException {
      rethrow;
    } catch (e, s) {
      AppLogger.e('[WebviewSession] create error', e, s);
      throw AuthException(
        'Could not establish WebView session.',
        cause: e,
        stackTrace: s,
      );
    }
  }

  /// Best-effort logout. Sends the cookie back to nuvannapi so it can delete
  /// the server-side session entry. Failures are non-fatal — the next call to
  /// a protected endpoint will fail-fast and re-prompt for login anyway.
  Future<void> revoke(String sessionToken) async {
    if (sessionToken.isEmpty) return;
    final url = Uri.parse(EnvConfig.webviewLogoutUrl);
    try {
      await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              // The endpoint reads the cookie; we still send it explicitly so
              // it works on platforms where the http client doesn't follow the
              // `Set-Cookie` jar.
              'Cookie': 'webview_session=$sessionToken',
            },
          )
          .timeout(_timeout);
    } catch (e, s) {
      AppLogger.w('[WebviewSession] revoke failed (non-fatal)', e, s);
    }
  }

  String _truncate(String s, [int max = 256]) =>
      s.length <= max ? s : '${s.substring(0, max)}...';

  void close() => _client.close();
}
