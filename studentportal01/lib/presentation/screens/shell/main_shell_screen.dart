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

/// Wraps authenticated app shell to manage FCM token sync and Supabase Realtime
/// foreground notification banners and local alerts.
class RealtimeNotificationWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const RealtimeNotificationWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<RealtimeNotificationWrapper> createState() =>
      _RealtimeNotificationWrapperState();
}

class _RealtimeNotificationWrapperState
    extends ConsumerState<RealtimeNotificationWrapper>
    with WidgetsBindingObserver {
  DateTime? _lastResumeSync;
  RealtimeChannel? _globalRealtimeChannel;
  String? _subscribedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _setupRealtime();
      await LocalNotificationService.requestPermissions();
      if (!mounted) return;
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      if (userId != null) {
        LocalNotificationService.syncDeviceToken(userId);
      }
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

  String? get _currentSchoolId {
    final auth = ref.read(authProvider);
    final ctx = ref.read(studentContextProvider).valueOrNull;
    return ctx?.schoolId ?? auth.user?.schoolId ?? auth.enrollment?.classInfo?.schoolId;
  }

  String? get _currentClassId {
    final auth = ref.read(authProvider);
    final ctx = ref.read(studentContextProvider).valueOrNull;
    return ctx?.classId ?? auth.enrollment?.classId;
  }

  void _setupRealtime() {
    try {
      if (!mounted) return;
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
          if (!mounted) return;
          final record = payload.newRecord;
          final mySchoolId = _currentSchoolId;
          final recSchoolId = record['school_id']?.toString();
          if (mySchoolId != null &&
              recSchoolId != null &&
              recSchoolId.isNotEmpty &&
              recSchoolId != mySchoolId) {
            return;
          }

          debugPrint('Realtime Shell: announcements_global updated -> refreshing');
          ref.invalidate(globalAnnouncementsProvider);

          if (payload.eventType == PostgresChangeEvent.insert &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) {
            final title =
                record['title']?.toString() ?? 'Nouvelle notification';
            final body = record['body']?.toString() ?? '';
            final message =
                body.isNotEmpty ? body : 'Nouvelle notification disponible';
            InAppNotificationBanner.show(
              title: title,
              message: message,
              icon: Icons.notifications_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                if (mounted) context.push('/notifications');
              },
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
          if (!mounted) return;
          final record = payload.newRecord;
          final mySchoolId = _currentSchoolId;
          final recSchoolId = record['school_id']?.toString();
          if (mySchoolId != null &&
              recSchoolId != null &&
              recSchoolId.isNotEmpty &&
              recSchoolId != mySchoolId) {
            return;
          }

          final myClassId = _currentClassId;
          final recClassId = record['class_id']?.toString();
          if (myClassId != null &&
              recClassId != null &&
              recClassId.isNotEmpty &&
              recClassId != myClassId) {
            return;
          }

          final recPayload = record['payload'];
          if (recPayload is Map) {
            final targetStudentId = recPayload['target_student_id']?.toString();
            if (targetStudentId != null &&
                targetStudentId.isNotEmpty &&
                targetStudentId != userId) {
              return;
            }
          }

          debugPrint('Realtime Shell: announcements_class updated -> refreshing');
          ref.invalidate(classMessagesProvider);

          if (payload.eventType == PostgresChangeEvent.insert &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) {
            final title = record['title']?.toString() ?? 'Nouveau message';
            final body = record['body']?.toString() ?? '';
            final message =
                body.isNotEmpty ? body : 'Nouveau message de classe disponible';
            InAppNotificationBanner.show(
              title: title,
              message: message,
              icon: Icons.mail_rounded,
              color: const Color(0xFF6B5CE7),
              onTap: () {
                if (mounted) context.push('/messages');
              },
            );
          }
        },
      );

      // 3. Suggestions & Replies
      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'suggestions',
        callback: (payload) {
          if (!mounted) return;
          final studentId = payload.newRecord['student_id']?.toString() ??
              payload.oldRecord['student_id']?.toString();
          if (studentId != null && studentId.isNotEmpty && studentId != userId) {
            return;
          }
          debugPrint('Realtime Shell: suggestions updated -> refreshing');
          ref.invalidate(suggestionsProvider);
        },
      );

      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'suggestion_replies',
        callback: (payload) async {
          if (!mounted) return;
          final record = payload.newRecord;
          final suggestionId = record['suggestion_id']?.toString();

          if (suggestionId != null && suggestionId.isNotEmpty) {
            try {
              final suggestion = await supabase
                  .from('suggestions')
                  .select('student_id')
                  .eq('id', suggestionId)
                  .maybeSingle();
              if (!mounted) return;
              if (suggestion == null ||
                  suggestion['student_id']?.toString() != userId) {
                return;
              }
            } catch (_) {
              // If verification fails, still refresh provider quietly without popping another user's banner
              if (mounted) ref.invalidate(suggestionsProvider);
              return;
            }
          }

          if (!mounted) return;
          debugPrint('Realtime Shell: suggestion_replies updated -> refreshing');
          ref.invalidate(suggestionsProvider);

          if (payload.eventType == PostgresChangeEvent.insert &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) {
            final text = (record['reply_text'] ??
                    record['body'] ??
                    record['message'] ??
                    '')
                .toString();
            final message = text.isNotEmpty
                ? text
                : 'L\'administration a répondu à votre suggestion';
            InAppNotificationBanner.show(
              title: 'Réponse à votre suggestion',
              message: message,
              icon: Icons.mark_chat_read_rounded,
              color: const Color(0xFF10B981),
              onTap: () {
                if (mounted) context.push('/suggestions');
              },
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
          if (!mounted) return;
          final record = payload.newRecord;
          final mySchoolId = _currentSchoolId;
          final recSchoolId = record['school_id']?.toString();
          if (mySchoolId != null &&
              recSchoolId != null &&
              recSchoolId.isNotEmpty &&
              recSchoolId != mySchoolId) {
            return;
          }

          final myClassId = _currentClassId;
          final recClassId = record['class_id']?.toString();
          if (myClassId != null &&
              recClassId != null &&
              recClassId.isNotEmpty &&
              recClassId != myClassId) {
            return;
          }

          final desc = record['description']?.toString() ?? '';
          final studentMatch =
              RegExp(r'\[Student:\s*([^|\]]+)').firstMatch(desc);
          if (studentMatch != null) {
            final targetStudentId = studentMatch.group(1)?.trim();
            if (targetStudentId != null &&
                targetStudentId.isNotEmpty &&
                targetStudentId != userId) {
              return;
            }
          }

          debugPrint('Realtime Shell: documents updated -> refreshing');
          ref.invalidate(allStudentDocumentsProvider);

          if (payload.eventType == PostgresChangeEvent.insert &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) {
            final title = record['title']?.toString() ?? 'Nouveau document';
            final cleanDesc = desc
                .replaceAll(RegExp(r'\[Semestre:\s*\d+\]'), '')
                .replaceAll(RegExp(r'\[Student:\s*[^\]]+\]'), '')
                .replaceAll(RegExp(r'\[Type:\s*[^\]]+\]'), '')
                .trim();
            final message = cleanDesc.isNotEmpty
                ? cleanDesc
                : 'Un nouveau document a été partagé';
            InAppNotificationBanner.show(
              title: title,
              message: message,
              icon: Icons.folder_shared_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () {
                if (mounted) context.push('/documents');
              },
            );
          }
        },
      );

      _globalRealtimeChannel?.subscribe((status, error) {
        debugPrint(
          'Realtime Shell subscription status: $status, error: $error',
        );
      });
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
        final userId = Supabase.instance.client.auth.currentSession?.user.id;
        if (userId != null) {
          LocalNotificationService.syncDeviceToken(userId);
        }
        if (!mounted) return;
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

    return widget.child;
  }
}

class MainShellScreen extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const MainShellScreen({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return RealtimeNotificationWrapper(
      child: Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: BubbleNavBar(currentIndex: currentIndex),
      ),
    );
  }
}

