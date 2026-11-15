import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/security_trace_http_client.dart';

/// Supabase configuration for Admin Dashboard
/// Uses the same Supabase project as the student app
class SupabaseConfig {
  static const String url = 'https://cazuauxivrboygehrkij.supabase.co';
  
  /// Optional Service Role Key for local development test environments only.
  /// NEVER hardcode production service_role keys into client code.
  /// All privileged actions are executed via secure Edge Functions.
  static const String serviceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: '',
  );
  
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNhenVhdXhpdnJib3lnZWhya2lqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc4ODQzMTYsImV4cCI6MjA4MzQ2MDMxNn0._rYkNtubGQo745cX-YApjWQyYC4s8r37SEa6AoiVppo';

  /// Storage bucket name for announcement attachments
  /// CREATE THIS BUCKET IN SUPABASE DASHBOARD: Storage > New bucket > "announcement-attachments" > Public
  static const String attachmentsBucket = 'announcement-attachments';
  
  /// Storage bucket name for suggestion attachments  
  /// CREATE THIS BUCKET IN SUPABASE DASHBOARD: Storage > New bucket > "suggestion-attachments" > Public
  static const String suggestionAttachmentsBucket = 'suggestion-attachments';

  /// Main client for user auth and normal operations
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Admin operations are securely executed through Edge Functions.
  /// For backward compatibility with existing screen queries, this returns the authenticated
  /// client governed by tenant-isolated RLS. If an explicit environment key is supplied
  /// during local testing, it uses it.
  static SupabaseClient? _adminClient;
  static SupabaseClient get adminClient {
    if (serviceRoleKey.isNotEmpty) {
      _adminClient ??= SupabaseClient(url, serviceRoleKey);
      return _adminClient!;
    }
    return client;
  }

  static Future<void> initialize() async {
    // Use anon key for normal auth operations and attach security/observability client
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      httpClient: SecurityTraceHttpClient(
        appSurface: 'school_admin',
        onForceDisconnect: (reason) {
          debugPrint('[SECURITY] School Admin forced disconnect: $reason');
        },
      ),
    );
  }

  /// Check if a storage bucket exists
  static Future<bool> bucketExists(String bucketName) async {
    try {
      final buckets = await client.storage.listBuckets();
      return buckets.any((b) => b.name == bucketName);
    } catch (_) {
      return false;
    }
  }
}
