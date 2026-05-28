import 'dart:convert';

/// Server-side opaque session that backs the `webview_session` HttpOnly cookie
/// the SPA inside the embedded WebView authenticates with.
///
/// Created by `POST /v1/webview/session` on nuvannapi (mirror of
/// `rechajem-api/src/controllers/webview-session-controller.ts`).
class WebviewSession {
  const WebviewSession({
    required this.sessionToken,
    required this.cookieName,
    required this.cookieDomain,
    required this.user,
  });

  /// Opaque token (32-byte random hex) injected as the `webview_session`
  /// cookie via `CookieManager.setCookie`.
  final String sessionToken;

  /// Cookie name (defaults to `webview_session`).
  final String cookieName;

  /// Domain the cookie should be bound to (e.g. `.revomaket.com`). Empty
  /// when nuvannapi runs without a configured cookie domain (local dev).
  final String cookieDomain;

  /// User summary as returned by the bridge endpoint (`sub`, `email`, `name`).
  final Map<String, dynamic> user;

  Map<String, dynamic> toMap() => {
        'sessionToken': sessionToken,
        'cookieName': cookieName,
        'cookieDomain': cookieDomain,
        'user': user,
      };

  String toJson() => jsonEncode(toMap());

  factory WebviewSession.fromMap(Map<String, dynamic> map) => WebviewSession(
        sessionToken: map['sessionToken'] as String,
        cookieName: (map['cookieName'] as String?) ?? 'webview_session',
        cookieDomain: (map['cookieDomain'] as String?) ?? '',
        user: (map['user'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  factory WebviewSession.fromJson(String source) =>
      WebviewSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
