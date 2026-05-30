import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/school_model.dart';
import 'auth_provider.dart';

final schoolProvider = FutureProvider<SchoolModel?>((ref) {
  final schoolId = ref.watch(authProvider.select((s) => s.user?.schoolId));
  if (schoolId == null) return Future.value(null);
  return _fetchSchool(schoolId);
});

Future<SchoolModel?> _fetchSchool(String schoolId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('schools')
      .select('id, name, logo_url, address, phone, email, created_at')
      .eq('id', schoolId)
      .maybeSingle();
  if (response == null) return null;
  return SchoolModel.fromJson(response);
}
