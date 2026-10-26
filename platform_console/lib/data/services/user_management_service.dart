import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required String schoolId,
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
      return {
        'success': false,
        'error': response.data?['error'] ?? 'HTTP ${response.status}',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
