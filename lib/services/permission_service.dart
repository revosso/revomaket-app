import 'package:permission_handler/permission_handler.dart';

import '../core/utils/app_logger.dart';

/// Lightweight wrapper around `permission_handler` that exposes only the
/// permissions the app actually requests.
class PermissionService {
  const PermissionService();

  Future<bool> requestNotifications() async =>
      _request(Permission.notification);

  Future<bool> requestCamera() async => _request(Permission.camera);

  Future<bool> requestMicrophone() async => _request(Permission.microphone);

  Future<bool> requestPhotos() async {
    // On Android 13+ we want media-images; on older Android we fall back to
    // storage. iOS is handled internally by the plugin.
    final mediaGranted = await _request(Permission.photos);
    if (mediaGranted) return true;
    return _request(Permission.storage);
  }

  Future<bool> requestLocation() async =>
      _request(Permission.locationWhenInUse);

  Future<bool> _request(Permission permission) async {
    try {
      final status = await permission.request();
      AppLogger.i('Permission $permission -> $status');
      return status.isGranted || status.isLimited;
    } catch (e, s) {
      AppLogger.w('Failed to request $permission', e, s);
      return false;
    }
  }
}
