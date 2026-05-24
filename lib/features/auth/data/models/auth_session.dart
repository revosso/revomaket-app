import 'auth_user.dart';

/// A successful authentication: tokens plus the resolved user profile.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String idToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final AuthUser user;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isAboutToExpire =>
      DateTime.now().add(const Duration(minutes: 2)).isAfter(expiresAt);

  AuthSession copyWith({
    String? accessToken,
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
    AuthUser? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      user: user ?? this.user,
    );
  }
}
