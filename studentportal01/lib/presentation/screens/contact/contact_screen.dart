import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../providers/nav_bar_provider.dart';
import '../../widgets/contact_skeleton.dart';

// Provider to fetch contact info from Supabase
final contactInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('app_settings')
        .select()
        .eq('key', 'contact_info')
        .maybeSingle();
    
    if (response != null && response['value'] != null) {
      return Map<String, dynamic>.from(response['value'] as Map);
    }
  } catch (e) {
    debugPrint('Error fetching contact info: $e');
  }
  
  // Default values
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
});

class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final cleanEmail = email.trim();
    final uri = Uri(scheme: 'mailto', path: cleanEmail);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      try {
        await launchUrl(uri);
      } catch (err) {
        debugPrint('Fallback error launching email: $err');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contactInfoAsync = ref.watch(contactInfoProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8D5F2),
              Color(0xFFD4C4E8),
              Color(0xFFC9D6F0),
              Color(0xFFE0EAF5),
              Color(0xFFF0F5FA),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: contactInfoAsync.when(
            data: (contactInfo) => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Custom App Bar with Circular Return Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Builder(
                      builder: (ctx) {
                        final isRtl = Directionality.of(ctx) == TextDirection.rtl;
                        return Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                final fromAIChat = ref.read(navigatedFromAIChatProvider);
                                if (fromAIChat) {
                                  ref.read(navigatedFromAIChatProvider.notifier).state = false;
                                  context.go('/ai-chat');
                                } else if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/');
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Icon(
                                      isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                                      size: 18,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                l10n.contact,
                                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                                style: ArabicTypography.headerStyle(
                                  ctx,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                
                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Header Card - Solid Light White & Borderless
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.support_agent_rounded,
                                color: Color(0xFF3B82F6),
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              l10n.needHelp,
                              style: ArabicTypography.headerStyle(
                                context,
                                color: const Color(0xFF1F2937),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.contactDesc,
                              textAlign: TextAlign.center,
                              style: ArabicTypography.bodyStyle(
                                context,
                                color: Colors.grey[600],
                                fontSize: 14.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // 2. Single Unified Contact Card (Appelez-nous, Email, Site Web, Visitez-nous all in one)
                      _UnifiedContactCard(
                        phone: contactInfo['phone'] ?? '',
                        email: contactInfo['email'] ?? '',
                        website: contactInfo['website'] ?? '',
                        address: contactInfo['address'] ?? '',
                        onCall: () => _launchPhone(contactInfo['phone'] ?? ''),
                        onEmail: () => _launchEmail(contactInfo['email'] ?? ''),
                        onWebsite: () => _launchUrl(contactInfo['website'] ?? 'https://aziz-tounsi.github.io/'),
                        onAddress: () => _launchUrl(contactInfo['maps'] ?? ''),
                      ),
                      const SizedBox(height: 20),

                      // 3. Dedicated Opening Hours Table (Horaires Card - Clean, no description, no row arrow)
                      _OpeningHoursCard(contactInfo: contactInfo),
                      const SizedBox(height: 20),

                      // 4. Clickable iOS-Style Location Map Preview Card (Under Horaires -> Opens Real Google Maps Location)
                      _IosStyleMapPreviewCard(
                        address: contactInfo['address'] ?? 'Rue El Emir Faicel, Kairouan',
                        onTap: () => _launchUrl(contactInfo['maps'] ?? 'https://www.google.com/maps/dir/35.831194,10.594667/35.6744015,10.1017/@35.7573801,10.0281956,10z'),
                      ),
                      const SizedBox(height: 28),
                      
                      // 5. Social Media Section with Instagram & TikTok PNG Icons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          l10n.joinUsSocial,
                          style: ArabicTypography.subtitleStyle(
                            context,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialButton(
                            iconWidget: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 32),
                            label: 'Facebook',
                            onTap: () => _launchUrl(contactInfo['facebook'] ?? 'https://facebook.com'),
                          ),
                          const SizedBox(width: 20),
                          _SocialButton(
                            iconWidget: Image.asset(
                              'assets/icons/insta.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.camera_alt_rounded, color: Color(0xFFE1306C), size: 32),
                            ),
                            label: 'Instagram',
                            onTap: () => _launchUrl(contactInfo['instagram'] ?? 'https://instagram.com'),
                          ),
                          const SizedBox(width: 20),
                          _SocialButton(
                            iconWidget: Image.asset(
                              'assets/icons/tiktok.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.music_note_rounded, color: Colors.black, size: 32),
                            ),
                            label: 'TikTok',
                            onTap: () => _launchUrl(contactInfo['tiktok'] ?? 'https://tiktok.com'),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            loading: () => const ContactSkeleton(),
            error: (context, error) => const Center(child: Text('Erreur de chargement')),
          ),
        ),
      ),
    );
  }
}

// Unified Contact Card: Appelez-nous, Email, Site Web, and Visitez-nous combined in one white card
class _UnifiedContactCard extends StatelessWidget {
  final String phone;
  final String email;
  final String website;
  final String address;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onWebsite;
  final VoidCallback onAddress;

  const _UnifiedContactCard({
    required this.phone,
    required this.email,
    required this.website,
    required this.address,
    required this.onCall,
    required this.onEmail,
    required this.onWebsite,
    required this.onAddress,
  });

  String _getShortUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header left: Section Title WITHOUT icon
          Text(
            l10n.nosCoordonnees,
            style: ArabicTypography.subtitleStyle(
              context,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          // Row 1: Téléphone
          _ContactRow(
            icon: Icons.phone_rounded,
            iconColor: const Color(0xFF10B981),
            label: l10n.callUs,
            value: '\u200E$phone',
            onTap: onCall,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 22),
          // Row 2: Email
          _ContactRow(
            icon: Icons.email_rounded,
            iconColor: const Color(0xFF3B82F6),
            label: l10n.email,
            value: email,
            onTap: onEmail,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 22),
          // Row 3: Site Web
          _ContactRow(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF8B5CF6),
            label: l10n.website,
            value: _getShortUrl(website),
            onTap: onWebsite,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 22),
          // Row 4: Adresse
          _ContactRow(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFEF4444),
            label: l10n.visitUs,
            value: address,
            onTap: onAddress,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = ArabicTypography.isArabic(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: ArabicTypography.bodyStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: ArabicTypography.bodyStyle(
                      context,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  isAr ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dedicated Opening Hours Table (Horaires Card) - Clean, no description, no row arrow
class _OpeningHoursCard extends StatelessWidget {
  final Map<String, dynamic> contactInfo;

  const _OpeningHoursCard({required this.contactInfo});

  String _getDayLabel(String key, AppLocalizations l10n) {
    switch (key.toLowerCase()) {
      case 'lun': return l10n.dayLun;
      case 'mar': return l10n.dayMar;
      case 'mer': return l10n.dayMer;
      case 'jeu': return l10n.dayJeu;
      case 'ven': return l10n.dayVen;
      case 'sam': return l10n.daySam;
      case 'dim': return l10n.dayDim;
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rawBadge = contactInfo['schedule_badge'] as String?;
    final badge = (rawBadge == null || rawBadge == 'Ouvert à tous')
        ? l10n.openToAll
        : rawBadge;
    final daysConfig = _getDaysConfig();
    final todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Title + Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.scheduleTitle,
                style: ArabicTypography.subtitleStyle(
                  context,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badge,
                      style: ArabicTypography.bodyStyle(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 4),
          // Days List (No right chevron arrows)
          ...daysConfig.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == daysConfig.length - 1;
            final isToday = item.weekdayNumber == todayWeekday;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFFF8FAFC) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xFFF8FAFC), width: 1),
                      ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      _getDayLabel(item.key, l10n),
                      style: ArabicTypography.bodyStyle(
                        context,
                        fontSize: 15,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? const Color(0xFF0F172A) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      item.isClosed ? l10n.closed : '\u200E${item.open} — ${item.close}',
                      style: ArabicTypography.bodyStyle(
                        context,
                        fontSize: 14.5,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: item.isClosed
                            ? const Color(0xFF94A3B8)
                            : (isToday ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_ScheduleDayDisplay> _getDaysConfig() {
    final rawDays = contactInfo['schedule_days'];
    final defaultDays = [
      _ScheduleDayDisplay(key: 'lun', label: 'Lun', open: '08h00', close: '17h00', isClosed: false, weekdayNumber: 1),
      _ScheduleDayDisplay(key: 'mar', label: 'Mar', open: '08h00', close: '17h00', isClosed: false, weekdayNumber: 2),
      _ScheduleDayDisplay(key: 'mer', label: 'Mer', open: '08h00', close: '17h00', isClosed: false, weekdayNumber: 3),
      _ScheduleDayDisplay(key: 'jeu', label: 'Jeu', open: '08h00', close: '17h00', isClosed: false, weekdayNumber: 4),
      _ScheduleDayDisplay(key: 'ven', label: 'Ven', open: '08h00', close: '17h00', isClosed: false, weekdayNumber: 5),
      _ScheduleDayDisplay(key: 'sam', label: 'Sam', open: '08h00', close: '17h00', isClosed: false, weekdayNumber: 6),
      _ScheduleDayDisplay(key: 'dim', label: 'Dim', open: '08h00', close: '17h00', isClosed: true, weekdayNumber: 7),
    ];

    if (rawDays is Map) {
      final map = Map<String, dynamic>.from(rawDays);
      return defaultDays.map((d) {
        if (map.containsKey(d.key)) {
          final dayData = Map<String, dynamic>.from(map[d.key] as Map);
          final open = dayData['open'] as String? ?? d.open;
          final close = dayData['close'] as String? ?? d.close;
          final isClosed = dayData['isClosed'] as bool? ?? d.isClosed;
          return _ScheduleDayDisplay(
            key: d.key,
            label: d.label,
            open: open,
            close: close,
            isClosed: isClosed,
            weekdayNumber: d.weekdayNumber,
          );
        }
        return d;
      }).toList();
    }

    return defaultDays;
  }
}

class _ScheduleDayDisplay {
  final String key;
  final String label;
  final String open;
  final String close;
  final bool isClosed;
  final int weekdayNumber;

  const _ScheduleDayDisplay({
    required this.key,
    required this.label,
    required this.open,
    required this.close,
    required this.isClosed,
    required this.weekdayNumber,
  });

  String get timeString => isClosed ? 'Fermé' : '$open — $close';
}

// Clickable iOS-Style Location Map Preview Card (Under Horaires -> Opens Real Location)
class _IosStyleMapPreviewCard extends StatelessWidget {
  final String address;
  final VoidCallback onTap;

  const _IosStyleMapPreviewCard({
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stylized iOS Map Viewport
            SizedBox(
              height: 155,
              width: double.infinity,
              child: Stack(
                children: [
                  // Vector Styled Map Canvas
                  CustomPaint(
                    size: const Size(double.infinity, 155),
                    painter: _IosMapCanvasPainter(),
                  ),
                  // Map Pin with Pulse Indicator
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_rounded, color: Color(0xFFEF4444), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                l10n.etablissement,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  // Google Maps Tag Top Right
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_rounded, size: 12, color: Color(0xFF3B82F6)),
                          SizedBox(width: 4),
                          Text(
                            'Google Maps',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Info Bar
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.locationAccess,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l10n.directions,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stylized iOS Map Canvas Painter
class _IosMapCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF4F6F8);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Park / Green Area
    final greenPaint = Paint()..color = const Color(0xFFE5F4E3);
    final parkPath = Path()
      ..moveTo(0, size.height * 0.4)
      ..cubicTo(size.width * 0.2, size.height * 0.3, size.width * 0.3, size.height * 0.7, size.width * 0.45, size.height * 0.6)
      ..lineTo(size.width * 0.45, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(parkPath, greenPaint);

    // Water River (Soft Blue)
    final waterPaint = Paint()
      ..color = const Color(0xFFD6EAF8)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final waterPath = Path()
      ..moveTo(size.width * 0.6, 0)
      ..cubicTo(size.width * 0.75, size.height * 0.4, size.width * 0.65, size.height * 0.65, size.width, size.height * 0.9);
    canvas.drawPath(waterPath, waterPaint);

    // Roads Secondary (Soft White)
    final secRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.35), secRoadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.2, size.height), secRoadPaint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.75, size.height), secRoadPaint);

    // Main Avenue (Yellow/Orange iOS Highway)
    final mainRoadBorder = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mainRoadPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(size.width * 0.4, size.height * 0.65, size.width * 0.5, size.height * 0.45, size.width, size.height * 0.3);
    canvas.drawPath(mainRoadPath, mainRoadBorder);

    final mainRoadInner = Paint()
      ..color = const Color(0xFFFEF3C7)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(mainRoadPath, mainRoadInner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SocialButton extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.iconWidget,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: iconWidget,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
