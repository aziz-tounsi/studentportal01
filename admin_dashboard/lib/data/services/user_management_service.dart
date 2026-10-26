import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

/// Secure service to handle user creation, deletion, and credentials reset.
/// Routes privileged operations through server-side Edge Functions without exposing
/// the Supabase service_role key to the client application.
class UserManagementService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Creates a new user in Supabase Auth and public.users via Edge Function
  static Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
    String? studentCode,
    String? classId,
    String? groupId,
    String? academicYearId,
    String? dateOfBirth,
    String? address,
    String? niveauCode,
    String? sectionCode,
    String? gender,
    String? nationality,
    String? schoolId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-users',
        body: {
          'action': 'create_user',
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
          'phone': phone,
          'student_code': studentCode,
          'class_id': classId,
          'group_id': groupId,
          'academic_year_id': academicYearId,
          'date_of_birth': dateOfBirth,
          'address': address,
          'niveau_code': niveauCode,
          'section_code': sectionCode,
          'gender': gender,
          'nationality': nationality,
          'school_id': schoolId,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }

      final errorMsg = response.data is Map ? response.data['error'] : 'Status ${response.status}';
      throw Exception(errorMsg ?? 'Failed to invoke manage-users function');
    } catch (e) {
      debugPrint('UserManagementService: Edge function failed ($e). Checking local fallback...');
      // Fallback only if serviceRoleKey was explicitly supplied in environment for local dev
      if (SupabaseConfig.serviceRoleKey.isNotEmpty) {
        debugPrint('UserManagementService: Executing direct serviceRole fallback for local dev.');
        final authClient = SupabaseConfig.adminClient;
        final authResp = await authClient.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: password,
            emailConfirm: true,
            userMetadata: {'role': role, 'full_name': fullName},
          ),
        );
        final newUserId = authResp.user?.id;
        if (newUserId == null) throw Exception('Local auth user creation failed');

        await authClient.from('users').insert({
          'id': newUserId,
          'school_id': schoolId,
          'email': email,
          'full_name': fullName,
          'role': role,
          'phone': phone,
          'student_code': studentCode,
          'date_of_birth': dateOfBirth,
          'address': address,
          'niveau_code': niveauCode,
          'section_code': sectionCode,
          'gender': gender,
          'nationality': nationality,
          'initial_password': password,
        });

        if (role == 'student' && classId != null && academicYearId != null) {
          await authClient.from('enrollments').insert({
            'school_id': schoolId,
            'user_id': newUserId,
            'class_id': classId,
            'group_id': groupId,
            'academic_year_id': academicYearId,
            'student_code': studentCode,
            'is_active': true,
          });
        }

        return {
          'success': true,
          'user': {'id': newUserId, 'email': email, 'password': password},
        };
      }
      rethrow;
    }
  }

  /// Deletes a user by ID
  static Future<bool> deleteUser(String userId) async {
    try {
      final response = await _client.functions.invoke(
        'manage-users',
        body: {
          'action': 'delete_user',
          'user_id': userId,
        },
      );

      if (response.status == 200) {
        return true;
      }
      final errorMsg = response.data is Map ? response.data['error'] : 'Status ${response.status}';
      throw Exception(errorMsg ?? 'Delete user failed');
    } catch (e) {
      if (SupabaseConfig.serviceRoleKey.isNotEmpty) {
        final authClient = SupabaseConfig.adminClient;
        try {
          await authClient.auth.admin.deleteUser(userId);
        } catch (_) {}
        await authClient.from('users').delete().eq('id', userId);
        return true;
      }
      rethrow;
    }
  }

  /// Resets a user's password
  static Future<String> resetPassword(String userId, {String? newPassword}) async {
    try {
      final response = await _client.functions.invoke(
        'manage-users',
        body: {
          'action': 'reset_password',
          'user_id': userId,
          'new_password': newPassword,
        },
      );

      if (response.status == 200 && response.data != null) {
        return response.data['password'] as String;
      }
      final errorMsg = response.data is Map ? response.data['error'] : 'Status ${response.status}';
      throw Exception(errorMsg ?? 'Password reset failed');
    } catch (e) {
      if (SupabaseConfig.serviceRoleKey.isNotEmpty) {
        final pass = newPassword ?? 'Pass@${DateTime.now().millisecondsSinceEpoch}';
        final authClient = SupabaseConfig.adminClient;
        await authClient.auth.admin.updateUserById(
          userId,
          attributes: AdminUserAttributes(password: pass),
        );
        await authClient.from('users').update({
          'initial_password': pass,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        return pass;
      }
      rethrow;
    }
  }

  /// Bulk deletes users by ID list
  static Future<Map<String, int>> bulkDeleteUsers(List<String> userIds) async {
    try {
      final response = await _client.functions.invoke(
        'manage-users',
        body: {
          'action': 'bulk_delete_users',
          'user_ids': userIds,
        },
      );

      if (response.status == 200 && response.data != null) {
        return {
          'deleted': (response.data['deleted'] as num?)?.toInt() ?? 0,
          'failed': (response.data['failed'] as num?)?.toInt() ?? 0,
        };
      }
      throw Exception('Bulk delete failed with status ${response.status}');
    } catch (e) {
      int deleted = 0;
      int failed = 0;
      for (final id in userIds) {
        try {
          await deleteUser(id);
          deleted++;
        } catch (_) {
          failed++;
        }
      }
      return {'deleted': deleted, 'failed': failed};
    }
  }
}
