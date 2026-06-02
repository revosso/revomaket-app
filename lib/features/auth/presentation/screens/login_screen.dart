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
    if (!await biometric.isAvailable() || await biometric.isEnabled()) {
      return;
    }

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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const AppLogo(size: 96),
                const SizedBox(height: 32),
                Text(
                  AppStrings.loginTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textInverted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
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
                                  ?.copyWith(color: Colors.white70),
                            ),
                            value: _biometricEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: loading
                                ? null
                                : (value) => unawaited(_onBiometricToggled(value)),
                          ),
                          const SizedBox(height: 8),
                        ],
                        FilledButton(
                          onPressed: loading
                              ? null
                              : () => unawaited(_onLoginPressed(auth)),
                          child: loading
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
                              : const Text(AppStrings.loginCta),
                        ),
                        const SizedBox(height: 16),
                        if (!auth.authConfigured)
                          Text(
                            'Auth0 not configured - proceeding without sign-in.',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white54,
                                    ),
                          )
                        else
                          Text(
                            loading
                                ? AppStrings.loginInProgress
                                : 'Secured by Auth0',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white54,
                                    ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
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
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
