import '../constants/app_constants.dart';

/// Helpers for safely classifying and validating URLs that show up in the
/// WebView.
class UrlUtils {
  const UrlUtils._();

  static const Set<String> _externalSchemes = <String>{
    'tel',
    'mailto',
    'sms',
    'smsto',
    'whatsapp',
    'fb-messenger',
    'tg',
    'instagram',
    'twitter',
    'geo',
    'maps',
    'comgooglemaps',
    'waze',
    'intent',
    'market',
    'itms-apps',
    'itms-appss',
  };

  /// Returns true if [url] should leave the WebView and open in a native app.
  static bool isExternalScheme(Uri url) {
    final scheme = url.scheme.toLowerCase();
    if (scheme.isEmpty) return false;
    return _externalSchemes.contains(scheme);
  }

  /// Returns true if the URL belongs to Revomaket and is safe to load in the
  /// WebView. Anything else (different domain, http on a host we don't trust)
  /// should be opened externally.
  static bool isInternalUrl(Uri url) {
    if (!url.hasScheme) return true;
    if (url.scheme != 'https' && url.scheme != 'http') return false;
    final host = url.host.toLowerCase();
    if (host.isEmpty) return false;
    return AppConstants.allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }

  /// True for `https://` URLs only. The WebView is locked to SSL.
  static bool isSecureHttp(Uri url) => url.scheme == 'https';

  /// Best-effort parse with a safe fallback to a fragment-only URI.
  static Uri tryParse(String value) {
    try {
      return Uri.parse(value);
    } catch (_) {
      return Uri(path: value);
    }
  }
}
