import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../config/app_routes.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../services/connectivity_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen>
    with SingleTickerProviderStateMixin {
  Timer? _autoRetry;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    final connectivity = context.read<ConnectivityService>();
    connectivity.addListener(_onConnectivityChanged);
    _startAutoReconnect();
  }

  void _startAutoReconnect() {
    _autoRetry?.cancel();
    _autoRetry =
        Timer.periodic(AppConstants.connectivityRetry, (_) => _retry(silent: true));
  }

  void _onConnectivityChanged() {
    final connectivity = context.read<ConnectivityService>();
    if (connectivity.isOnline && mounted) {
      _navigateForward();
    }
  }

  void _navigateForward() {
    final auth = context.read<AuthProvider>();
    final destination = auth.isAuthenticated ? AppRoutes.home : AppRoutes.login;
    Navigator.of(context).pushReplacementNamed(destination);
  }

  Future<void> _retry({bool silent = false}) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final connectivity = context.read<ConnectivityService>();
    final online = await connectivity.recheck();
    if (!mounted) return;
    if (online) {
      _navigateForward();
      return;
    }
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still offline. Please try again.')),
      );
    }
    setState(() => _retrying = false);
  }

  @override
  void dispose() {
    _autoRetry?.cancel();
    context.read<ConnectivityService>().removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.contentOverlay,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    AppStrings.offlineTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.offlineMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _retrying ? null : () => _retry(),
                      icon: _retrying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textOnPrimary),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: const Text(AppStrings.retryCta),
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
