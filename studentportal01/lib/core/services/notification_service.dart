import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/widgets/in_app_notification_banner.dart';
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
  static bool _permissionsRequested = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static final Map<String, DateTime> _recentNotifications = {};

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
      if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
        return;
      }

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
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
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
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
      }

      // 4. Configure Firebase messaging listeners
      try {
        // Keep iOS foreground OS banners disabled because InAppNotificationBanner handles foreground UI
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );

        // Foreground notification handling -> show single in-app banner (deduplicated against Realtime)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          final title = notification?.title ??
              message.data['title']?.toString() ??
              'Nouvelle notification';
          final body =
              notification?.body ?? message.data['body']?.toString() ?? '';
          final route = message.data['route']?.toString();

          final IconData icon;
          final Color color;
          switch (route) {
            case '/messages':
              icon = Icons.mail_rounded;
              color = const Color(0xFF6B5CE7);
              break;
            case '/documents':
              icon = Icons.folder_shared_rounded;
              color = const Color(0xFF3B82F6);
              break;
            case '/suggestions':
              icon = Icons.mark_chat_read_rounded;
              color = const Color(0xFF10B981);
              break;
            default:
              icon = Icons.notifications_rounded;
              color = const Color(0xFF8B5CF6);
          }

          InAppNotificationBanner.show(
            title: title,
            message: body.isNotEmpty ? body : 'Nouvelle notification disponible',
            icon: icon,
            color: color,
            onTap: () {
              if (route != null && route.isNotEmpty) {
                rootNavigatorKey.currentContext?.push(route);
              }
            },
          );
        });

        // App opened from background via notification tap
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final route = message.data['route']?.toString();
          if (route != null && route.isNotEmpty) {
            rootNavigatorKey.currentContext?.push(route);
          }
        });

        // Check if opened from completely terminated state
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          final route = initialMessage.data['route']?.toString();
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

  /// Request OS notification permissions safely once the Activity window is ready
  static Future<void> requestPermissions() async {
    if (kIsWeb || _permissionsRequested) return;
    _permissionsRequested = true;

    try {
      if (!_isInitialized) {
        await init();
      }

      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('Notification permission request error: $e');
    }
  }

  /// Synchronize the student's device token with Supabase
  static Future<void> syncDeviceToken(String userId) async {
    try {
      if (kIsWeb) return;
      if (!_isInitialized) {
        await init();
      }

      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await Supabase.instance.client.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'device_type': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,token');
        debugPrint('FCM token synchronized for user $userId');
      } else {
        debugPrint('FCM token is null/empty for user $userId');
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub =
          // ignore: deprecated_member_use
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          if (newToken.isEmpty) return;
          await Supabase.instance.client.from('user_fcm_tokens').upsert({
            'user_id': userId,
            'token': newToken,
            'device_type': Platform.isIOS ? 'ios' : 'android',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,token');
          debugPrint('FCM token refreshed & synced for user $userId');
        } catch (e) {
          debugPrint('FCM token refresh sync error: $e');
        }
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
      if (kIsWeb) return;
      final now = DateTime.now();
      final key = '$title|$body|${routePayload ?? ''}';
      final prev = _recentNotifications[key];
      if (prev != null && now.difference(prev).inSeconds < 5) {
        return;
      }
      _recentNotifications[key] = now;
      if (_recentNotifications.length > 30) {
        _recentNotifications.removeWhere(
          (_, ts) => now.difference(ts).inSeconds > 30,
        );
      }

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
        id: id & 0x7fffffff,
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

