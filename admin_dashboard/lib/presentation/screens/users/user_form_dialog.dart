import '../../../data/services/user_management_service.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_model.dart';
import '../../providers/users_provider.dart';
import '../../providers/curriculum_provider.dart';
import '../../providers/classes_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../widgets/ios_loader.dart';

class UserFormDialog extends ConsumerStatefulWidget {
  final UserModel? user;
  const UserFormDialog({super.key, this.user});
  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _nationalityController;
  late TextEditingController _studentCodeController;
  String _selectedRole = 'student';
  String? _selectedNiveauCode;
  String? _selectedSectionCode;
  String? _selectedGender;
  String? _selectedClassId; // For class enrollment
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _showPassword = false;
  String? _generatedCredentials;

  bool get isEditing => widget.user != null;

  // Password strength calculation
  int get _passwordStrength {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) return 0;
    int score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) score++;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score++;
    if (RegExp(r'[!@#\$%&*]').hasMatch(pwd)) score++;
    return score.clamp(0, 4);
  }

  String get _passwordStrengthLabel {
    switch (_passwordStrength) {
      case 0: return 'Très faible';
      case 1: return 'Faible';
      case 2: return 'Moyen';
      case 3: return 'Fort';
      default: return 'Très fort';
    }
  }

  Color get _passwordStrengthColor {
    switch (_passwordStrength) {
      case 0: return AppColors.error;
      case 1: return AppColors.warning;
      case 2: return AppColors.warning;
      case 3: return AppColors.primary;
      default: return AppColors.success;
    }
  }

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.user?.fullName ?? '',
    );
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _addressController = TextEditingController(
      text: widget.user?.address ?? '',
    );
    _nationalityController = TextEditingController(
      text: widget.user?.nationality ?? '',
    );
    _studentCodeController = TextEditingController(
      text: widget.user?.studentCode ?? '',
    );
    _selectedRole = widget.user?.role ?? 'student';
    _selectedNiveauCode = widget.user?.niveauCode;
    _selectedSectionCode = widget.user?.sectionCode;
    _selectedGender = widget.user?.gender;
    _dateOfBirth = widget.user?.dateOfBirth;

    _passwordController.addListener(() {
      if (mounted) setState(() {});
    });

    if (!isEditing) {
      _generatePassword();
    } else {
      // Load current enrollment class
      _loadCurrentEnrollment();
      _loadCurrentPassword();
    }
  }

  Future<void> _loadCurrentEnrollment() async {
    if (widget.user == null) return;
    try {
      final supabase = Supabase.instance.client;
      final enrollment = await supabase
          .from('enrollments')
          .select('class_id')
          .eq('user_id', widget.user!.id)
          .maybeSingle();
      if (enrollment != null && mounted) {
        setState(() {
          _selectedClassId = enrollment['class_id'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading enrollment: $e');
    }
  }

  Future<void> _loadCurrentPassword() async {
    if (widget.user == null) return;
    try {
      final supabase = Supabase.instance.client;
      final userData = await supabase
          .from('users')
          .select('initial_password')
          .eq('id', widget.user!.id)
          .maybeSingle();
      if (userData != null && mounted) {
        final pwd = userData['initial_password'] as String?;
        if (pwd != null && pwd.isNotEmpty) {
          _passwordController.text = pwd;
        }
      }
    } catch (e) {
      debugPrint('Error loading password: $e');
    }
  }

  void _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#\$%&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    final password = List.generate(
      12,
      (i) => chars[(random + i * 17) % chars.length],
    ).join();
    _passwordController.text = password;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nationalityController.dispose();
    _studentCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curriculumState = ref.watch(curriculumProvider);
    final allNiveaux = curriculumState.whenOrNull(data: (s) => s.niveaux) ?? [];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 720,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SECTION: IDENTITÉ ──
                      _buildSectionHeader(Icons.badge_outlined, 'Identité'),
                      const SizedBox(height: 20),
                      _buildPremiumTextField(
                        controller: _fullNameController,
                        label: 'Nom complet',
                        placeholder: 'Ex: Jean Dupont',
                        validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPremiumDateField(
                              label: 'Date de naissance',
                              value: _dateOfBirth,
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _dateOfBirth ?? DateTime(2000),
                                  firstDate: DateTime(1950),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) setState(() => _dateOfBirth = date);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Genre'),
                                const SizedBox(height: 8),
                                _buildGenderToggle(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── SECTION: SCOLARITÉ ──
                      _buildSectionHeader(Icons.school_outlined, 'Scolarité'),
                      const SizedBox(height: 20),
                      _buildPremiumDropdown<String>(
                        label: 'Rôle',
                        value: _selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Étudiant')),
                          DropdownMenuItem(value: 'staff', child: Text('Manager')),
                        ],
                        onChanged: isEditing ? null : (v) {
                          if (v != null) setState(() => _selectedRole = v);
                        },
                      ),
                      if (_selectedRole == 'student') ...[
                        const SizedBox(height: 16),
                        _buildPremiumDropdown<String?>(
                          label: 'Niveau',
                          value: _selectedNiveauCode,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Sélectionner un niveau')),
                            ...allNiveaux.map((n) => DropdownMenuItem(value: n.code, child: Text(n.name))),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedNiveauCode = v;
                            if (!niveauRequiresSection(v)) _selectedSectionCode = null;
                          }),
                        ),
                        if (niveauRequiresSection(_selectedNiveauCode)) ...[
                          const SizedBox(height: 16),
                          _buildPremiumDropdown<String?>(
                            label: 'Section',
                            value: _selectedSectionCode,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Sélectionner une section')),
                              ...sectionsList.map((s) => DropdownMenuItem(
                                    value: s['code'] as String,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10, height: 10,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: _parseColor(s['color'] as String?),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Text(s['name'] as String),
                                      ],
                                    ),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedSectionCode = v),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, _) {
                            final classesAsync = ref.watch(classesProvider);
                            return classesAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text(
                                UserFriendlyError.format(
                                  e,
                                  fallback: 'Unable to load classes right now.',
                                ),
                              ),
                              data: (classesState) {
                                final classes = classesState.classes;
                                return _buildPremiumDropdown<String?>(
                                  label: 'Classe',
                                  value: _selectedClassId,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('Sélectionner une classe')),
                                    ...classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                  ],
                                  onChanged: (v) => setState(() => _selectedClassId = v),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPremiumTextField(
                          controller: _studentCodeController,
                          label: 'Immatriculation',
                          placeholder: 'STU-2026-0001 (auto si vide)',
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildPremiumTextField(
                        controller: _nationalityController,
                        label: 'Nationalité',
                        placeholder: 'Tunisienne',
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumTextField(
                        controller: _phoneController,
                        label: 'Téléphone',
                        placeholder: '+216 XX XXX XXX',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── SECTION: COMPTE & SÉCURITÉ ──
                      _buildSectionHeader(Icons.lock_outline, 'Compte & Sécurité'),
                      const SizedBox(height: 20),
                      _buildPremiumTextField(
                        controller: _emailController,
                        label: _selectedRole == 'student'
                            ? 'Email (optionnel — auto-généré si vide)'
                            : 'Email professionnel',
                        placeholder: _selectedRole == 'student'
                            ? 'Laisser vide pour email établissement automatique'
                            : 'j.dupont@lycee.fr',
                        enabled: !isEditing,
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        validator: (v) {
                          final trimmed = v?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return _selectedRole == 'student' ? null : 'Requis';
                          }
                          final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(trimmed)) return 'Format email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordSection(),
                      if (_generatedCredentials != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.successSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Text('Utilisateur créé!', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_generatedCredentials!, style: const TextStyle(fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildSummaryStrip(),
            _buildFooter(),
          ],
        ),
      ),
    ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PREMIUM UI COMPONENTS
  // ═══════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: AppColors.slate100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Modifier l\'utilisateur' : 'Ajouter un nouvel utilisateur',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditing ? 'Modifiez les informations du profil.' : 'Créez un profil complet pour le système académique.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.slate50),
              child: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFF6D4CF6), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF4B5563)),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700));
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
            filled: true,
            fillColor: AppColors.slate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderLight)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderLight)),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDateField({required String label, required DateTime? value, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null ? DateFormat('dd/MM/yyyy').format(value) : 'JJ/MM/AAAA',
                    style: TextStyle(fontSize: 14, color: value != null ? AppColors.textPrimary : AppColors.textTertiary),
                  ),
                ),
                const Icon(Icons.calendar_month, size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [_genderPill('M', 'Masculin'), _genderPill('F', 'Féminin')]),
    );
  }

  Widget _genderPill(String value, String label) {
    final isActive = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? AppColors.primary : AppColors.textTertiary)),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumDropdown<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              dropdownColor: Colors.white,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(isEditing ? 'Nouveau mot de passe (optionnel)' : 'Mot de passe provisoire'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                        validator: isEditing ? null : (v) => v == null || v.isEmpty ? 'Requis' : null,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                          hintText: isEditing ? 'Laisser vide pour ne pas changer' : 'Mot de passe...',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.textTertiary),
                      splashRadius: 18,
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _passwordController.text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe copié'), duration: Duration(seconds: 1)));
                      },
                      icon: const Icon(Icons.copy, size: 18, color: AppColors.textTertiary),
                      splashRadius: 18,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _generatePassword,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.refresh, size: 18, color: AppColors.slate600),
                    SizedBox(width: 6),
                    Text('GÉNÉRER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPasswordStrengthMeter(),
      ],
    );
  }

  Widget _buildPasswordStrengthMeter() {
    final strength = _passwordStrength;
    return Column(
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i < strength ? _passwordStrengthColor : AppColors.slate200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FORCE: ${_passwordStrengthLabel.toUpperCase()}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _passwordStrengthColor),
            ),
            const Text(
              'Recommandé: 12+ caractères',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryStrip() {
    final roleLabel = _selectedRole == 'student' ? 'Étudiant' : 'Manager';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: Row(
        children: [
          _summaryChip(AppColors.primary, 'TYPE: ${roleLabel.toUpperCase()}'),
          const SizedBox(width: 24),
          _summaryChip(AppColors.slate300, 'CODE: AUTO-GÉNÉRÉ'),
          const SizedBox(width: 24),
          _summaryChip(AppColors.success, 'STATUT: ACTIF'),
        ],
      ),
    );
  }

  Widget _summaryChip(Color dotColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Annuler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const IosLoader.small(color: Colors.white)
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(isEditing ? 'Enregistrer' : 'Créer l\'utilisateur', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.secondary;
      case 'staff':
        return AppColors.primary;
      case 'teacher':
        return AppColors.success;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final notifier = ref.read(usersProvider.notifier);

    bool success;
    final email = _emailController.text;
    final password = _passwordController.text;

    debugPrint('UserFormDialog: Starting submit, isEditing=$isEditing');
    debugPrint('UserFormDialog: fullName=${_fullNameController.text}');
    debugPrint('UserFormDialog: classId=$_selectedClassId');

    if (isEditing) {
      debugPrint('UserFormDialog: Calling updateUser for ${widget.user!.id}');
      success = await notifier.updateUser(
        widget.user!.id,
        fullName: _fullNameController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        role: _selectedRole,
        studentCode: _studentCodeController.text.isNotEmpty ? _studentCodeController.text : null,
        dateOfBirth: _dateOfBirth?.toIso8601String().split('T')[0],
        address: _addressController.text.isNotEmpty
            ? _addressController.text
            : null,
        niveauCode: _selectedNiveauCode,
        sectionCode: _selectedSectionCode,
        gender: _selectedGender,
        nationality: _nationalityController.text.isNotEmpty
            ? _nationalityController.text
            : null,
      );
      debugPrint('UserFormDialog: updateUser returned $success');

      // Update password securely via Edge Function if a new one was entered
      if (success && _passwordController.text.isNotEmpty) {
        try {
          await UserManagementService.resetPassword(
            widget.user!.id,
            newPassword: _passwordController.text,
          );
          debugPrint('UserFormDialog: password updated successfully');
        } catch (e) {
          debugPrint('UserFormDialog: password update error: $e');
        }
      }

      // Update enrollment if class is selected
      if (success && _selectedClassId != null && _selectedRole == 'student') {
        debugPrint('UserFormDialog: Calling updateEnrollment');
        final enrollResult = await notifier.updateEnrollment(
          widget.user!.id,
          _selectedClassId!,
        );
        debugPrint('UserFormDialog: updateEnrollment returned $enrollResult');
      }
    } else {
      success = await notifier.createUser(
        email: email,
        password: password,
        fullName: _fullNameController.text,
        role: _selectedRole,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        dateOfBirth: _dateOfBirth?.toIso8601String().split('T')[0],
        address: _addressController.text.isNotEmpty
            ? _addressController.text
            : null,
        niveauCode: _selectedNiveauCode,
        sectionCode: _selectedSectionCode,
        gender: _selectedGender,
        nationality: _nationalityController.text.isNotEmpty
            ? _nationalityController.text
            : null,
        classId: _selectedClassId,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);

      if (!isEditing) {
        final resolvedEmail =
            ref.read(usersProvider).value?.lastCreatedEmail ?? email;
        // Show credentials dialog for newly created user
        _showCredentialsDialog(
          context,
          _fullNameController.text,
          resolvedEmail,
          password,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilisateur modifié avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (mounted) {
      final errMsg = ref.read(usersProvider).value?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errMsg != null && errMsg.isNotEmpty
                ? errMsg
                : 'Unable to save user details right now. Please try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showCredentialsDialog(
    BuildContext context,
    String name,
    String email,
    String password,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Utilisateur créé !', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'IMPORTANT - Sauvegardez ces identifiants',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Communiquez ces informations à l\'utilisateur pour qu\'il puisse se connecter.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nom: $name',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildCredentialRow(ctx, 'Email', email),
            const SizedBox(height: 12),
            _buildCredentialRow(ctx, 'Mot de passe', password),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: 'Email: $email\nMot de passe: $password'),
                      );
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Identifiants copiés !'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAF0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_all, size: 16),
                    label: const Text('Copier tout', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAF0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copié !'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Copier',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.slate300;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return AppColors.slate300;
  }
}
