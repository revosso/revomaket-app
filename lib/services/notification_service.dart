import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_logger.dart';
import 'secure_storage_service.dart';

// Firebase is intentionally imported only when configured. The service degrades
// gracefully when Firebase has not been initialized.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Background isolate entry point. MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } catch (_) {/* ignored */}
  }
  AppLogger.i('Background message: ${message.messageId}');
}

/// Coordinates Firebase Cloud Messaging + local notifications.
///
/// The service is safe to call even when Firebase has not been initialized -
/// it logs a warning and becomes a no-op so the rest of the app keeps working
/// while integrators wire `google-services.json` / `GoogleService-Info.plist`.
class NotificationService {
  NotificationService({
    SecureStorageService? storage,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _storage = storage ?? SecureStorageService(),
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final SecureStorageService _storage;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final StreamController<String> _onTokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<RemoteMessage> _onMessageOpenedController =
      StreamController<RemoteMessage>.broadcast();

  bool _initialized = false;
  bool _firebaseAvailable = false;

  Stream<String> get onTokenRefresh => _onTokenRefreshController.stream;
  Stream<RemoteMessage> get onMessageOpened => _onMessageOpenedController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocalNotifications();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAvailable = true;
    } catch (e, s) {
      AppLogger.w(
        'Firebase not configured - push notifications disabled. '
        'Add google-services.json / GoogleService-Info.plist to enable.',
        e,
        s,
      );
      return;
    }

    await _initFirebaseMessaging();
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final android13Plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android13Plugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _initFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    AppLogger.i('Notification permission: ${settings.authorizationStatus}');

    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _storage.write(AppConstants.kFcmToken, token);
        _onTokenRefreshController.add(token);
        AppLogger.i('FCM token acquired');
      }
    } catch (e, s) {
      AppLogger.w('Could not retrieve FCM token', e, s);
    }

    messaging.onTokenRefresh.listen((token) async {
      await _storage.write(AppConstants.kFcmToken, token);
      _onTokenRefreshController.add(token);
    });

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp
        .listen(_onMessageOpenedController.add);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['url']?.toString(),
    );
  }

  Future<String?> currentToken() async {
    if (!_firebaseAvailable) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  bool get isAvailable => _firebaseAvailable && !kIsWeb;

  void dispose() {
    _onTokenRefreshController.close();
    _onMessageOpenedController.close();
  }
}
