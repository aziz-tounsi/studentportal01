import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/connectivity_service.dart';
import '../../data/models/school_model.dart';
import '../../data/services/offline_cache_service.dart';
import 'auth_provider.dart';

final schoolProvider = FutureProvider<SchoolModel?>((ref) {
  final schoolId = ref.watch(authProvider.select((s) => s.user?.schoolId));
  if (schoolId == null) return Future.value(null);
  return _fetchSchool(schoolId);
});

Future<SchoolModel?> _fetchSchool(String schoolId) async {
  final cacheKey = 'school_$schoolId';
  try {
    final supabase = Supabase.instance.client;
    Map<String, dynamic>? response;
    try {
      response = await supabase
          .from('schools')
          .select('id, name, logo_url, address, phone, email, code, primary_color, secondary_color, bio, created_at')
          .eq('id', schoolId)
          .maybeSingle();
    } catch (_) {
      response = await supabase
          .from('schools')
          .select('id, name, logo_url, address, phone, email, code, primary_color, secondary_color, created_at')
          .eq('id', schoolId)
          .maybeSingle();
    }
    if (response != null) {
      final school = SchoolModel.fromJson(response);
      OfflineCacheService.instance.setJson(cacheKey, school.toJson());
      ConnectivityService.instance.reportNetworkSuccess();
      return school;
    }
  } catch (e) {
    ConnectivityService.instance.reportNetworkError(e);
  }

  final cached = OfflineCacheService.instance.getMap(cacheKey);
  if (cached != null) {
    return SchoolModel.fromJson(cached);
  }

  return null;
}
