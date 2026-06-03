import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../config/app_routes.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../services/biometric_service.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBiometricPreference());
  }

  Future<void> _loadBiometricPreference() async {
    final biometric = context.read<BiometricService>();
    final available = await biometric.isAvailable();
    final enabled = await biometric.isEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _biometricLoading = false;
    });
  }

  Future<void> _onBiometricToggled(bool value) async {
    await context.read<BiometricService>().setEnabled(enabled: value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  Future<void> _maybeOfferBiometricEnrollment() async {
    final biometric = context.read<BiometricService>();
    if (!await biometric.isAvailable() || await biometric.isEnabled()) return;

    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.biometricEnableTitle),
        content: const Text(AppStrings.biometricEnableMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.biometricNotNowCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.biometricEnableCta),
          ),
        ],
      ),
    );

    if (enable == true) {
      await biometric.setEnabled(enabled: true);
      if (mounted) setState(() => _biometricEnabled = true);
    }
  }

  Future<void> _onLoginPressed(AuthProvider auth) async {
    final success = await auth.login();
    if (!mounted) return;
    if (!success) return;

    await _maybeOfferBiometricEnrollment();
    if (!mounted) return;

    unawaited(Navigator.of(context).pushReplacementNamed(AppRoutes.home));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.splashOverlay,
      child: Scaffold(
        backgroundColor: AppColors.splashBackground,
        body: Stack(
          children: [
            // Amber arc — top right
            Positioned(
              top: -90,
              right: -90,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.09),
                ),
              ),
            ),
            Positioned(
              top: -45,
              right: -45,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.11),
                ),
              ),
            ),
            // Navy arc — bottom left
            Positioned(
              bottom: -70,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    // Logo + brand
                    Center(child: const AppLogo(size: 88)),
                    const SizedBox(height: 28),
                    Text(
                      AppStrings.loginTitle,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),

                    const Spacer(flex: 2),

                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        final loading = auth.isAuthenticating;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (auth.lastError != null) ...[
                              _ErrorBanner(message: auth.lastError!),
                              const SizedBox(height: 16),
                            ],
                            if (_biometricAvailable && !_biometricLoading) ...[
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  AppStrings.biometricLoginToggle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                                value: _biometricEnabled,
                                activeColor: AppColors.accent,
                                onChanged: loading
                                    ? null
                                    : (v) =>
                                        unawaited(_onBiometricToggled(v)),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Amber CTA button
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.textOnAccent,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: loading
                                  ? null
                                  : () => unawaited(_onLoginPressed(auth)),
                              child: loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : const Text(AppStrings.loginCta),
                            ),

                            const SizedBox(height: 16),
                            if (!auth.authConfigured)
                              Text(
                                'Auth0 not configured — proceeding without sign-in.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              )
                            else
                              Text(
                                loading
                                    ? AppStrings.loginInProgress
                                    : 'Secured by Auth0',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Sub-brand footer
                    Text(
                      AppStrings.tagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
