import 'package:package_info_plus/package_info_plus.dart';

import '../core/utils/app_logger.dart';

/// Caches the bundle identifier / version so we only hit the platform channel
/// once per app session.
class PackageInfoService {
  PackageInfoService._();

  static PackageInfo? _info;

  static Future<PackageInfo> get info async {
    if (_info != null) return _info!;
    try {
      _info = await PackageInfo.fromPlatform();
      AppLogger.i(
        'App ${_info!.appName} v${_info!.version}+${_info!.buildNumber} '
        '(${_info!.packageName})',
      );
      return _info!;
    } catch (e, s) {
      AppLogger.w('Failed to read package info', e, s);
      rethrow;
    }
  }
}
