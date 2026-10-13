import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';

class _DayScheduleState {
  final String key;
  final String label;
  final String fullName;
  final TextEditingController openController;
  final TextEditingController closeController;
  bool isClosed;

  _DayScheduleState({
    required this.key,
    required this.label,
    required this.fullName,
    required String open,
    required String close,
    this.isClosed = false,
  })  : openController = TextEditingController(text: open),
        closeController = TextEditingController(text: close);

  void dispose() {
    openController.dispose();
    closeController.dispose();
  }
}

// Provider for contact info state using AsyncNotifier pattern (Riverpod 3.x)
class ContactInfoNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return await loadContactInfo();
  }

  Future<Map<String, dynamic>> loadContactInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('app_settings')
          .select()
          .eq('key', 'contact_info')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        return Map<String, dynamic>.from(response['value'] as Map);
      } else {
        return _defaultData();
      }
    } catch (e) {
      return _defaultData();
    }
  }

  Map<String, dynamic> _defaultData() {
    return {
      'phone': '53 518 054',
      'email': 'lyceepythagore19@gmail.com',
      'address': 'Rue El Emir Faicel, Kairouan',
      'facebook': 'https://www.facebook.com/profile.php?id=100064041700592',
      'instagram': 'https://www.instagram.com/',
      'tiktok': 'https://www.tiktok.com/',
      'maps': 'https://www.google.com/maps/dir/35.831194,10.594667/35.6744015,10.1017/@35.7573801,10.0281956,10z',
      'website': 'https://aziz-tounsi.github.io/',
      'hours': 'Lun - Sam: 08:00 - 17:00',
      'schedule_badge': 'Ouvert à tous',
      'schedule_description': '',
      'schedule_days': {
        'lun': {'label': 'Lun', 'fullName': 'Lundi', 'open': '08h00', 'close': '17h00', 'isClosed': false},
        'mar': {'label': 'Mar', 'fullName': 'Mardi', 'open': '08h00', 'close': '17h00', 'isClosed': false},
        'mer': {'label': 'Mer', 'fullName': 'Mercredi', 'open': '08h00', 'close': '17h00', 'isClosed': false},
        'jeu': {'label': 'Jeu', 'fullName': 'Jeudi', 'open': '08h00', 'close': '17h00', 'isClosed': false},
        'ven': {'label': 'Ven', 'fullName': 'Vendredi', 'open': '08h00', 'close': '17h00', 'isClosed': false},
        'sam': {'label': 'Sam', 'fullName': 'Samedi', 'open': '08h00', 'close': '17h00', 'isClosed': false},
        'dim': {'label': 'Dim', 'fullName': 'Dimanche', 'open': '08h00', 'close': '17h00', 'isClosed': true},
      },
    };
  }

  Future<bool> saveContactInfo(Map<String, dynamic> info) async {
    try {
      final supabase = Supabase.instance.client;
      
      final existing = await supabase
          .from('app_settings')
          .select()
          .eq('key', 'contact_info')
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('app_settings')
            .update({'value': info, 'updated_at': DateTime.now().toIso8601String()})
            .eq('key', 'contact_info');
      } else {
        await supabase
            .from('app_settings')
            .insert({
              'key': 'contact_info',
              'value': info,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
      }
      
      state = AsyncValue.data(info);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final contactInfoProvider = AsyncNotifierProvider<ContactInfoNotifier, Map<String, dynamic>>(
  ContactInfoNotifier.new,
);

class ContactInfoScreen extends ConsumerStatefulWidget {
  const ContactInfoScreen({super.key});

  @override
  ConsumerState<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends ConsumerState<ContactInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _tiktokController;
  late TextEditingController _mapsController;
  late TextEditingController _websiteController;
  late TextEditingController _hoursController;
  late TextEditingController _scheduleBadgeController;
  late TextEditingController _scheduleDescController;
  
  late List<_DayScheduleState> _days;
  
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _facebookController = TextEditingController();
    _instagramController = TextEditingController();
    _tiktokController = TextEditingController();
    _mapsController = TextEditingController();
    _websiteController = TextEditingController();
    _hoursController = TextEditingController();
    _scheduleBadgeController = TextEditingController(text: 'Ouvert à tous');
    _scheduleDescController = TextEditingController(text: '');

    _days = [
      _DayScheduleState(key: 'lun', label: 'Lun', fullName: 'Lundi', open: '08h00', close: '17h00', isClosed: false),
      _DayScheduleState(key: 'mar', label: 'Mar', fullName: 'Mardi', open: '08h00', close: '17h00', isClosed: false),
      _DayScheduleState(key: 'mer', label: 'Mer', fullName: 'Mercredi', open: '08h00', close: '17h00', isClosed: false),
      _DayScheduleState(key: 'jeu', label: 'Jeu', fullName: 'Jeudi', open: '08h00', close: '17h00', isClosed: false),
      _DayScheduleState(key: 'ven', label: 'Ven', fullName: 'Vendredi', open: '08h00', close: '17h00', isClosed: false),
      _DayScheduleState(key: 'sam', label: 'Sam', fullName: 'Samedi', open: '08h00', close: '17h00', isClosed: false),
      _DayScheduleState(key: 'dim', label: 'Dim', fullName: 'Dimanche', open: '08h00', close: '17h00', isClosed: true),
    ];
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _mapsController.dispose();
    _websiteController.dispose();
    _hoursController.dispose();
    _scheduleBadgeController.dispose();
    _scheduleDescController.dispose();
    for (final day in _days) {
      day.dispose();
    }
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_isDataLoaded) return;
    _isDataLoaded = true;

    _phoneController.text = data['phone'] ?? '';
    _emailController.text = data['email'] ?? '';
    _addressController.text = data['address'] ?? '';
    _facebookController.text = data['facebook'] ?? '';
    _instagramController.text = data['instagram'] ?? '';
    _tiktokController.text = data['tiktok'] ?? '';
    _mapsController.text = data['maps'] ?? '';
    _websiteController.text = data['website'] ?? '';
    _hoursController.text = data['hours'] ?? 'Lun - Sam: 08:00 - 17:00';
    _scheduleBadgeController.text = data['schedule_badge'] ?? 'Ouvert à tous';
    _scheduleDescController.text = data['schedule_description'] ?? '';

    if (data['schedule_days'] is Map) {
      final scheduleMap = Map<String, dynamic>.from(data['schedule_days'] as Map);
      for (final day in _days) {
        if (scheduleMap.containsKey(day.key)) {
          final dayData = Map<String, dynamic>.from(scheduleMap[day.key] as Map);
          day.openController.text = dayData['open'] ?? '08h00';
          day.closeController.text = dayData['close'] ?? '17h00';
          day.isClosed = dayData['isClosed'] ?? (day.key == 'dim');
        }
      }
    }
  }

  void _applyStandardHoursToAll() {
    setState(() {
      for (final day in _days) {
        if (day.key != 'dim') {
          day.openController.text = '08h00';
          day.closeController.text = '17h00';
          day.isClosed = false;
        } else {
          day.isClosed = true;
        }
      }
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final scheduleDaysMap = <String, dynamic>{};
    for (final day in _days) {
      scheduleDaysMap[day.key] = {
        'label': day.label,
        'fullName': day.fullName,
        'open': day.openController.text.trim(),
        'close': day.closeController.text.trim(),
        'isClosed': day.isClosed,
      };
    }

    final info = {
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'facebook': _facebookController.text.trim(),
      'instagram': _instagramController.text.trim(),
      'tiktok': _tiktokController.text.trim(),
      'maps': _mapsController.text.trim(),
      'website': _websiteController.text.trim(),
      'hours': _hoursController.text.trim(),
      'schedule_badge': _scheduleBadgeController.text.trim(),
      'schedule_description': _scheduleDescController.text.trim(),
      'schedule_days': scheduleDaysMap,
    };

    final success = await ref.read(contactInfoProvider.notifier).saveContactInfo(info);

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
    final contactInfoAsync = ref.watch(contactInfoProvider);

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
                  child: contactInfoAsync.when(
                    loading: () => const Center(child: IosLoader()),
                    error: (e, _) => Center(child: Text('Erreur: $e')),
                    data: (data) {
                      if (!_isDataLoaded) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _populateFields(data);
                          setState(() {});
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
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
          ),
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
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.contact_phone,
              color: Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informations de Contact & Horaires',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Gérer les coordonnées, réseaux sociaux et les horaires d\'ouverture dans l\'application',
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
                    style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w500),
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
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // Contact principal
            _buildSectionCard(
              title: 'Contact Principal',
              icon: Icons.phone,
              iconColor: const Color(0xFF10B981),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _phoneController,
                        label: 'Numéro de téléphone',
                        hint: '53 518 054',
                        icon: Icons.phone_outlined,
                        validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        label: 'Adresse email',
                        hint: 'contact@ecole.com',
                        icon: Icons.email_outlined,
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Requis';
                          if (!v!.contains('@')) return 'Email invalide';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _addressController,
                  label: 'Adresse physique (affichée sur la carte)',
                  hint: 'Rue El Emir Faicel, Kairouan',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tableau des Horaires
            _buildSectionCard(
              title: 'Tableau des Horaires d\'Ouverture (App Mobile)',
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFFF59E0B),
              trailing: OutlinedButton.icon(
                onPressed: _applyStandardHoursToAll,
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Rétablir 08h00 — 17h00 (Lun-Sam)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              children: [
                _buildTextField(
                  controller: _scheduleBadgeController,
                  label: 'Badge de statut (ex: Ouvert à tous)',
                  hint: 'Ouvert à tous',
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Créneaux par jour :',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    children: _days.asMap().entries.map((entry) {
                      final index = entry.key;
                      final day = entry.value;
                      final isLast = index == _days.length - 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast ? null : Border(bottom: BorderSide(color: AppColors.slate200.withValues(alpha: 0.6))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: day.isClosed ? const Color(0xFFF1F5F9) : const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                day.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: day.isClosed ? const Color(0xFF94A3B8) : const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 100,
                              child: Text(
                                day.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: day.isClosed ? const Color(0xFF94A3B8) : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Toggle Open / Closed
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: !day.isClosed,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setState(() {
                                      day.isClosed = !val;
                                      _hasChanges = true;
                                    });
                                  },
                                ),
                                Text(
                                  day.isClosed ? 'Fermé' : 'Ouvert',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: day.isClosed ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            if (!day.isClosed) ...[
                              const Text('De : ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: day.openController,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    hintText: '08h00',
                                  ),
                                  onChanged: (_) => setState(() => _hasChanges = true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('À : ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: day.closeController,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    hintText: '17h00',
                                  ),
                                  onChanged: (_) => setState(() => _hasChanges = true),
                                ),
                              ),
                            ] else ...[
                              const Expanded(
                                child: Text(
                                  'Aucun créneau d\'ouverture ce jour.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic, fontSize: 13),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Réseaux sociaux avec TikTok & Instagram
            _buildSectionCard(
              title: 'Réseaux Sociaux & Liens Web',
              icon: Icons.public,
              iconColor: const Color(0xFF3B82F6),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _facebookController,
                        label: 'Lien Facebook',
                        hint: 'https://www.facebook.com/...',
                        icon: Icons.facebook,
                        iconColor: const Color(0xFF1877F2),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        controller: _instagramController,
                        label: 'Lien Instagram',
                        hint: 'https://www.instagram.com/...',
                        icon: Icons.camera_alt_rounded,
                        iconColor: const Color(0xFFE1306C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _tiktokController,
                        label: 'Lien TikTok',
                        hint: 'https://www.tiktok.com/@...',
                        icon: Icons.music_note_rounded,
                        iconColor: const Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        controller: _websiteController,
                        label: 'Site Web / Portfolio',
                        hint: 'https://...',
                        icon: Icons.language,
                        iconColor: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _mapsController,
                  label: 'Lien Google Maps (Itinéraire)',
                  hint: 'https://www.google.com/maps/...',
                  icon: Icons.map_outlined,
                  iconColor: const Color(0xFFEF4444),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Preview
            _buildPreviewCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    Widget? trailing,
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
                  color: iconColor.withValues(alpha: 0.1),
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
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
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
            prefixIcon: Icon(icon, color: iconColor ?? AppColors.slate500, size: 20),
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
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: 0.05),
            const Color(0xFF8B5CF6).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.visibility, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Aperçu Mobile des Coordonnées & Horaires',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_iphone, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Rendu dans l\'application',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              // Contact Card Preview
              Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nos Coordonnées',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPreviewRow(Icons.phone, const Color(0xFF10B981), 'Appelez-nous', _phoneController.text.isEmpty ? '---' : _phoneController.text),
                    const Divider(height: 18, color: Color(0xFFF1F5F9)),
                    _buildPreviewRow(Icons.email, const Color(0xFF3B82F6), 'Email', _emailController.text.isEmpty ? '---' : _emailController.text),
                    const Divider(height: 18, color: Color(0xFFF1F5F9)),
                    _buildPreviewRow(Icons.location_on, const Color(0xFFEF4444), 'Visitez-nous', _addressController.text.isEmpty ? '---' : _addressController.text),
                  ],
                ),
              ),

              // Horaires Preview
              Container(
                width: 340,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Horaires',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _scheduleBadgeController.text.isEmpty ? 'Ouvert à tous' : _scheduleBadgeController.text,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 6),
                    ..._days.take(4).map((day) {
                      final isOpen = !day.isClosed;
                      final timeString = isOpen
                          ? '${day.openController.text} — ${day.closeController.text}'
                          : 'Fermé';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 38,
                              child: Text(
                                day.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                timeString,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isOpen ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, Color color, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
