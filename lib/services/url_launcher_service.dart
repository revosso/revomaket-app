import 'package:url_launcher/url_launcher.dart';

import '../core/utils/app_logger.dart';
import '../core/utils/url_utils.dart';

/// Single source of truth for launching external URLs.
class UrlLauncherService {
  const UrlLauncherService();

  /// Tries to open [uri] using the most appropriate native handler.
  /// Returns true on success.
  Future<bool> launch(Uri uri) async {
    try {
      LaunchMode mode = LaunchMode.externalApplication;
      if (uri.scheme == 'tel' ||
          uri.scheme == 'mailto' ||
          uri.scheme == 'sms' ||
          uri.scheme == 'smsto') {
        mode = LaunchMode.externalNonBrowserApplication;
      }
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: mode);
      }
      AppLogger.w('No handler for $uri, trying externalApplication fallback');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, s) {
      AppLogger.e('Failed to launch $uri', e, s);
      return false;
    }
  }

  Future<bool> launchExternalUrlString(String value) =>
      launch(UrlUtils.tryParse(value));
}
