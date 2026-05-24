import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'services/connectivity_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/url_launcher_service.dart';

class RevomaketApp extends StatelessWidget {
  const RevomaketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Singletons created once for the lifetime of the app.
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService(),
        ),
        ChangeNotifierProvider<DeepLinkService>(
          create: (_) => DeepLinkService()..init(),
        ),
        Provider<UrlLauncherService>(create: (_) => const UrlLauncherService()),
        Provider<NotificationService>(
          create: (_) => NotificationService()..init(),
          dispose: (_, service) => service.dispose(),
        ),

        // Feature providers.
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.contentOverlay,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(context).clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
