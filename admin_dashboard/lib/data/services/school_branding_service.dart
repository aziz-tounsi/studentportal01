import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/providers/auth_provider.dart';

/// Shared provider exposing the current logged-in tenant school's name & logo URL.
final currentSchoolBrandingProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authProvider).user;
  final schoolId = user?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return null;

  final resp = await Supabase.instance.client
      .from('schools')
      .select('id, name, logo_url, primary_color, secondary_color')
      .eq('id', schoolId)
      .maybeSingle();

  return resp == null ? null : Map<String, dynamic>.from(resp);
});

/// Shared helper for uploading school logos to Supabase Storage (`profiles/logos/...`).
class SchoolBrandingService {
  static const String defaultLogoAsset = 'assets/images/app_logo.png';
  static const String _bucket = 'profiles';

  /// Opens gallery/file picker and uploads the chosen logo image.
  /// Returns the public URL, or `null` if the user cancelled selection.
  static Future<String?> pickAndUploadLogo({String? schoolId}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final ext = _extensionFromFile(image);
    final sanitizedId = (schoolId ?? 'new').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final fileName = '${sanitizedId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'logos/$fileName';
    final mimeType = image.mimeType ?? _mimeFromExtension(ext);

    await Supabase.instance.client.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );

    return Supabase.instance.client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  static String _extensionFromFile(XFile file) {
    final name = file.name;
    if (name.contains('.')) {
      final ext = name.split('.').last.toLowerCase();
      if (ext.isNotEmpty && !ext.contains('/')) return ext;
    }
    final path = file.path;
    if (!path.startsWith('blob:') && path.contains('.')) {
      final dotExt = path.split('.').last.toLowerCase();
      if (dotExt.isNotEmpty && !dotExt.contains('/')) return dotExt;
    }
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.contains('/')) {
      final sub = mimeType.split('/').last.toLowerCase();
      if (sub == 'jpeg') return 'jpg';
      if (sub.isNotEmpty) return sub;
    }
    return 'png';
  }

  static String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/png';
    }
  }
}
