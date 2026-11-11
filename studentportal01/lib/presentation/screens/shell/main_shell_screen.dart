import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../providers/announcements_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_context_provider.dart';
import '../../providers/suggestions_provider.dart';
import '../../widgets/bubble_nav_bar.dart';
import '../../widgets/in_app_notification_banner.dart';
import '../../../core/services/notification_service.dart';
import '../documents/documents_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  final int currentIndex;

  const MainShellScreen({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  DateTime? _lastResumeSync;
  RealtimeChannel? _globalRealtimeChannel;
  String? _subscribedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtime();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tearDownRealtime();
    super.dispose();
  }

  void _tearDownRealtime() {
    if (_globalRealtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_globalRealtimeChannel!);
      } catch (_) {}
      _globalRealtimeChannel = null;
      _subscribedUserId = null;
    }
  }

  void _setupRealtime() {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) return;
      final userId = session.user.id;

      // Sync FCM device token for background push notifications
      LocalNotificationService.syncDeviceToken(userId);

      if (_subscribedUserId == userId && _globalRealtimeChannel != null) {
        return; // already subscribed for this user
      }

      _tearDownRealtime();
      _subscribedUserId = userId;

      _globalRealtimeChannel =
          supabase.channel('student_portal_realtime_shell_$userId');

      // 1. Global announcements (Notifications)
      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'announcements_global',
        callback: (payload) {
          debugPrint('Realtime Shell: announcements_global updated -> refreshing');
          ref.invalidate(globalAnnouncementsProvider);
          if (payload.eventType == PostgresChangeEvent.insert) {
            final record = payload.newRecord;
            final title = record['title']?.toString() ?? 'Nouvelle notification';
            final body = record['body']?.toString() ?? '';
            InAppNotificationBanner.show(
              title: title,
              message: body.isNotEmpty ? body : 'Nouvelle notification disponible',
              icon: Icons.notifications_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                if (mounted) context.push('/notifications');
              },
            );
            LocalNotificationService.showNotification(
              id: (record['id'] ?? '').hashCode,
              title: title,
              body: body.isNotEmpty ? body : 'Nouvelle notification disponible',
              routePayload: '/notifications',
            );
          }
        },
      );

      // 2. Class messages (Messages)
      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'announcements_class',
        callback: (payload) {
          debugPrint('Realtime Shell: announcements_class updated -> refreshing');
          ref.invalidate(classMessagesProvider);
          if (payload.eventType == PostgresChangeEvent.insert) {
            final record = payload.newRecord;
            final title = record['title']?.toString() ?? 'Nouveau message';
            final body = record['body']?.toString() ?? '';
            InAppNotificationBanner.show(
              title: title,
              message: body.isNotEmpty ? body : 'Nouveau message de classe disponible',
              icon: Icons.mail_rounded,
              color: const Color(0xFF6B5CE7),
              onTap: () {
                if (mounted) context.push('/messages');
              },
            );
            LocalNotificationService.showNotification(
              id: (record['id'] ?? '').hashCode,
              title: title,
              body: body.isNotEmpty ? body : 'Nouveau message de classe disponible',
              routePayload: '/messages',
            );
          }
        },
      );

      // 3. Suggestions & Replies
      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'suggestions',
        callback: (_) {
          debugPrint('Realtime Shell: suggestions updated -> refreshing');
          ref.invalidate(suggestionsProvider);
        },
      );

      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'suggestion_replies',
        callback: (payload) {
          debugPrint('Realtime Shell: suggestion_replies updated -> refreshing');
          ref.invalidate(suggestionsProvider);
          if (payload.eventType == PostgresChangeEvent.insert) {
            final record = payload.newRecord;
            final text = (record['reply_text'] ??
                    record['body'] ??
                    record['message'] ??
                    '')
                .toString();
            InAppNotificationBanner.show(
              title: 'Réponse à votre suggestion',
              message: text.isNotEmpty
                  ? text
                  : 'L\'administration a répondu à votre suggestion',
              icon: Icons.mark_chat_read_rounded,
              color: const Color(0xFF10B981),
              onTap: () {
                if (mounted) context.push('/suggestions');
              },
            );
            LocalNotificationService.showNotification(
              id: (record['id'] ?? '').hashCode,
              title: 'Réponse à votre suggestion',
              body: text.isNotEmpty
                  ? text
                  : 'L\'administration a répondu à votre suggestion',
              routePayload: '/suggestions',
            );
          }
        },
      );

      // 4. Documents
      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'documents',
        callback: (payload) {
          debugPrint('Realtime Shell: documents updated -> refreshing');
          ref.invalidate(allStudentDocumentsProvider);
          if (payload.eventType == PostgresChangeEvent.insert) {
            final record = payload.newRecord;
            final title = record['title']?.toString() ?? 'Nouveau document';
            final desc = record['description']?.toString() ?? '';
            InAppNotificationBanner.show(
              title: title,
              message: desc.isNotEmpty ? desc : 'Un nouveau document a été partagé',
              icon: Icons.folder_shared_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () {
                if (mounted) context.push('/documents');
              },
            );
            LocalNotificationService.showNotification(
              id: (record['id'] ?? '').hashCode,
              title: title,
              body: desc.isNotEmpty ? desc : 'Un nouveau document a été partagé',
              routePayload: '/documents',
            );
          }
        },
      );

      _globalRealtimeChannel?.subscribe();
    } catch (e) {
      debugPrint('Realtime shell setup error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResumeSync == null ||
          now.difference(_lastResumeSync!) > const Duration(seconds: 3)) {
        _lastResumeSync = now;
        ref.invalidate(semestersProvider);
        ref.invalidate(globalAnnouncementsProvider);
        ref.invalidate(classMessagesProvider);
        ref.invalidate(allStudentDocumentsProvider);
        ref.invalidate(suggestionsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes to connect/disconnect realtime
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.isAuthenticated) {
        _setupRealtime();
      } else {
        _tearDownRealtime();
      }
    });

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: BubbleNavBar(currentIndex: widget.currentIndex),
    );
  }
}
