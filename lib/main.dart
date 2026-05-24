import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/app_theme.dart';
import 'config/env_config.dart';
import 'core/utils/app_logger.dart';
import 'services/package_info_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.contentOverlay);

  FlutterError.onError = (details) {
    AppLogger.e('Flutter error', details.exception, details.stack);
  };

  await EnvConfig.load();

  // Warm up package info so the splash screen does not jitter.
  PackageInfoService.info.ignore();

  runApp(const RevomaketApp());
}
