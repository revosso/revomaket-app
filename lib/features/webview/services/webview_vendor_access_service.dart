import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/env_config.dart';
import '../../../core/utils/app_logger.dart';

/// Detects vendor/admin dashboard access from `GET /v1/users/me`.
///
/// Mirrors `MarketplaceHeader` + `userHasSellerRegistration` / `effectiveCanSell`
/// on the web app.
class WebviewVendorAccessService {
  WebviewVendorAccessService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<bool> canAccessVendorDashboard({String? accessToken}) async {
    final origin = EnvConfig.apiOrigin;
    if (origin.isEmpty) return false;

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      };

      final response = await _client.get(
        Uri.parse('$origin/v1/users/me'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        AppLogger.w(
          '[WebView] vendor access check failed HTTP ${response.statusCode}',
        );
        return false;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return false;
      return canAccessFromProfile(body);
    } catch (e, s) {
      AppLogger.w('[WebView] vendor access check error', e, s);
      return false;
    }
  }

  /// Mirrors `MarketplaceHeader` dashboard visibility on the web app.
  static bool canAccessFromProfile(Map<String, dynamic> profile) {
    final roles = (profile['roles'] as List?)?.cast<String>() ?? const [];
    if (roles.contains('ADMINISTRATOR') || roles.contains('SELLER')) {
      return true;
    }

    final accounts =
        (profile['businessAccounts'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    if (accounts.isNotEmpty) return true;

    for (final account in accounts) {
      final caps = account['capabilities'];
      if (caps is Map && caps['effectiveCanSell'] == true) return true;
    }

    return false;
  }
}
