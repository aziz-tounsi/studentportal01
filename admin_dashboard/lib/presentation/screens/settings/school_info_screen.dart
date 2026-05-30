import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';

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

  Future<bool> saveSchool(Map<String, dynamic> data) async {
    try {
      final schoolId = await _getSchoolId();
      if (schoolId == null) return false;

      final supabase = Supabase.instance.client;
      final existing = await supabase
          .from('schools')
          .select('id')
          .eq('id', schoolId)
          .maybeSingle();

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

      state = AsyncValue.data(data);
      return true;
    } catch (e) {
      return false;
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
    _nameController.text = data['name'] ?? '';
    setState(() {
      _logoUrl = data['logo_url'] as String?;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return;

    setState(() => _uploadingLogo = true);

    try {
      final supabase = Supabase.instance.client;
      final bytes = await image.readAsBytes();
      final ext = _extensionFromFile(image);
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'logos/$fileName';
      final mimeType = image.mimeType ?? 'image/png';

      await supabase.storage
          .from('profiles')
          .uploadBinary(storagePath, bytes,
              fileOptions: FileOptions(contentType: mimeType));

      final publicUrl = supabase.storage
          .from('profiles')
          .getPublicUrl(storagePath);

      setState(() {
        _logoUrl = publicUrl;
        _hasChanges = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  String _extensionFromFile(XFile file) {
    final path = file.path;
    final mimeType = file.mimeType;
    if (path.contains('.')) {
      final dotExt = path.split('.').last;
      if (!dotExt.contains('/')) return dotExt;
    }
    if (mimeType != null && mimeType.contains('/')) {
      return mimeType.split('/').last;
    }
    return 'png';
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'logo_url': _logoUrl,
    };

    final success =
        await ref.read(schoolInfoProvider.notifier).saveSchool(data);

    setState(() {
      _isLoading = false;
      _hasChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: AppColors.textOnPrimary,
              ),
              const SizedBox(width: 12),
              Text(success
                  ? 'Informations sauvegardées avec succès!'
                  : 'Erreur lors de la sauvegarde'),
            ],
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
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
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erreur: $e')),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
                    ),
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
                      onTap: _pickLogo,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.2),
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: _uploadingLogo
                            ? const Center(
                                child: CircularProgressIndicator())
                            : _logoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      _logoUrl!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                      errorBuilder: (_, __, ___) =>
                                          _buildLogoPlaceholder(),
                                    ),
                                  )
                                : _buildLogoPlaceholder(),
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
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Le logo apparaît sur la carte d\'étudiant\ndans l\'application mobile.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _pickLogo,
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

  Widget _buildLogoPlaceholder() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              color: Color(0xFF8B5CF6), size: 32),
          SizedBox(height: 4),
          Text(
            'Ajouter',
            style: TextStyle(
              color: Color(0xFF8B5CF6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
