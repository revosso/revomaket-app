import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../services/secure_storage_service.dart';
import '../data/models/webview_session.dart';

/// Persists the [WebviewSession] in secure storage so the next app launch can
/// skip the Auth0 round-trip and reopen the WebView with the previously
/// minted `webview_session` cookie.
class WebviewSessionStorage {
  WebviewSessionStorage({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;

  Future<void> save(WebviewSession session) async {
    try {
      await Future.wait([
        _storage.write(
          AppConstants.kWebviewSessionToken,
          session.sessionToken,
        ),
        _storage.write(
          AppConstants.kWebviewSessionCookieName,
          session.cookieName,
        ),
        _storage.write(
          AppConstants.kWebviewSessionCookieDomain,
          session.cookieDomain,
        ),
        _storage.write(
          AppConstants.kWebviewSessionUser,
          jsonEncode(session.user),
        ),
      ]);
      AppLogger.i('[WebviewSessionStorage] saved');
    } catch (e, s) {
      AppLogger.w('[WebviewSessionStorage] save failed (non-fatal)', e, s);
    }
  }

  Future<WebviewSession?> load() async {
    try {
      final results = await Future.wait([
        _storage.read(AppConstants.kWebviewSessionToken),
        _storage.read(AppConstants.kWebviewSessionCookieName),
        _storage.read(AppConstants.kWebviewSessionCookieDomain),
        _storage.read(AppConstants.kWebviewSessionUser),
      ]);
      final token = results[0];
      if (token == null || token.isEmpty) return null;

      Map<String, dynamic> user = const {};
      final rawUser = results[3];
      if (rawUser != null && rawUser.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawUser);
          if (decoded is Map) {
            user = decoded.cast<String, dynamic>();
          }
        } catch (_) {
          // Corrupt entry → fall back to empty profile; the next /me roundtrip
          // will repopulate it.
        }
      }

      return WebviewSession(
        sessionToken: token,
        cookieName: results[1] ?? 'webview_session',
        cookieDomain: results[2] ?? '',
        user: user,
      );
    } catch (e, s) {
      AppLogger.w('[WebviewSessionStorage] load failed, clearing', e, s);
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(AppConstants.kWebviewSessionToken),
        _storage.delete(AppConstants.kWebviewSessionCookieName),
        _storage.delete(AppConstants.kWebviewSessionCookieDomain),
        _storage.delete(AppConstants.kWebviewSessionUser),
      ]);
    } catch (e, s) {
      AppLogger.w('[WebviewSessionStorage] clear failed (non-fatal)', e, s);
    }
  }
}
