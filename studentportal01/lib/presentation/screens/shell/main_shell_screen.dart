import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../providers/announcements_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/student_context_provider.dart';
import '../../providers/suggestions_provider.dart';
import '../../widgets/bubble_nav_bar.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/services/offline_cache_service.dart';
import '../documents/documents_screen.dart';

class InAppBannerData {
  final String title;
  final String message;
  final String? route;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const InAppBannerData({
    required this.title,
    required this.message,
    this.route,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });
}

/// Wraps authenticated app shell to manage FCM token sync and Supabase Realtime
/// provider refreshes plus deduplicated native OS foreground notifications and in-app alerts.
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
  InAppBannerData? _currentBanner;
  Timer? _bannerDismissTimer;
  Timer? _periodicCatchUpTimer;
  final Set<String> _alertedNotificationIds = {};

  void _loadAlertedIds(String userId) {
    try {
      final cached = OfflineCacheService.instance.getList('alerted_notification_ids_$userId');
      if (cached != null) {
        _alertedNotificationIds.addAll(cached.map((e) => e.toString()));
      }
    } catch (_) {}
  }

  void _markAsAlerted(String userId, String id) {
    _alertedNotificationIds.add(id);
    if (_alertedNotificationIds.length > 200) {
      _alertedNotificationIds.removeAll(_alertedNotificationIds.take(50).toList());
    }
    unawaited(OfflineCacheService.instance.setJson(
      'alerted_notification_ids_$userId',
      _alertedNotificationIds.toList(),
    ));
  }

  Future<void> _catchUpUnseenNotifications() async {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    final userId = session.user.id;
    if (_alertedNotificationIds.isEmpty) {
      _loadAlertedIds(userId);
    }

    try {
      final readIds = ref.read(readAnnouncementsProvider);
      final globalList = ref.read(globalAnnouncementsProvider).valueOrNull ?? [];
      final classList = ref.read(classMessagesProvider).valueOrNull ?? [];

      for (final a in globalList) {
        if (!readIds.contains(a.id) && !_alertedNotificationIds.contains(a.id)) {
          _markAsAlerted(userId, a.id);
          final title = a.title.trim().isNotEmpty ? a.title.trim() : 'Nouvelle notification';
          final body = a.body.trim().isNotEmpty ? a.body.trim() : 'Nouvelle notification disponible';
          final route = '/notifications?id=${a.id}';
          final dedupKey = 'announcements_global:${a.id}';

          _showInAppBanner(
            title: title,
            message: body,
            route: route,
            icon: Icons.campaign_rounded,
            iconColor: const Color(0xFF6D4CF6),
            iconBgColor: const Color(0xFF6D4CF6).withValues(alpha: 0.12),
          );

          LocalNotificationService.showNotification(
            id: LocalNotificationService.stableNotificationId(dedupKey),
            title: title,
            body: body,
            routePayload: route,
            dedupKey: dedupKey,
          );
          return;
        }
      }

      for (final m in classList) {
        if (!readIds.contains(m.id) && !_alertedNotificationIds.contains(m.id)) {
          _markAsAlerted(userId, m.id);
          final title = m.title.trim().isNotEmpty ? m.title.trim() : 'Nouveau message';
          final cleanBody = m.body.replaceFirst(RegExp(r'^\*\*@[^*]+\*\*\s*'), '').trim();
          final message = cleanBody.isNotEmpty ? cleanBody : 'Nouveau message disponible';
          final route = '/messages?id=${m.id}';
          final dedupKey = 'announcements_class:${m.id}';

          _showInAppBanner(
            title: title,
            message: message,
            route: route,
            icon: Icons.chat_bubble_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
          );

          LocalNotificationService.showNotification(
            id: LocalNotificationService.stableNotificationId(dedupKey),
            title: title,
            body: message,
            routePayload: route,
            dedupKey: dedupKey,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Catch-up unseen notifications error: $e');
    }
  }

  void _showInAppBanner({
    required String title,
    required String message,
    String? route,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    if (!mounted) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    _bannerDismissTimer?.cancel();
    setState(() {
      _currentBanner = InAppBannerData(
        title: title,
        message: message,
        route: route,
        icon: icon,
        iconColor: iconColor,
        iconBgColor: iconBgColor,
      );
    });

    _bannerDismissTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted && _currentBanner != null) {
        setState(() {
          _currentBanner = null;
        });
      }
    });
  }

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
        _loadAlertedIds(userId);
        unawaited(LocalNotificationService.syncDeviceToken(userId).catchError((_) {}));
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        _catchUpUnseenNotifications();
      }
    });

    _periodicCatchUpTimer?.cancel();
    _periodicCatchUpTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      if (mounted) {
        _catchUpUnseenNotifications();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerDismissTimer?.cancel();
    _periodicCatchUpTimer?.cancel();
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
      unawaited(LocalNotificationService.syncDeviceToken(userId).catchError((_) {}));

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

          if (payload.eventType == PostgresChangeEvent.insert) {
            final title =
                record['title']?.toString().trim().isNotEmpty == true
                    ? record['title']!.toString().trim()
                    : 'Nouvelle notification';
            final body = record['body']?.toString().trim() ?? '';
            final message =
                body.isNotEmpty ? body : 'Nouvelle notification disponible';
            final recId = record['id']?.toString();
            final route = recId != null && recId.isNotEmpty
                ? '/notifications?id=$recId'
                : '/notifications';
            final dedupKey = recId != null && recId.isNotEmpty
                ? 'announcements_global:$recId'
                : null;

            _showInAppBanner(
              title: title,
              message: message,
              route: route,
              icon: Icons.campaign_rounded,
              iconColor: const Color(0xFF6D4CF6),
              iconBgColor: const Color(0xFF6D4CF6).withValues(alpha: 0.12),
            );

            if (recId != null) _markAsAlerted(userId, recId);

            LocalNotificationService.showNotification(
              id: LocalNotificationService.stableNotificationId(
                  dedupKey ?? '$title|$message|$route'),
              title: title,
              body: message,
              routePayload: route,
              dedupKey: dedupKey,
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
          String? targetStudentId;
          if (recPayload is Map) {
            targetStudentId = recPayload['target_student_id']?.toString();
            if (targetStudentId != null &&
                targetStudentId.isNotEmpty &&
                targetStudentId != userId) {
              return;
            }
          }

          debugPrint('Realtime Shell: announcements_class updated -> refreshing');
          ref.invalidate(classMessagesProvider);

          if (payload.eventType == PostgresChangeEvent.insert) {
            final rawTitle = record['title']?.toString().trim() ?? '';
            final title = rawTitle.isNotEmpty
                ? rawTitle
                : (targetStudentId != null && targetStudentId.isNotEmpty
                    ? 'Nouveau message'
                    : 'Nouveau message de classe');
            final cleanBody = (record['body']?.toString() ?? '')
                .replaceFirst(RegExp(r'^\*\*@[^*]+\*\*\s*'), '')
                .trim();
            final message = cleanBody.isNotEmpty
                ? cleanBody
                : 'Nouveau message disponible';
            final recId = record['id']?.toString();
            final route = recId != null && recId.isNotEmpty
                ? '/messages?id=$recId'
                : '/messages';
            final dedupKey = recId != null && recId.isNotEmpty
                ? 'announcements_class:$recId'
                : null;

            _showInAppBanner(
              title: title,
              message: message,
              route: route,
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
            );

            if (recId != null) _markAsAlerted(userId, recId);

            LocalNotificationService.showNotification(
              id: LocalNotificationService.stableNotificationId(
                  dedupKey ?? '$title|$message|$route'),
              title: title,
              body: message,
              routePayload: route,
              dedupKey: dedupKey,
            );
          }
        },
      );

      // 3. Student personal announcements (Messages ciblés)
      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'announcements_student',
        callback: (payload) {
          if (!mounted) return;
          final record = payload.newRecord;
          final recStudentId = record['student_id']?.toString() ??
              (record['payload'] is Map ? record['payload']['target_student_id']?.toString() : null);
          if (recStudentId != null && recStudentId.isNotEmpty && recStudentId != userId) {
            return;
          }

          debugPrint('Realtime Shell: announcements_student updated -> refreshing');
          ref.invalidate(classMessagesProvider);
          ref.invalidate(globalAnnouncementsProvider);

          if (payload.eventType == PostgresChangeEvent.insert) {
            final title = record['title']?.toString().trim().isNotEmpty == true
                ? record['title']!.toString().trim()
                : 'Nouveau message personnel';
            final body = record['body']?.toString().trim() ?? '';
            final message = body.isNotEmpty ? body : 'Nouveau message disponible';
            final recId = record['id']?.toString();
            final route = recId != null && recId.isNotEmpty ? '/messages?id=$recId' : '/messages';
            final dedupKey = recId != null && recId.isNotEmpty ? 'announcements_student:$recId' : null;

            _showInAppBanner(
              title: title,
              message: message,
              route: route,
              icon: Icons.mark_email_unread_rounded,
              iconColor: const Color(0xFF4F46E5),
              iconBgColor: const Color(0xFF4F46E5).withValues(alpha: 0.12),
            );

            if (recId != null) _markAsAlerted(userId, recId);

            LocalNotificationService.showNotification(
              id: LocalNotificationService.stableNotificationId(
                  dedupKey ?? '$title|$message|$route'),
              title: title,
              body: message,
              routePayload: route,
              dedupKey: dedupKey,
            );
          }
        },
      );

      // 4. Suggestions & Replies
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
              // If verification fails, still refresh provider quietly without popping another user's alert
              if (mounted) ref.invalidate(suggestionsProvider);
              return;
            }
          }

          if (!mounted) return;
          debugPrint('Realtime Shell: suggestion_replies updated -> refreshing');
          ref.invalidate(suggestionsProvider);

          if (payload.eventType == PostgresChangeEvent.insert) {
            final text = (record['reply_text'] ??
                    record['body'] ??
                    record['message'] ??
                    '')
                .toString()
                .trim();
            final message = text.isNotEmpty
                ? text
                : 'L\'administration a répondu à votre suggestion.';
            final recId = record['id']?.toString();
            final dedupKey = recId != null && recId.isNotEmpty
                ? 'suggestion_replies:$recId'
                : null;

            _showInAppBanner(
              title: 'Réponse à votre suggestion',
              message: message,
              route: '/suggestions',
              icon: Icons.reply_rounded,
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
            );

            LocalNotificationService.showNotification(
              id: LocalNotificationService.stableNotificationId(
                  dedupKey ?? 'Réponse à votre suggestion|$message|/suggestions'),
              title: 'Réponse à votre suggestion',
              body: message,
              routePayload: '/suggestions',
              dedupKey: dedupKey,
            );
          }
        },
      );

      // 5. Documents
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
            final rawTitle = record['title']?.toString().trim() ?? '';
            final title =
                'Nouveau document : ${rawTitle.isNotEmpty ? rawTitle : 'Document'}';
            final cleanDesc = desc
                .replaceAll(RegExp(r'\[Semestre:\s*\d+\]'), '')
                .replaceAll(RegExp(r'\[Student:\s*[^\]]+\]'), '')
                .replaceAll(RegExp(r'\[Type:\s*[^\]]+\]'), '')
                .trim();
            final message = cleanDesc.isNotEmpty
                ? cleanDesc
                : 'Un nouveau document a été partagé.';
            final recId = record['id']?.toString();
            final route = recId != null && recId.isNotEmpty
                ? '/documents?id=$recId'
                : '/documents';
            final dedupKey =
                recId != null && recId.isNotEmpty ? 'documents:$recId' : null;

            _showInAppBanner(
              title: title,
              message: message,
              route: route,
              icon: Icons.description_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            );

            if (recId != null) _markAsAlerted(userId, recId);

            LocalNotificationService.showNotification(
              id: LocalNotificationService.stableNotificationId(
                  dedupKey ?? '$title|$message|$route'),
              title: title,
              body: message,
              routePayload: route,
              dedupKey: dedupKey,
            );
          }
        },
      );

      // 5. School branding updates (logo_url, name)
      _globalRealtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'schools',
        callback: (payload) {
          if (!mounted) return;
          final mySchoolId = _currentSchoolId;
          final recSchoolId = payload.newRecord['id']?.toString();
          if (mySchoolId != null &&
              recSchoolId != null &&
              recSchoolId.isNotEmpty &&
              recSchoolId != mySchoolId) {
            return;
          }
          debugPrint('Realtime Shell: school branding updated -> refreshing');
          ref.invalidate(schoolProvider);
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
        ref.invalidate(schoolProvider);
        ref.invalidate(globalAnnouncementsProvider);
        ref.invalidate(classMessagesProvider);
        ref.invalidate(allStudentDocumentsProvider);
        ref.invalidate(suggestionsProvider);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            _catchUpUnseenNotifications();
          }
        });
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

    return Stack(
      children: [
        widget.child,
        if (_currentBanner != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _InAppFloatingNotificationBanner(
                  banner: _currentBanner!,
                  onDismiss: () {
                    _bannerDismissTimer?.cancel();
                    setState(() => _currentBanner = null);
                  },
                  onTap: () {
                    final targetRoute = _currentBanner?.route;
                    _bannerDismissTimer?.cancel();
                    setState(() => _currentBanner = null);
                    if (targetRoute != null) {
                      LocalNotificationService.navigateToRoute(targetRoute);
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
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

class _InAppFloatingNotificationBanner extends StatelessWidget {
  final InAppBannerData banner;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _InAppFloatingNotificationBanner({
    required this.banner,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: banner.iconColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: banner.iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(banner.icon, size: 20, color: banner.iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                banner.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'À l\'instant',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          banner.message,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

