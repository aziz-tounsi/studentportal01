import 'package:flutter/foundation.dart';
import '../../core/config/supabase_config.dart';

class FcmPushService {
  static final _supabase = SupabaseConfig.client;

  /// Dispatch a push notification to specific users or broadcast
  static Future<void> sendPush({
    required String title,
    required String body,
    List<String>? targetUserIds,
    String? targetClassId,
    String? targetSchoolId,
    String route = '/notifications',
    Map<String, dynamic>? extraData,
  }) async {
    try {
      // 1. Resolve user IDs if class or school target
      List<String> userIds = targetUserIds != null ? List.from(targetUserIds) : [];

      if (targetClassId != null && targetClassId.isNotEmpty) {
        final enrollments = await _supabase
            .from('enrollments')
            .select('user_id')
            .eq('class_id', targetClassId)
            .eq('is_active', true);
        final classUserIds = (enrollments as List)
            .map((e) => e['user_id'] as String?)
            .whereType<String>()
            .toList();
        userIds.addAll(classUserIds);
      } else if (targetSchoolId != null && targetSchoolId.isNotEmpty && userIds.isEmpty) {
        final schoolUsers = await _supabase
            .from('users')
            .select('id')
            .eq('school_id', targetSchoolId)
            .eq('role', 'student');
        final schoolUserIds = (schoolUsers as List)
            .map((u) => u['id'] as String?)
            .whereType<String>()
            .toList();
        userIds.addAll(schoolUserIds);
      }

      userIds = userIds.toSet().toList();

      // 2. Invoke Edge Function for push delivery
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'title': title,
          'body': body,
          'userIds': userIds,
          'route': route,
          'data': extraData ?? {},
        },
      );
      debugPrint('Push dispatched via Edge Function for ${userIds.length} users');
    } catch (e) {
      debugPrint('Push dispatch skipped or failed: $e');
    }
  }
}
