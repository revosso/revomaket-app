import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../services/secure_storage_service.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';

/// Persists an [AuthSession] securely and reconstructs it on demand.
class SessionManager {
  SessionManager({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;

  Future<void> save(AuthSession session) async {
    await Future.wait([
      _storage.write(AppConstants.kAccessToken, session.accessToken),
      _storage.write(AppConstants.kIdToken, session.idToken),
      if (session.refreshToken != null)
        _storage.write(AppConstants.kRefreshToken, session.refreshToken!),
      _storage.write(
        AppConstants.kTokenExpiresAt,
        session.expiresAt.toIso8601String(),
      ),
      _storage.write(AppConstants.kUserProfile, session.user.toJson()),
    ]);
  }

  Future<AuthSession?> load() async {
    try {
      final accessToken = await _storage.read(AppConstants.kAccessToken);
      final idToken = await _storage.read(AppConstants.kIdToken);
      final refreshToken = await _storage.read(AppConstants.kRefreshToken);
      final expiresAtRaw = await _storage.read(AppConstants.kTokenExpiresAt);
      final profileRaw = await _storage.read(AppConstants.kUserProfile);

      if (accessToken == null ||
          idToken == null ||
          expiresAtRaw == null ||
          profileRaw == null) {
        return null;
      }
      final user = AuthUser.fromJson(profileRaw);
      return AuthSession(
        accessToken: accessToken,
        idToken: idToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.tryParse(expiresAtRaw) ?? DateTime.now(),
        user: user,
      );
    } catch (e, s) {
      AppLogger.w('Could not load session, clearing.', e, s);
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(AppConstants.kAccessToken),
      _storage.delete(AppConstants.kIdToken),
      _storage.delete(AppConstants.kRefreshToken),
      _storage.delete(AppConstants.kTokenExpiresAt),
      _storage.delete(AppConstants.kUserProfile),
    ]);
  }

  /// Returns the raw access token (for WebView header injection, etc.).
  Future<String?> currentAccessToken() async =>
      _storage.read(AppConstants.kAccessToken);

  /// Helper for debugging - never call in release code paths.
  String debugDescribe(AuthSession s) =>
      jsonEncode({'sub': s.user.id, 'exp': s.expiresAt.toIso8601String()});
}
