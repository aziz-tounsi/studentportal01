import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/services/school_branding_service.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/school_logo_preview.dart';
import '../../widgets/skeleton_loader.dart';

class SchoolInfoNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return await _loadSchool();
  }

  Future<String?> _getSchoolId() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final resp = await supabase
        .from('users')
        .select('school_id')
        .eq('id', userId)
        .maybeSingle();
    return resp?['school_id'] as String?;
  }

  Future<Map<String, dynamic>> _loadSchool() async {
    try {
      final schoolId = await _getSchoolId();
      if (schoolId == null) {
        return {'id': null, 'name': '', 'logo_url': null, 'bio': ''};
      }
      final supabase = Supabase.instance.client;
      Map<String, dynamic>? response;
      try {
        response = await supabase
            .from('schools')
            .select('id, name, logo_url, address, phone, email, bio')
            .eq('id', schoolId)
            .maybeSingle();
      } catch (_) {
        response = await supabase
            .from('schools')
            .select('id, name, logo_url, address, phone, email')
            .eq('id', schoolId)
            .maybeSingle();
      }
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return {'id': schoolId, 'name': '', 'logo_url': null, 'bio': ''};
    } catch (e) {
      return {'id': null, 'name': '', 'logo_url': null, 'bio': ''};
    }
  }

  Future<String?> saveSchool(Map<String, dynamic> data) async {
    try {
      final schoolId = await _getSchoolId();
      if (schoolId == null) {
        return 'Aucun établissement associé à votre compte.';
      }

      final supabase = Supabase.instance.client;
      final existing = await supabase
          .from('schools')
          .select('id')
          .eq('id', schoolId)
          .maybeSingle();

      final current = state.value ?? {};
      final merged = {
        ...current,
        'id': schoolId,
        'name': data['name'],
        'logo_url': data['logo_url'],
        'bio': data['bio'],
      };

      final updatePayload = {
        'name': data['name'],
        'logo_url': data['logo_url'],
        'bio': data['bio'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        try {
          await supabase.from('schools').update(updatePayload).eq('id', schoolId);
        } catch (_) {
          // If bio column is not yet added in Supabase schema
          await supabase.from('schools').update({
            'name': data['name'],
            'logo_url': data['logo_url'],
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', schoolId);
        }
      } else {
        try {
          await supabase.from('schools').insert({
            'id': schoolId,
            ...updatePayload,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {
          await supabase.from('schools').insert({
            'id': schoolId,
            'name': data['name'],
            'logo_url': data['logo_url'],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      state = AsyncValue.data(merged);
      ref.invalidate(currentSchoolBrandingProvider);
      return null;
    } catch (e) {
      return UserFriendlyError.format(
        e,
        fallback: 'Erreur lors de la sauvegarde des informations de l\'école.',
      );
    }
  }
}

final schoolInfoProvider =
    AsyncNotifierProvider<SchoolInfoNotifier, Map<String, dynamic>>(
  SchoolInfoNotifier.new,
);

class SchoolInfoScreen extends ConsumerStatefulWidget {
  const SchoolInfoScreen({super.key});

  @override
  ConsumerState<SchoolInfoScreen> createState() => _SchoolInfoScreenState();
}

class _SchoolInfoScreenState extends ConsumerState<SchoolInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isLoading = false;
  String? _logoUrl;
  String? _schoolId;
  bool _populated = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_populated) return;
    _populated = true;
    _nameController.text = data['name'] ?? '';
    _bioController.text = data['bio'] ?? '';
    setState(() {
      _schoolId = data['id'] as String?;
      _logoUrl = data['logo_url'] as String?;
    });
  }

  Future<void> _pickLogo() async {
    setState(() => _uploadingLogo = true);
    try {
      final publicUrl = await SchoolBrandingService.pickAndUploadLogo(
        schoolId: _schoolId ?? ref.read(schoolInfoProvider).value?['id'] as String?,
      );
      if (publicUrl == null || !mounted) return;
      setState(() {
        _logoUrl = publicUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UserFriendlyError.format(
                e,
                fallback: 'Impossible de téléverser le logo pour le moment.',
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  void _resetToDefaultLogo() {
    setState(() {
      _logoUrl = null;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'logo_url': _logoUrl,
      'bio': _bioController.text.trim(),
    };

    final errorMessage =
        await ref.read(schoolInfoProvider.notifier).saveSchool(data);
    final success = errorMessage == null;

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: AppColors.textOnPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                success ? 'Informations sauvegardées avec succès!' : errorMessage,
              ),
            ),
          ],
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(schoolInfoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/settings'),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: schoolAsync.when(
                    loading: () =>
                        const SchoolInfoSkeletonLoader(),
                    error: (e, _) => Center(
                      child: Text(
                        UserFriendlyError.format(
                          e,
                          fallback: 'Unable to load school information right now. Please try again.',
                        ),
                      ),
                    ),
                    data: (data) {
                      if (_nameController.text.isEmpty &&
                          data['name'] != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _populateFields(data);
                        });
                      }
                      return _buildForm(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informations de l\'école',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                'Nom, logo et paramètres de votre établissement',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveChanges,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: IosLoader.small(color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(
                _isLoading ? 'Sauvegarde...' : 'Sauvegarder',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                shadowColor: const Color(0xFF6D4CF6).withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              title: 'Identité de l\'établissement',
              icon: Icons.apartment_outlined,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Nom de l\'école',
                  hint: 'Lycée Pythagore',
                  icon: Icons.school_outlined,
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'Le nom est requis' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _bioController,
                  label: 'Bio de l\'établissement (À propos)',
                  hint: 'Présentez votre établissement, sa vision pédagogique et ses valeurs...',
                  icon: Icons.info_outline,
                  maxLines: 4,
                  helperText: 'Affichée dans la section "À propos" de l\'application mobile',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Logo de l\'école',
              icon: Icons.image_outlined,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _uploadingLogo ? null : _pickLogo,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: _uploadingLogo
                            ? const Center(child: IosLoader())
                            : SchoolLogoPreview(
                                logoUrl: _logoUrl,
                                size: 116,
                                borderRadius: 14,
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Logo de l\'établissement',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ce logo s\'affiche pour votre école dans l\'application mobile et l\'espace administration.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _uploadingLogo ? null : _pickLogo,
                                icon: const Icon(Icons.upload, size: 18),
                                label: const Text('Changer le logo'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6D4CF6),
                                  side: const BorderSide(
                                    color: Color(0xFF6D4CF6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                ),
                              ),
                              if (_logoUrl != null && _logoUrl!.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed:
                                      _uploadingLogo ? null : _resetToDefaultLogo,
                                  icon: const Icon(Icons.restart_alt, size: 18),
                                  label: const Text('Logo par défaut'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF64748B),
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4B5563), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            if (helperText != null) ...[
              const SizedBox(width: 8),
              Text(
                '($helperText)',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF6D4CF6),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
