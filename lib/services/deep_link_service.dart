import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_logger.dart';

/// Captures incoming deep links (custom scheme + universal links) and exposes
/// them as a broadcast stream of fully-qualified Revomaket URLs that can be
/// loaded directly inside the WebView.
class DeepLinkService extends ChangeNotifier {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  StreamSubscription<Uri>? _sub;

  /// Stream of deep links translated to https URLs on revomaket.com.
  Stream<Uri> get onLink => _controller.stream;

  /// Latest captured link before the WebView was ready, if any.
  Uri? pending;

  Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        final normalized = _normalize(initial);
        if (normalized != null) {
          pending = normalized;
          AppLogger.i('Initial deep link: $normalized');
        }
      }
    } catch (e, s) {
      AppLogger.w('Failed to read initial deep link', e, s);
    }

    _sub = _appLinks.uriLinkStream.listen((uri) {
      final normalized = _normalize(uri);
      if (normalized != null) {
        AppLogger.i('Deep link received: $normalized');
        _controller.add(normalized);
      }
    }, onError: (Object e, StackTrace s) {
      AppLogger.w('Deep link stream error', e, s);
    });
  }

  /// Converts a `revomaket://path` or `https://revomaket.com/path` into a
  /// canonical https URL on the configured web base. Returns null when the URI
  /// does not target Revomaket.
  Uri? _normalize(Uri uri) {
    if (uri.scheme == AppConstants.deepLinkScheme) {
      final path = uri.host.isNotEmpty
          ? '/${uri.host}${uri.path}'
          : uri.path.isNotEmpty
              ? uri.path
              : '/';
      return Uri.parse('${AppConstants.webBaseUrl}$path')
          .replace(query: uri.query.isEmpty ? null : uri.query);
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        AppConstants.allowedHosts.any(
          (host) => uri.host == host || uri.host.endsWith('.$host'),
        )) {
      return uri.scheme == 'https'
          ? uri
          : uri.replace(scheme: 'https');
    }
    return null;
  }

  void clearPending() => pending = null;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
    super.dispose();
  }
}
