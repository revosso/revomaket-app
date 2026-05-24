import 'dart:convert';

/// Lightweight user profile decoded from the Auth0 ID token.
class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.name,
    this.pictureUrl,
    this.emailVerified = false,
  });

  final String id;
  final String? email;
  final String? name;
  final String? pictureUrl;
  final bool emailVerified;

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'pictureUrl': pictureUrl,
        'emailVerified': emailVerified,
      };

  String toJson() => jsonEncode(toMap());

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
        id: map['id'] as String,
        email: map['email'] as String?,
        name: map['name'] as String?,
        pictureUrl: map['pictureUrl'] as String?,
        emailVerified: (map['emailVerified'] as bool?) ?? false,
      );

  factory AuthUser.fromJson(String source) =>
      AuthUser.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
