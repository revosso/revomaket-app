import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/utils/biometric_flow.dart';
import '../../services/biometric_service.dart';

/// Presents a full-screen lock when the app returns from the background while
/// the user has an active session and biometric unlock is enabled.
class BiometricLifecycleListener extends StatefulWidget {
  const BiometricLifecycleListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<BiometricLifecycleListener> createState() =>
      _BiometricLifecycleListenerState();
}

class _BiometricLifecycleListenerState extends State<BiometricLifecycleListener>
    with WidgetsBindingObserver {
  bool _lockOnResume = false;
  bool _lockScreenVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _lockOnResume = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _lockOnResume) {
      _lockOnResume = false;
      unawaited(_guardOnResume());
    }
  }

  Future<void> _guardOnResume() async {
    if (_lockScreenVisible) return;

    final navigator = widget.navigatorKey.currentState;
    final navContext = widget.navigatorKey.currentContext;
    if (navigator == null || navContext == null) return;

    final routeName = ModalRoute.of(navContext)?.settings.name;
    if (!BiometricFlow.shouldGuardRoute(routeName)) return;

    final auth = Provider.of<AuthProvider>(navContext, listen: false);
    if (!auth.isAuthenticated) return;

    final biometric =
        Provider.of<BiometricService>(navContext, listen: false);
    if (!await biometric.isEnabled()) return;

    _lockScreenVisible = true;
    try {
      await navigator.pushNamed(
        AppRoutes.biometricUnlock,
        arguments: true,
      );
    } finally {
      _lockScreenVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
