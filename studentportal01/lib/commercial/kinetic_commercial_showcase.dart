import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../core/config/supabase_config.dart';
import '../core/l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../data/services/offline_cache_service.dart';
import '../presentation/providers/announcements_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/school_provider.dart';
import '../presentation/providers/student_context_provider.dart';
import '../presentation/providers/suggestions_provider.dart';
import '../presentation/screens/ai_chat/ai_chat_screen.dart';
import '../presentation/screens/documents/documents_screen.dart';
import '../presentation/screens/emploi/emploi_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/notifications/notifications_screen.dart';
import 'commercial_mobile_demo_data.dart';

// ═══════════════════════════════════════════════════════════════════
// MOCK AUTH NOTIFIER THAT INJECTS REAL USER & STUDENT DATA
// ═══════════════════════════════════════════════════════════════════

class CommercialMockAuthNotifier extends AuthNotifier {
  CommercialMockAuthNotifier() {
    state = CommercialMobileDemoData.buildAuthState();
  }

  @override
  AuthState get state => CommercialMobileDemoData.buildAuthState();
}

// ═══════════════════════════════════════════════════════════════════
// MAIN STANDALONE ENTRY POINT
// ═══════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('fr', null);
  } catch (_) {}

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (_) {}

  try {
    await OfflineCacheService.instance.init();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => CommercialMockAuthNotifier()),
        schoolProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoSchool,
        ),
        studentContextProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoStudentContext,
        ),
        timetableProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoTimetableSlots,
        ),
        globalAnnouncementsProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoAnnouncements,
        ),
        unreadDocumentsCountProvider.overrideWithValue(2),
        repliedOrSeenSuggestionsCountProvider.overrideWithValue(1),
      ],
      child: const CommercialKineticApp(),
    ),
  );
}

class CommercialKineticApp extends StatelessWidget {
  const CommercialKineticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pythagore 3D Kinetic Commercial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: const Kinetic3DStageScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3D KINETIC COMMERCIAL MOTION STAGE
// ═══════════════════════════════════════════════════════════════════

class Kinetic3DStageScreen extends ConsumerStatefulWidget {
  const Kinetic3DStageScreen({super.key});

  @override
  ConsumerState<Kinetic3DStageScreen> createState() =>
      _Kinetic3DStageScreenState();
}

class _Kinetic3DStageScreenState extends ConsumerState<Kinetic3DStageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timelineCtrl;
  bool _isPlaying = true;
  bool _hideHud = false;
  static const double _totalDurationSec = 30.0;

