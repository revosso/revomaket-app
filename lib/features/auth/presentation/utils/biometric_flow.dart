import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../config/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../services/biometric_service.dart';
import '../providers/auth_provider.dart';

/// Shared biometric gate used on cold start and when returning to the app.
class BiometricFlow {
  const BiometricFlow._();

  /// Returns `true` when the user may proceed (biometric off, or scan succeeded).
  static Future<bool> unlockIfRequired(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return true;

    final biometric = context.read<BiometricService>();
    if (!await biometric.isEnabled()) return true;

    final result = await biometric.authenticate(
      reason: AppStrings.biometricUnlockReason,
    );
    return result == BiometricAuthResult.success;
  }

  /// Whether biometric unlock should run after bootstrap.
  static Future<bool> shouldShowLockScreen(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return false;

    final biometric = context.read<BiometricService>();
    return biometric.isEnabled();
  }

  /// Whether a resume-time unlock prompt should run for the current route.
  static bool shouldGuardRoute(String? routeName) {
    if (routeName == null) return false;
    return routeName != AppRoutes.splash &&
        routeName != AppRoutes.login &&
        routeName != AppRoutes.biometricUnlock &&
        routeName != AppRoutes.offline;
  }
}
