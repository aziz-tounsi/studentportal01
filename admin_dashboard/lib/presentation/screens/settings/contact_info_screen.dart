import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/modern_animated_switch.dart';
import '../../widgets/skeleton_loader.dart';

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
                    loading: () => const ContactInfoSkeletonLoader(),
                    error: (e, _) => Center(
                      child: Text(
                        UserFriendlyError.format(
                          e,
                          fallback: 'Unable to load contact information right now. Please try again.',
                        ),
                      ),
                    ),
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
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informations de Contact & Horaires',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
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
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveChanges,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(
                _isLoading ? 'Sauvegarde...' : 'Sauvegarder',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        ],
                        validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        label: 'Adresse email',
                        hint: 'contact@ecole.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Requis';
                          if (!v!.contains('@')) return 'Email invalide';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tableau des Horaires
            _buildSectionCard(
              title: 'Tableau des Horaires d\'Ouverture (App Mobile)',
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFFF59E0B),
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
                                ModernAnimatedSwitch(
                                  value: !day.isClosed,
                                  activeColor: const Color(0xFF6D4CF6),
                                  onChanged: (val) {
                                    setState(() {
                                      day.isClosed = !val;
                                      _hasChanges = true;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  day.isClosed ? 'Fermé' : 'Ouvert',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: day.isClosed ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            if (!day.isClosed) ...[
                              const Text('De : ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              const SizedBox(width: 8),
                              _buildTimeButton(
                                context: context,
                                controller: day.openController,
                                defaultHint: '08h00',
                              ),
                              const SizedBox(width: 14),
                              const Text('À : ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              const SizedBox(width: 8),
                              _buildTimeButton(
                                context: context,
                                controller: day.closeController,
                                defaultHint: '17h00',
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
          ],
        ),
      ),
    );
  }

  Future<void> _pickTimeForDay(BuildContext context, TextEditingController controller) async {
    int initialHour = 8;
    int initialMinute = 0;
    final text = controller.text.replaceAll('h', ':').trim();
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length >= 2) {
        initialHour = int.tryParse(parts[0]) ?? 8;
        initialMinute = int.tryParse(parts[1]) ?? 0;
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}h${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formatted;
        _hasChanges = true;
      });
    }
  }

  Widget _buildTimeButton({
    required BuildContext context,
    required TextEditingController controller,
    required String defaultHint,
  }) {
    final value = controller.text.isNotEmpty ? controller.text : defaultHint;
    return InkWell(
      onTap: () => _pickTimeForDay(context, controller),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF6D4CF6)),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Color? iconColor,
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
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
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
    Color? iconColor,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            prefixIcon: (icon != null && iconColor != null)
                ? Icon(icon, color: iconColor, size: 18)
                : null,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

}
