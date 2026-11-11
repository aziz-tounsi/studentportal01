import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('Handling a background message: ${message.messageId}');
  } catch (e) {
    debugPrint('Background message handler error: $e');
  }
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'student_portal_channel',
    'Student Portal Notifications',
    description: 'Notifications for announcements, messages, and document updates.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) return;

      // 1. Initialize Firebase Core
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('Firebase.initializeApp warning/error: $e');
      }

      // 2. Initialize Local Notifications Plugin
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final ctx = rootNavigatorKey.currentContext;
              if (ctx != null && payload.startsWith('/')) {
                ctx.push(payload);
              }
            } catch (e) {
              debugPrint('Error navigating from notification: $e');
            }
          }
        },
      );

      // 3. Create Android notification channel
      if (!kIsWeb && Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);

        // Request runtime permission on Android 13+
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      // 4. Request Firebase permissions
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        // Foreground notification handling
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          final title = notification?.title ?? message.data['title'] ?? 'Nouvelle notification';
          final body = notification?.body ?? message.data['body'] ?? '';
          final route = message.data['route'] as String?;

          showNotification(
            id: message.messageId.hashCode,
            title: title,
            body: body,
            routePayload: route,
          );
        });

        // App opened from background via notification tap
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final route = message.data['route'] as String?;
          if (route != null && route.isNotEmpty) {
            rootNavigatorKey.currentContext?.push(route);
          }
        });

        // Check if opened from completely terminated state
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          final route = initialMessage.data['route'] as String?;
          if (route != null && route.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 600), () {
              rootNavigatorKey.currentContext?.push(route);
            });
          }
        }
      } catch (e) {
        debugPrint('Firebase messaging listener setup error: $e');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('LocalNotificationService initialization skipped/error: $e');
    }
  }

  /// Synchronize the student's device token with Supabase
  static Future<void> syncDeviceToken(String userId) async {
    try {
      if (kIsWeb) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await Supabase.instance.client.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'device_type': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id, token');
        debugPrint('FCM token synchronized for user $userId');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await Supabase.instance.client.from('user_fcm_tokens').upsert({
            'user_id': userId,
            'token': newToken,
            'device_type': Platform.isIOS ? 'ios' : 'android',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id, token');
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }

  static Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? routePayload,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: routePayload,
      );
    } catch (e) {
      debugPrint('LocalNotificationService showNotification error: $e');
    }
  }
}
