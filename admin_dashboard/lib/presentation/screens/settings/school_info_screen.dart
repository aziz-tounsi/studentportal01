import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/services/school_branding_service.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/school_logo_preview.dart';

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
        return {'id': null, 'name': '', 'logo_url': null};
      }
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('schools')
          .select('id, name, logo_url, address, phone, email')
          .eq('id', schoolId)
          .maybeSingle();
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return {'id': schoolId, 'name': '', 'logo_url': null};
    } catch (e) {
      return {'id': null, 'name': '', 'logo_url': null};
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
      };

      if (existing != null) {
        await supabase
            .from('schools')
            .update({
              'name': data['name'],
              'logo_url': data['logo_url'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', schoolId);
      } else {
        await supabase.from('schools').insert({
          'id': schoolId,
          'name': data['name'],
          'logo_url': data['logo_url'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
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
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _logoUrl;
  String? _schoolId;
  bool _populated = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_populated) return;
    _populated = true;
    _nameController.text = data['name'] ?? '';
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
        _hasChanges = true;
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
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'logo_url': _logoUrl,
    };

    final errorMessage =
        await ref.read(schoolInfoProvider.notifier).saveSchool(data);
    final success = errorMessage == null;

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (success) _hasChanges = false;
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
                        const Center(child: IosLoader()),
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
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.business,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informations de l\'école',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Modifications non sauvegardées',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveChanges,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: IosLoader.small(color: AppColors.textOnPrimary),
                  )
                : const Icon(Icons.save),
            label: Text(_isLoading ? 'Sauvegarde...' : 'Sauvegarder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
        onChanged: () => setState(() => _hasChanges = true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              title: 'Identité de l\'établissement',
              icon: Icons.business,
              iconColor: const Color(0xFF10B981),
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Nom de l\'école',
                  hint: 'Lycée Pythagore',
                  icon: Icons.school_outlined,
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'Le nom est requis' : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Logo de l\'école',
              icon: Icons.image_outlined,
              iconColor: const Color(0xFF8B5CF6),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _uploadingLogo ? null : _pickLogo,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.25),
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignInside,
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
                          Row(
                            children: [
                              const Text(
                                'Logo de l\'établissement',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_logoUrl != null && _logoUrl!.isNotEmpty)
                                      ? const Color(0xFF10B981).withOpacity(0.12)
                                      : const Color(0xFF64748B).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (_logoUrl != null && _logoUrl!.isNotEmpty)
                                      ? 'Personnalisé'
                                      : 'Par défaut',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: (_logoUrl != null && _logoUrl!.isNotEmpty)
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ce logo s\'affiche pour votre école dans l\'application mobile et l\'espace administration.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _uploadingLogo ? null : _pickLogo,
                                icon: const Icon(Icons.upload, size: 18),
                                label: const Text('Changer le logo'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF8B5CF6),
                                  side: const BorderSide(
                                    color: Color(0xFF8B5CF6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
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
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
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
    required Color iconColor,
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color? iconColor,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.slate400),
            prefixIcon:
                Icon(icon, color: iconColor ?? AppColors.slate500, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
