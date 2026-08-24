import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_logger.dart';
import 'secure_storage_service.dart';

enum BiometricAuthResult {
  success,
  canceled,
  unavailable,
  lockedOut,
  error,
}

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
      if (!await _auth.isDeviceSupported()) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
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

  /// Verifies biometrics once, then persists the user preference.
  Future<bool> verifyAndEnable({required String reason}) async {
    if (!await isAvailable()) return false;
    final result = await authenticate(reason: reason);
    if (result == BiometricAuthResult.success) {
      await setEnabled(enabled: true);
      return true;
    }
    return false;
  }

  Future<BiometricType?> primaryBiometricType() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) {
        return BiometricType.face;
      }
      if (biometrics.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      }
      if (biometrics.contains(BiometricType.strong) ||
          biometrics.contains(BiometricType.weak)) {
        return biometrics.first;
      }
      return biometrics.isEmpty ? null : biometrics.first;
    } catch (e, s) {
      AppLogger.w('Failed to read biometric types', e, s);
      return null;
    }
  }

  Future<BiometricAuthResult> authenticate({
    required String reason,
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Revomaket',
            cancelButton: 'Cancel',
            biometricNotRecognized: 'Not recognized. Try again.',
            biometricRequiredTitle: 'Biometric required',
            deviceCredentialsRequiredTitle: 'Device credentials required',
            goToSettingsButton: 'Settings',
            goToSettingsDescription:
                'Configure biometrics in your device settings.',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Settings',
            goToSettingsDescription:
                'Configure Face ID or Touch ID in Settings.',
            lockOut: 'Biometric locked. Try again later.',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      return didAuthenticate
          ? BiometricAuthResult.success
          : BiometricAuthResult.canceled;
    } on PlatformException catch (e, s) {
      AppLogger.w('Biometric authentication failed', e, s);
      switch (e.code) {
        case auth_error.notAvailable:
        case auth_error.notEnrolled:
        case auth_error.passcodeNotSet:
          return BiometricAuthResult.unavailable;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricAuthResult.lockedOut;
        default:
          return BiometricAuthResult.error;
      }
    } catch (e, s) {
      AppLogger.w('Biometric authentication failed', e, s);
      return BiometricAuthResult.error;
    }
  }
}
