import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../../../config/app_routes.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../services/biometric_service.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

/// Full-screen lock shown on cold start and when returning from background.
class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({
    super.key,
    this.resumeMode = false,
  });

  /// When `true`, a successful unlock pops back to the previous screen.
  final bool resumeMode;

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _busy = false;
  String? _errorMessage;
  BiometricType? _biometricType;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBiometricType());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Future<void>.delayed(
        const Duration(milliseconds: 350),
        _tryUnlock,
      ));
    });
  }

  Future<void> _loadBiometricType() async {
    final type =
        await context.read<BiometricService>().primaryBiometricType();
    if (!mounted) return;
    setState(() => _biometricType = type);
  }

  IconData get _biometricIcon {
    return switch (_biometricType) {
      BiometricType.face => Icons.face_rounded,
      BiometricType.fingerprint => Icons.fingerprint,
      _ => Icons.lock_rounded,
    };
  }

  Future<void> _tryUnlock() async {
    if (_busy) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      await _signInAgain();
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final biometric = context.read<BiometricService>();
    if (!await biometric.isEnabled()) {
      _finishUnlock();
      return;
    }

    final result = await biometric.authenticate(
      reason: AppStrings.biometricUnlockReason,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case BiometricAuthResult.success:
        _finishUnlock();
      case BiometricAuthResult.canceled:
        setState(() => _errorMessage = AppStrings.biometricUnlockCanceled);
      case BiometricAuthResult.lockedOut:
        setState(() => _errorMessage = AppStrings.biometricUnlockLockedOut);
      case BiometricAuthResult.unavailable:
        setState(() => _errorMessage = AppStrings.biometricUnlockUnavailable);
      case BiometricAuthResult.error:
        setState(() => _errorMessage = AppStrings.biometricUnlockFailed);
    }
  }

  void _finishUnlock() {
    final navigator = Navigator.of(context);
    if (widget.resumeMode || navigator.canPop()) {
      navigator.pop(true);
      return;
    }
    unawaited(navigator.pushReplacementNamed(AppRoutes.home));
  }

  Future<void> _signInAgain() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.splashOverlay,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.splashBackground,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const AppLogo(size: 88),
                  const SizedBox(height: 28),
                  Icon(
                    _biometricIcon,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.biometricUnlockTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textInverted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.biometricUnlockSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.accent,
                            height: 1.4,
                          ),
                    ),
                  ],
                  const Spacer(flex: 2),
                  FilledButton(
                    onPressed: _busy ? null : () => unawaited(_tryUnlock()),
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textOnPrimary,
                              ),
                            ),
                          )
                        : const Text(AppStrings.biometricUnlockCta),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_signInAgain()),
                    child: const Text(
                      AppStrings.biometricSignInAgainCta,
                      style: TextStyle(color: Color(0xCCFFFFFF)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
