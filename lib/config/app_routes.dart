import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/offline/presentation/screens/offline_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/webview/presentation/screens/webview_screen.dart';

/// Named routes used throughout the app.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String offline = '/offline';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        home: (_) => const WebViewScreen(),
        offline: (_) => const OfflineScreen(),
      };
}