  @override
  void initState() {
    super.initState();
    _timelineCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_totalDurationSec * 1000).toInt()),
    )..repeat();
  }

  @override
  void dispose() {
    _timelineCtrl.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _timelineCtrl.repeat();
      } else {
        _timelineCtrl.stop();
      }
    });
  }

  void _reset() {
    _timelineCtrl.reset();
    if (_isPlaying) _timelineCtrl.repeat();
    setState(() {});
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _ease(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              _togglePlayPause();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyH) {
              setState(() => _hideHud = !_hideHud);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
              _reset();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedBuilder(
          animation: _timelineCtrl,
          builder: (context, _) {
            final t = _timelineCtrl.value * _totalDurationSec;

            // Camera parameter variables
            double rotX = 0, rotY = 0, rotZ = 0;
            double transX = 0, transY = 0;
            double camScale = 1.0;

            String badgeText = "PYTHAGORE REVOLUTION";
            String titleText = "STUDENT\nOS 2.0";
            String subText = "L'application scolaire repensée de fond en comble.";
            double textOpacity = 1.0;
            double textOffset = 360;

            int activeScreen = 0; // 0: Home, 1: Timetable, 2: Notifs, 3: Nova
            bool timetablePopped = false;
            double notifBurstProgress = 0.0;
            double novaAuraOpacity = 0.0;
            String sceneName = "SCENE 1: EDGE MACRO SHOT";

            // ─────────────────────────────────────────────────────
            // 1. SCENE 1: TITANIUM EDGE MACRO SHOT (0.0s - 4.5s)
            // Camera looking along the phone's metallic side edge
            // ─────────────────────────────────────────────────────
            if (t < 4.5) {
              final p = _ease(t / 4.5);
              sceneName = "SCENE 1: TITANIUM EDGE MACRO SHOT";
              badgeText = "INNOVATION ACADÉMIQUE";
              titleText = "STUDENT\nOS 2.0";
              subText = "L'expérience scolaire la plus fluide et avancée au monde.";
              textOpacity = t > 0.5 ? 1.0 : 0.0;
              textOffset = 360;

              rotX = _lerp(45, 25, p);
              rotY = _lerp(-65, -35, p);
              rotZ = _lerp(25, 12, p);
              transX = _lerp(-140, -120, p);
              transY = _lerp(60, 20, p);
              camScale = _lerp(1.35, 1.15, p);

              activeScreen = 0;
            }

            // ─────────────────────────────────────────────────────
            // 2. SCENE 2: CAMERA DOLLY SWOOP INTO HOME SCREEN (4.5s - 9.5s)
            // Camera swoops around into the glass screen
            // ─────────────────────────────────────────────────────
            else if (t < 9.5) {
              final p = _ease((t - 4.5) / 5.0);
              sceneName = "SCENE 2: CAMERA DOLLY • PROFIL 360°";
              badgeText = "IDENTITÉ SCOLAIRE CONNECTÉE";
              titleText = "PROFIL 360°\nEN DIRECT";
              subText = "Badge certifié, carte d'étudiant NFC, notes et présences.";
              textOpacity = 1.0;
              textOffset = -460;

              rotX = _lerp(25, 12, p);
              rotY = _lerp(-35, 15, p);
              rotZ = _lerp(12, -4, p);
              transX = _lerp(-120, 180, p);
              transY = _lerp(20, 0, p);
              camScale = _lerp(1.15, 1.02, p);

              activeScreen = 0;
            }

            // ─────────────────────────────────────────────────────
            // 3. SCENE 3: 3D TIMETABLE CARD POP & BOUNCE (9.5s - 15.0s)
            // Emploi card physically lifts in Z-axis & transitions
            // ─────────────────────────────────────────────────────
            else if (t < 15.0) {
              sceneName = "SCENE 3: 3D TIMETABLE POP & BOUNCE";
              badgeText = "EMPLOI DU TEMPS EN TEMPS RÉEL";
              titleText = "PLANNING\nINTELLIGENT";
              subText = "Salles, professeurs et alertes de changement à la seconde.";
              textOpacity = 1.0;
              textOffset = -460;

              rotX = 10;
              rotY = -8;
              rotZ = 2;
              transX = 180;
              camScale = 1.05;

              if (t < 11.2) {
                activeScreen = 0;
                timetablePopped = true;
              } else {
                activeScreen = 1; // Real EmploiScreen!
                timetablePopped = false;
              }
            }

            // ─────────────────────────────────────────────────────
            // 4. SCENE 4: EXPLODED NOTIFICATIONS (15.0s - 21.0s)
            // Cards burst OUTSIDE the mobile screen borders in 3D!
            // ─────────────────────────────────────────────────────
            else if (t < 21.0) {
              final p = _ease((t - 15.0) / 6.0);
              sceneName = "SCENE 4: EXPLODED 3D NOTIFICATIONS";
              badgeText = "NOTIFICATIONS PARALLAX";
              titleText = "ALERTES HORS\nDE L'ÉCRAN";
              subText = "Ne manquez jamais une note, un devoir ou un cours déplacé.";
              textOpacity = 1.0;
              textOffset = -480;

              rotX = _lerp(10, 26, p);
              rotY = _lerp(-8, -32, p);
              rotZ = _lerp(2, 8, p);
              transX = _lerp(180, 140, p);
              camScale = 1.0;

              activeScreen = 2; // Real NotificationsScreen!
              notifBurstProgress = ((t - 15.4) / 4.0).clamp(0.0, 1.0);
            }

            // ─────────────────────────────────────────────────────
            // 5. SCENE 5: MEET NOVA • PRIVATE AI TUTOR (21.0s - 26.5s)
            // Real AIChatScreen with glowing neural aura
            // ─────────────────────────────────────────────────────
            else if (t < 26.5) {
              final p = _ease((t - 21.0) / 5.5);
              sceneName = "SCENE 5: NOVA PEDAGOGICAL AI TUTOR";
              badgeText = "ASSISTANT IA PRIVÉ";
              titleText = "RENCONTREZ\nNOVA.";
              subText = "Le tuteur IA personnel sécurisé qui accompagne chaque élève 24h/24.";
              textOpacity = 1.0;
              textOffset = 380;

              rotX = _lerp(26, 12, p);
              rotY = _lerp(-32, 22, p);
              rotZ = _lerp(8, -5, p);
              transX = _lerp(140, -180, p);
              camScale = 1.05;

              activeScreen = 3; // Real AIChatScreen!
              novaAuraOpacity = ((t - 21.2) / 2.0).clamp(0.0, 1.0);
            }

            // ─────────────────────────────────────────────────────
            // 6. SCENE 6: GRAND HERO OUTRO (26.5s - 30.0s)
            // Centered floating levitation pose
            // ─────────────────────────────────────────────────────
            else {
              final p = _ease((t - 26.5) / 3.5);
              sceneName = "SCENE 6: GRAND HERO OUTRO";
              badgeText = "PYTHAGORE ÉDUCATION";
              titleText = "LE FUTUR DE\nL'ÉDUCATION.";
              subText = "Disponible sur iOS, Android et Web.";
              textOpacity = _lerp(1.0, 0.0, p);
              textOffset = 0;

              rotX = _lerp(12, 0, p);
              rotY = _lerp(22, 0, p);
              rotZ = _lerp(-5, 0, p);
              transX = _lerp(-180, 0, p);
              transY = math.sin(t * 2.5) * 8;
              camScale = _lerp(1.05, 0.94, p);

              activeScreen = 0;
            }

            // 3D Perspective Matrix using raw transformation values
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..setTranslationRaw(transX, transY, 0.0)
              ..rotateX(rotX * math.pi / 180)
              ..rotateY(rotY * math.pi / 180)
              ..rotateZ(rotZ * math.pi / 180)
              ..scaleByDouble(camScale, camScale, camScale, 1.0);

            return Stack(
              children: [
                // 1. Ambient Background Lighting & Studio Orbs
                Positioned(
                  top: -120,
                  left: screenSize.width * 0.1,
                  child: Container(
                    width: 700,
                    height: 700,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF6D4CF6).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150,
                  right: screenSize.width * 0.15,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Kinetic 3D Typography Layer
                Positioned.fill(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(textOffset, 0),
                      child: Opacity(
                        opacity: textOpacity.clamp(0.0, 1.0),
                        child: SizedBox(
                          width: 480,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF60A5FA)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(
                                    color: Color(0xFF93C5FD),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                titleText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 54,
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                  letterSpacing: -1.8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                subText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 17,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. The 3D Smartphone Holding the REAL Flutter App
                Positioned.fill(
                  child: Center(
                    child: Transform(
                      transform: matrix,
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Neural Glow Aura for NOVA
                          if (novaAuraOpacity > 0)
                            Positioned(
                              top: -40,
                              bottom: -40,
                              left: -40,
                              right: -40,
                              child: Opacity(
                                opacity: novaAuraOpacity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(80),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 70,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Phone Chassis Frame
                          Container(
                            width: 390,
                            height: 800,
                            decoration: BoxDecoration(
                              color: const Color(0xFF11141C),
                              borderRadius: BorderRadius.circular(54),
                              border: Border.all(
                                color: const Color(0xFF2C3242),
                                width: 10,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  blurRadius: 80,
                                  offset: const Offset(0, 35),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF6D4CF6)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 100,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(44),
                              child: Stack(
                                children: [
                                  // ── MOUNTING YOUR ACTUAL FLUTTER APP CODE ──
                                  if (activeScreen == 0)
                                    const Positioned.fill(child: HomeScreen()),
                                  if (activeScreen == 1)
                                    const Positioned.fill(
                                        child: EmploiScreen()),
                                  if (activeScreen == 2)
                                    const Positioned.fill(
                                        child: NotificationsScreen()),
                                  if (activeScreen == 3)
                                    const Positioned.fill(
                                        child: AIChatScreen()),

                                  // Simulated 3D Bouncing Tile for Scene 3
                                  if (timetablePopped)
                                    Positioned(
                                      top: 360,
                                      left: 20,
                                      right: 20,
                                      child: Transform(
                                        transform: Matrix4.identity()
                                          ..setTranslationRaw(0.0, 0.0, 90.0)
                                          ..scaleByDouble(1.08, 1.08, 1.08, 1.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF14B8A6),
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF14B8A6)
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 40,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.calendar_month_rounded,
                                                  color: Colors.white, size: 28),
                                              SizedBox(width: 14),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Emploi du Temps',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    '3 cours aujourd\'hui',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Dynamic Island
                                  Positioned(
                                    top: 12,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 120,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1F2937),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color:
                                                        const Color(0xFF374151),
                                                    width: 2),
                                              ),
                                            ),
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Glass Sheen Reflection
                                  IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withValues(alpha: 0.16),
                                            Colors.white.withValues(alpha: 0.03),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.35, 0.6],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── 3D NOTIFICATION CARDS BURSTING OUTSIDE THE BEZEL ──
                          if (notifBurstProgress > 0) ...[
                            // Card 1: Burst Outside Left
                            Positioned(
                              top: 180,
                              left: -110 * notifBurstProgress,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setTranslationRaw(0.0, 0.0,
                                      140.0 * notifBurstProgress)
                                  ..rotateZ(-0.06),
                                child: Opacity(
                                  opacity: notifBurstProgress,
                                  child: Container(
                                    width: 320,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          blurRadius: 40,
                                          offset: const Offset(0, 20),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.4),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Color(0xFF10B981),
                                          child: Icon(Icons.grade_rounded,
                                              color: Colors.white, size: 20),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Note Publiée : Mathématiques',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                'Yasmine a obtenu 18.5/20',
                                                style: TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Card 2: Burst Outside Right
                            Positioned(
                              top: 340,
                              right: -120 * notifBurstProgress,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setTranslationRaw(0.0, 0.0,
                                      210.0 * notifBurstProgress)
                                  ..rotateZ(0.06),
                                child: Opacity(
                                  opacity: notifBurstProgress,
                                  child: Container(
                                    width: 320,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          blurRadius: 40,
                                          offset: const Offset(0, 20),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6)
                                              .withValues(alpha: 0.4),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Color(0xFF3B82F6),
                                          child: Icon(Icons.room_rounded,
                                              color: Colors.white, size: 20),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Changement de Salle : B12',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                'Physique-Chimie à 10:15',
                                                style: TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Director HUD Controller (Bottom Bar)
                if (!_hideHud)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D111C).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              icon: const Icon(Icons.replay_rounded,
                                  color: Colors.white70),
                              onPressed: _reset,
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 240,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF60A5FA),
                                  inactiveTrackColor:
                                      Colors.white.withValues(alpha: 0.15),
                                  thumbColor: const Color(0xFF60A5FA),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _timelineCtrl.value,
                                  onChanged: (v) {
                                    _timelineCtrl.value = v;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(t).toStringAsFixed(1)}s / 30.0s',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                sceneName,
                                style: const TextStyle(
                                  color: Color(0xFFA5B4FC),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            IconButton(
                              icon: const Icon(Icons.visibility_off_outlined,
                                  color: Colors.white54, size: 18),
                              tooltip: 'Masquer l\'HUD (H)',
                              onPressed: () => setState(() => _hideHud = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_hideHud)
                  Positioned(
                    top: 16,
                    right: 20,
                    child: InkWell(
                      onTap: () => setState(() => _hideHud = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Appuyer sur H pour afficher l\'HUD',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
