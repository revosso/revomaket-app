import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../config/app_routes.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../providers/auth_provider.dart';
import '../utils/biometric_flow.dart';

/// Shown when the user must re-authenticate with biometrics before continuing.
class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await BiometricFlow.unlockIfRequired(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      unawaited(
        Navigator.of(context).pushReplacementNamed(AppRoutes.home),
      );
    }
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
                    Icons.fingerprint,
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
