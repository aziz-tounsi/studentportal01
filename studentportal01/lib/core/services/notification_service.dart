import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/firebase_options.dart';
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

  static int stableNotificationId(String key) => key.hashCode & 0x7fffffff;

  /// Safely resolves the target in-app route, including specific item ID
  static String? buildTargetRoute({
    String? route,
    String? table,
    String? recordId,
  }) {
    if (route != null && route.isNotEmpty) {
      if (recordId != null && recordId.isNotEmpty && !route.contains('id=')) {
        return route.contains('?') ? '$route&id=$recordId' : '$route?id=$recordId';
      }
      return route;
    }
    if (table != null && table.isNotEmpty) {
      final suffix = (recordId != null && recordId.isNotEmpty) ? '?id=$recordId' : '';
      switch (table) {
        case 'announcements_global':
          return '/notifications$suffix';
        case 'announcements_class':
        case 'announcements':
          return '/messages$suffix';
        case 'documents':
          return '/documents$suffix';
        case 'suggestions':
        case 'suggestion_replies':
          return '/suggestions$suffix';
        case 'absences':
          return '/absences$suffix';
        case 'grades':
          return '/resultats';
        default:
          break;
      }
    }
    return null;
  }

  /// Cleanly navigates using GoRouter to properly switch the ShellRoute and highlight the tab
  static void navigateToRoute(String? targetRoute) {
    if (targetRoute == null || targetRoute.isEmpty) return;
    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        dismissAllOverlaysAndPopups();
        GoRouter.of(ctx).go(targetRoute);
      }
    } catch (e) {
      debugPrint('Error navigating from notification to $targetRoute: $e');
    }
  }

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'student_portal_alerts_v2',
    'Student Portal Notifications',
    description: 'Notifications for announcements, messages, and document updates.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    showBadge: true,
  );

  static bool get isFirebaseAvailable =>
      !kIsWeb && Firebase.apps.isNotEmpty;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
        return;
      }

      // 1. Initialize Firebase Core
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        if (Firebase.apps.isNotEmpty) {
          FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        }
      } catch (e) {
        try {
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp();
          }
          if (Firebase.apps.isNotEmpty) {
            FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
          }
        } catch (e2) {
          debugPrint('Firebase.initializeApp warning/error: $e / $e2');
        }
      }

      // 2. Initialize Local Notifications Plugin
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
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
            navigateToRoute(payload);
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

      // 4. Configure Firebase messaging listeners (if Firebase is initialized)
      if (isFirebaseAvailable) {
        try {
          // Keep iOS native FCM presentation alerts off because showNotification presents unified OS alerts deduplicated with Realtime
          await FirebaseMessaging.instance
              .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );

        // Foreground notification handling -> post single native phone OS notification
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          final title = notification?.title ??
              message.data['title']?.toString() ??
              'Nouvelle notification';
          final body =
              notification?.body ?? message.data['body']?.toString() ?? '';
          final route = message.data['route']?.toString();
          final table = message.data['table']?.toString();
          final recordId = message.data['record_id']?.toString();
          final resolvedRoute = buildTargetRoute(
            route: route,
            table: table,
            recordId: recordId,
          );
          final dedupKey = (table != null &&
                  table.isNotEmpty &&
                  recordId != null &&
                  recordId.isNotEmpty)
              ? '$table:$recordId'
              : null;

          showNotification(
            id: stableNotificationId(dedupKey ?? '$title|$body|${resolvedRoute ?? ''}'),
            title: title,
            body: body.isNotEmpty ? body : 'Nouvelle notification disponible',
            routePayload: resolvedRoute,
            dedupKey: dedupKey,
          );
        });

        // App opened from background via notification tap
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final route = message.data['route']?.toString();
          final table = message.data['table']?.toString();
          final recordId = message.data['record_id']?.toString();
          final resolvedRoute = buildTargetRoute(
            route: route,
            table: table,
            recordId: recordId,
          );
          if (resolvedRoute != null && resolvedRoute.isNotEmpty) {
            navigateToRoute(resolvedRoute);
          }
        });

        // Check if opened from completely terminated state
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          final route = initialMessage.data['route']?.toString();
          final table = initialMessage.data['table']?.toString();
          final recordId = initialMessage.data['record_id']?.toString();
          final resolvedRoute = buildTargetRoute(
            route: route,
            table: table,
            recordId: recordId,
          );
          if (resolvedRoute != null && resolvedRoute.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 600), () {
              navigateToRoute(resolvedRoute);
            });
          }
          }
        } catch (e) {
          debugPrint('Firebase messaging listener setup error: $e');
        }
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

      if (isFirebaseAvailable) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      }
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

      if (!isFirebaseAvailable) {
        debugPrint('Firebase not available on this device; skipping FCM token sync');
        return;
      }

      String? token;
      if (Platform.isIOS) {
        // Query APNs token first on iOS. On sideloaded builds without push entitlement,
        // APNs token is null. We avoid calling getToken() when APNs is missing to prevent exceptions.
        String? apnsToken;
        for (int i = 0; i < 4; i++) {
          try {
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) break;
          } catch (e) {
            debugPrint('[APNS] getAPNSToken attempt $i: $e');
          }
          await Future.delayed(const Duration(milliseconds: 1000));
        }

        if (apnsToken == null) {
          debugPrint(
            '[APNS] No APNs token available from iOS (typical on personal Apple ID sideloading without Push entitlement). '
            'In-app Realtime & Catch-up notifications will deliver all alerts.',
          );
          return;
        }

        try {
          // ignore: deprecated_member_use
          token = await FirebaseMessaging.instance.getToken().timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
        } catch (e) {
          debugPrint('[FCM] iOS getToken error: $e');
        }
      } else {
        // ignore: deprecated_member_use
        token = await FirebaseMessaging.instance.getToken().timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        );
      }

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
    String? dedupKey,
  }) async {
    try {
      if (kIsWeb) return;
      final now = DateTime.now();
      final key = (dedupKey != null && dedupKey.isNotEmpty)
          ? dedupKey
          : '$title|$body|${routePayload ?? ''}';
      final prev = _recentNotifications[key];
      if (prev != null && now.difference(prev).inSeconds < 20) {
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
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        channelShowBadge: true,
        ticker: title,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
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

