import 'package:local_auth/local_auth.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_logger.dart';
import 'secure_storage_service.dart';

/// Optional biometric unlock. Off by default; toggled by the user.
class BiometricService {
  BiometricService({
    LocalAuthentication? auth,
    SecureStorageService? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? SecureStorageService();

  final LocalAuthentication _auth;
  final SecureStorageService _storage;

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (e, s) {
      AppLogger.w('Biometric availability check failed', e, s);
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final value = await _storage.read(AppConstants.kBiometricEnabled);
    return value == 'true';
  }

  Future<void> setEnabled({required bool enabled}) async {
    await _storage.write(AppConstants.kBiometricEnabled, enabled.toString());
  }

  Future<bool> authenticate({
    String reason = 'Authenticate to access Revomaket',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e, s) {
      AppLogger.w('Biometric authentication failed', e, s);
      return false;
    }
  }
}
