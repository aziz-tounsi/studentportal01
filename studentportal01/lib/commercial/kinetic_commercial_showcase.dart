import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../core/config/supabase_config.dart';
import '../core/l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../data/services/core_data_service.dart';
import '../data/services/offline_cache_service.dart';
import '../presentation/providers/announcements_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/school_provider.dart';
import '../presentation/providers/student_context_provider.dart' as ctx;
import '../presentation/providers/suggestions_provider.dart';
import '../presentation/screens/absences/absences_screen.dart';
import '../presentation/screens/ai_chat/ai_chat_screen.dart';
import '../presentation/screens/documents/documents_screen.dart';
import '../presentation/screens/emploi/emploi_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/mon_solde/mon_solde_screen.dart';
import '../presentation/screens/notifications/notifications_screen.dart';
import '../presentation/screens/resultats/resultats_screen.dart';
import '../presentation/widgets/emploi_skeleton.dart';
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
// MAIN STANDALONE ENTRY POINT WITH ALL REAL SCREEN PROVIDERS
// ═══════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('fr', null);
  } catch (_) {}

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
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
        ctx.studentContextProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoStudentContext,
        ),
        ctx.semestersProvider.overrideWith(
          (ref) async => [
            SemesterInfo(
                id: 'sem-1', name: 'Semestre 1', number: 1, isCurrent: true),
            SemesterInfo(
                id: 'sem-2', name: 'Semestre 2', number: 2, isCurrent: false),
          ],
        ),
        timetableProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoTimetableSlots,
        ),
        absencesProvider.overrideWith(
          (ref, arg) async => CommercialMobileDemoData.demoAbsences,
        ),
        gradesProvider.overrideWith(
          (ref, arg) async => CommercialMobileDemoData.demoGrades,
        ),
        ctx.paymentsDataProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoPaymentPlans,
        ),
        globalAnnouncementsProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoAnnouncements,
        ),
        allStudentDocumentsProvider.overrideWith(
          (ref) async => CommercialMobileDemoData.demoDocuments,
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
      title: 'Pythagore • 3D Master Motion Graphic Commercial',
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
// 3D KINETIC COMMERCIAL MOTION STAGE (90.0s MASTER TIMELINE)
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
  static const double _totalDurationSec = 92.0;

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

  void _jumpTo(double seconds) {
    _timelineCtrl.value = (seconds / _totalDurationSec).clamp(0.0, 1.0);
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
      backgroundColor: const Color(0xFF03050A),
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

            // Camera transformation variables
            double rotX = 0, rotY = 0, rotZ = 0;
            double transX = 0, transY = 0;
            double camScale = 1.0;

            String badgeText = "PYTHAGORE TECHNOLOGIES";
            String titleText = "STUDENT\nOS 2.0";
            String subText =
                "L'expérience scolaire la plus fluide et avancée au monde.";
            double textOpacity = 1.0;
            double textOffset = 360;

            // Screen index:
            // 0: Home, 1: Emploi, 2: Absences, 3: Resultats, 4: Mon Solde, 5: Notifs, 6: Nova AI
            int activeScreen = 0;
            bool showSkeleton = false;

            // Interaction simulation
            Offset? tapTargetPosition;
            double tapPulseScale = 0.0;
            double cardBounceScale = 1.0;
            bool cardLiftedInZ = false;

            // Feature 3D effects
            double notifBurstProgress = 0.0;
            double novaAuraOpacity = 0.0;
            String sceneName = "SCENE 1: TITANIUM EDGE MACRO";

            // ═════════════════════════════════════════════════════════
            // SCENE 1: TITANIUM EDGE MACRO SHOT (0.0s – 7.5s)
            // Extreme macro camera looking down brushed metal frame
            // ═════════════════════════════════════════════════════════
            if (t < 7.5) {
              final p = _ease(t / 7.5);
              sceneName = "SCENE 1: TITANIUM EDGE MACRO SHOT";
              badgeText = "INGÉNIERIE MATÉRIELLE & LOGICIELLE";
              titleText = "STUDENT\nOS 2.0";
              subText = "Conçu pour repousser les limites de la vie scolaire.";
              textOpacity = t > 0.6 ? 1.0 : 0.0;
              textOffset = 380;

              rotX = _lerp(48, 26, p);
              rotY = _lerp(-70, -38, p);
              rotZ = _lerp(28, 14, p);
              transX = _lerp(-180, -130, p);
              transY = _lerp(80, 20, p);
              camScale = _lerp(1.42, 1.18, p);

              activeScreen = 0;
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 2: PROFIL 360° & STUDENT ID CARD (7.5s – 18.0s)
            // Camera sweeps to face the phone; Student ID card lifts & tilts
            // ═════════════════════════════════════════════════════════
            else if (t < 18.0) {
              final p = _ease((t - 7.5) / 10.5);
              sceneName = "SCENE 2: IDENTITÉ SCOLAIRE • PROFIL 360°";
              badgeText = "IDENTITÉ SCOLAIRE CONNECTÉE";
              titleText = "CARTE ÉTUDIANT\nNFC EN DIRECT";
              subText =
                  "Yasmine Ben Salem • 4ème Bac Maths 1 • Validation instantanée.";
              textOpacity = 1.0;
              textOffset = -480;

              rotX = _lerp(26, 14, p);
              rotY = _lerp(-38, 16, p);
              rotZ = _lerp(14, -3, p);
              transX = _lerp(-130, 180, p);
              transY = _lerp(20, 0, p);
              camScale = _lerp(1.18, 1.03, p);

              activeScreen = 0;

              // Simulated tap on student card at t = 11.0s
              if (t >= 10.8 && t < 15.5) {
                final tapT = (t - 10.8) / 4.7;
                tapTargetPosition = const Offset(195, 180);
                tapPulseScale = math.sin(tapT * math.pi * 3).clamp(0.0, 1.0);
                cardLiftedInZ = true;
              }
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 3: TAP TIMETABLE -> REAL EMPLOI SCREEN (18.0s – 30.0s)
            // Exact timetable card bounces, navigates, and shows real grid
            // ═════════════════════════════════════════════════════════
            else if (t < 30.0) {
              sceneName = "SCENE 3: PLANNING & EMPLOI DU TEMPS";
              badgeText = "EMPLOI DU TEMPS EN TEMPS RÉEL";
              titleText = "PLANNING\nINTELLIGENT";
              subText =
                  "Maths, Physique, Info, SVT • Salles et professeurs assignés.";
              textOpacity = 1.0;
              textOffset = -480;

              // Tap phase (18.0s – 20.2s)
              if (t < 20.2) {
                activeScreen = 0;
                final tapP = ((t - 18.0) / 2.2).clamp(0.0, 1.0);
                tapTargetPosition = const Offset(105, 480);
                tapPulseScale = math.sin(tapP * math.pi).clamp(0.0, 1.0);
                cardBounceScale = 1.0 - (0.12 * math.sin(tapP * math.pi));

                rotX = 14;
                rotY = 16;
                rotZ = -3;
                transX = 180;
                camScale = 1.03;
              }
              // Skeleton shimmer phase (20.2s – 21.6s)
              else if (t < 21.6) {
                activeScreen = 1;
                showSkeleton = true;
                rotX = 12;
                rotY = -8;
                rotZ = 2;
                transX = 180;
                camScale = 1.06;
              }
              // Full real Emploi grid with 3D camera pan (21.6s – 30.0s)
              else {
                activeScreen = 1;
                showSkeleton = false;
                final gridP = _ease((t - 21.6) / 8.4);
                rotX = _lerp(12, 18, gridP);
                rotY = _lerp(-8, -26, gridP);
                rotZ = _lerp(2, 6, gridP);
                transX = _lerp(180, 140, gridP);
                transY = _lerp(0, -30, gridP);
                camScale = _lerp(1.06, 1.08, gridP);
              }
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 4: TAP ABSENCES -> REAL ABSENCES SCREEN (30.0s – 42.0s)
            // Tap rose absences card -> Attendance gauges & telemetry
            // ═════════════════════════════════════════════════════════
            else if (t < 42.0) {
              sceneName = "SCENE 4: ASSIDUITÉ & GESTION DES ABSENCES";
              badgeText = "SUIVI D'ASSIDUITÉ TOTAL";
              titleText = "GAUGES &\nPRÉSENCES";
              subText =
                  "4.0h manquées • Seuils de tolérance, justificatifs et barèmes.";
              textOpacity = 1.0;
              textOffset = 380;

              // Tap phase (30.0s – 32.2s)
              if (t < 32.2) {
                activeScreen = 0;
                final tapP = ((t - 30.0) / 2.2).clamp(0.0, 1.0);
                tapTargetPosition = const Offset(285, 480);
                tapPulseScale = math.sin(tapP * math.pi).clamp(0.0, 1.0);
                cardBounceScale = 1.0 - (0.12 * math.sin(tapP * math.pi));

                rotX = 14;
                rotY = -12;
                rotZ = 2;
                transX = -180;
                camScale = 1.04;
              }
              // Skeleton loading (32.2s – 33.5s)
              else if (t < 33.5) {
                activeScreen = 2;
                showSkeleton = true;
                rotX = 10;
                rotY = 8;
                rotZ = -2;
                transX = -170;
                camScale = 1.06;
              }
              // Full real Absences screen (33.5s – 42.0s)
              else {
                activeScreen = 2;
                showSkeleton = false;
                final p = _ease((t - 33.5) / 8.5);
                rotX = _lerp(10, 22, p);
                rotY = _lerp(8, 28, p);
                rotZ = _lerp(-2, -6, p);
                transX = _lerp(-170, -140, p);
                transY = _lerp(0, -25, p);
                camScale = _lerp(1.06, 1.08, p);
              }
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 5: TAP RÉSULTATS -> REAL GRADES SCREEN (42.0s – 54.0s)
            // Tap blue card -> General Average 19.62, coefficients, DC/DS
            // ═════════════════════════════════════════════════════════
            else if (t < 54.0) {
              sceneName = "SCENE 5: EXCELLENCE ACADÉMIQUE • RÉSULTATS";
              badgeText = "EXCELLENCE ACADÉMIQUE";
              titleText = "BULLETINS &\nCOEFFICIENTS";
              subText =
                  "Moyenne générale 18.42/20 • Félicitations • Coefficients officiels.";
              textOpacity = 1.0;
              textOffset = -480;

              // Tap phase (42.0s – 44.2s)
              if (t < 44.2) {
                activeScreen = 0;
                final tapP = ((t - 42.0) / 2.2).clamp(0.0, 1.0);
                tapTargetPosition = const Offset(285, 650);
                tapPulseScale = math.sin(tapP * math.pi).clamp(0.0, 1.0);
                cardBounceScale = 1.0 - (0.12 * math.sin(tapP * math.pi));

                rotX = 12;
                rotY = 14;
                rotZ = -3;
                transX = 180;
                camScale = 1.04;
              }
              // Skeleton loading (44.2s – 45.4s)
              else if (t < 45.4) {
                activeScreen = 3;
                showSkeleton = true;
                rotX = 10;
                rotY = -6;
                rotZ = 2;
                transX = 170;
                camScale = 1.06;
              }
              // Full real Resultats screen (45.4s – 54.0s)
              else {
                activeScreen = 3;
                showSkeleton = false;
                final p = _ease((t - 45.4) / 8.6);
                rotX = _lerp(10, 16, p);
                rotY = _lerp(-6, -24, p);
                rotZ = _lerp(2, 5, p);
                transX = _lerp(170, 150, p);
                transY = _lerp(0, -40, p);
                camScale = _lerp(1.06, 1.09, p);
              }
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 6: TAP MON SOLDE -> REAL FINANCIAL SCREEN (54.0s – 65.5s)
            // Tap purple card -> Tuition payments, installments & receipts
            // ═════════════════════════════════════════════════════════
            else if (t < 65.5) {
              sceneName = "SCENE 6: TRANSPARENCE FINANCIÈRE • MON SOLDE";
              badgeText = "TRANSPARENCE FINANCIÈRE";
              titleText = "ÉCHÉANCIERS &\nPAIEMENTS";
              subText =
                  "Scolarité, transport, cantine • Règlements par carte & reçus.";
              textOpacity = 1.0;
              textOffset = 380;

              // Tap phase (54.0s – 56.2s)
              if (t < 56.2) {
                activeScreen = 0;
                final tapP = ((t - 54.0) / 2.2).clamp(0.0, 1.0);
                tapTargetPosition = const Offset(105, 650);
                tapPulseScale = math.sin(tapP * math.pi).clamp(0.0, 1.0);
                cardBounceScale = 1.0 - (0.12 * math.sin(tapP * math.pi));

                rotX = 12;
                rotY = -14;
                rotZ = 2;
                transX = -180;
                camScale = 1.04;
              }
              // Skeleton loading (56.2s – 57.5s)
              else if (t < 57.5) {
                activeScreen = 4;
                showSkeleton = true;
                rotX = 8;
                rotY = 8;
                rotZ = -2;
                transX = -170;
                camScale = 1.06;
              }
              // Full real Mon Solde screen (57.5s – 65.5s)
              else {
                activeScreen = 4;
                showSkeleton = false;
                final p = _ease((t - 57.5) / 8.0);
                rotX = _lerp(8, 20, p);
                rotY = _lerp(8, 26, p);
                rotZ = _lerp(-2, -5, p);
                transX = _lerp(-170, -145, p);
                transY = _lerp(0, -35, p);
                camScale = _lerp(1.06, 1.08, p);
              }
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 7: NOTIFICATIONS & 3D EXPLODED PARALLAX (65.5s – 78.5s)
            // Real Notifs screen -> EXACT cards BURST OUT OF THE PHONE!
            // ═════════════════════════════════════════════════════════
            else if (t < 78.5) {
              final p = _ease((t - 65.5) / 13.0);
              sceneName = "SCENE 7: NOTIFICATIONS PARALLAXE 3D ÉCLATÉES";
              badgeText = "ALERTES HORS DE L'ÉCRAN";
              titleText = "NOTIFICATIONS\nEXPLOSÉES EN 3D";
              subText =
                  "Les alertes d'examen et les notes sautent littéralement du châssis.";
              textOpacity = 1.0;
              textOffset = -480;

              rotX = _lerp(12, 28, p);
              rotY = _lerp(-10, -36, p);
              rotZ = _lerp(2, 9, p);
              transX = _lerp(180, 130, p);
              transY = _lerp(0, -10, p);
              camScale = 1.02;

              activeScreen = 5; // Real NotificationsScreen!

              // Cards burst out from the mobile screen into physical Z space!
              if (t >= 68.0) {
                notifBurstProgress = ((t - 68.0) / 4.5).clamp(0.0, 1.0);
              }
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 8: RENCONTREZ NOVA • TUTEUR IA PRIVÉ (78.5s – 87.0s)
            // Real AIChatScreen with multi-neon aura & live response
            // ═════════════════════════════════════════════════════════
            else if (t < 87.0) {
              final p = _ease((t - 78.5) / 8.5);
              sceneName = "SCENE 8: RENCONTREZ NOVA • TUTEUR IA PRIVÉ";
              badgeText = "ASSISTANT IA PRIVÉ 24H/24";
              titleText = "RENCONTREZ\nNOVA.";
              subText =
                  "L'intelligence artificielle pédagogique privée qui coache chaque élève.";
              textOpacity = 1.0;
              textOffset = 380;

              rotX = _lerp(28, 12, p);
              rotY = _lerp(-36, 22, p);
              rotZ = _lerp(9, -4, p);
              transX = _lerp(130, -180, p);
              transY = _lerp(-10, 0, p);
              camScale = 1.05;

              activeScreen = 6; // Real AIChatScreen!
              novaAuraOpacity = ((t - 78.5) / 2.0).clamp(0.0, 1.0);
            }

            // ═════════════════════════════════════════════════════════
            // SCENE 9: GRAND HERO OUTRO & LEVITATION (87.0s – 92.0s)
            // Floating 3D phone, studio reflections, final brand signature
            // ═════════════════════════════════════════════════════════
            else {
              final p = _ease((t - 87.0) / 5.0);
              sceneName = "SCENE 9: GRAND HERO OUTRO & SIGNATURE";
              badgeText = "PYTHAGORE ÉDUCATION";
              titleText = "LE FUTUR DE\nL'ÉDUCATION.";
              subText = "Disponible dès maintenant sur iOS, Android et Web.";
              textOpacity = 1.0;
              textOffset = 0;

              rotX = _lerp(12, 0, p);
              rotY = _lerp(22, 0, p);
              rotZ = _lerp(-4, 0, p);
              transX = _lerp(-180, 0, p);
              transY = math.sin(t * 2.4) * 10;
              camScale = _lerp(1.05, 0.94, p);

              activeScreen = 0; // Return home gracefully
            }

            // 3D Perspective Matrix Calculation
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..setTranslationRaw(transX, transY, 0.0)
              ..rotateX(rotX * math.pi / 180)
              ..rotateY(rotY * math.pi / 180)
              ..rotateZ(rotZ * math.pi / 180)
              ..scaleByDouble(camScale, camScale, camScale, 1.0);

            return Stack(
              children: [
                // 1. Ambient Background Lighting & Studio Glow
                Positioned(
                  top: -140,
                  left: screenSize.width * 0.1,
                  child: Container(
                    width: 550,
                    height: 550,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF4F46E5).withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: screenSize.width * 0.08,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF2D78).withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Nova AI Neural Aura (Behind phone)
                if (novaAuraOpacity > 0)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 440,
                        height: 860,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(56),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D78)
                                  .withValues(alpha: 0.55 * novaAuraOpacity),
                              blurRadius: 140,
                              spreadRadius: 25,
                            ),
                            BoxShadow(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.50 * novaAuraOpacity),
                              blurRadius: 180,
                              spreadRadius: 40,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 2. Kinetic Floating Typography (Apple style)
                Positioned.fill(
                  child: Align(
                    alignment: textOffset < 0
                        ? Alignment.centerLeft
                        : (textOffset > 0
                            ? Alignment.centerRight
                            : Alignment.bottomCenter),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width > 900 ? 90 : 36,
                        vertical: textOffset == 0 ? 90 : 0,
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: textOpacity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: textOffset < 0
                              ? CrossAxisAlignment.start
                              : (textOffset > 0
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.center),
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  letterSpacing: 2.2,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              titleText,
                              textAlign: textOffset < 0
                                  ? TextAlign.left
                                  : (textOffset > 0
                                      ? TextAlign.right
                                      : TextAlign.center),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenSize.width > 900 ? 56 : 38,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 380,
                              child: Text(
                                subText,
                                textAlign: textOffset < 0
                                    ? TextAlign.left
                                    : (textOffset > 0
                                        ? TextAlign.right
                                        : TextAlign.center),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 16,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Central 3D Smartphone Stage
                Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: matrix,
                    child: SizedBox(
                      width: 390,
                      height: 844,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ── OUTER METALLIC TITANIUM EDGE ──
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(54),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE2E8F0),
                                  Color(0xFF64748B),
                                  Color(0xFF1E293B),
                                  Color(0xFF0F172A),
                                  Color(0xFF334155),
                                  Color(0xFFCBD5E1),
                                ],
                                stops: [0.0, 0.2, 0.5, 0.7, 0.88, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.85),
                                  blurRadius: 90,
                                  offset: const Offset(0, 45),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 110,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.5),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                            ),
                          ),

                          // ── SCREEN GLASS CONTAINER & ACTUAL SCREENS ──
                          Positioned(
                            top: 10,
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(44),
                              child: Stack(
                                children: [
                                  // ── MOUNTING YOUR ACTUAL FLUTTER APP CODE ──
                                  Positioned.fill(
                                    child: Transform.scale(
                                      scale: cardBounceScale,
                                      alignment: tapTargetPosition != null
                                          ? Alignment(
                                              (tapTargetPosition.dx / 370.0) * 2 - 1,
                                              (tapTargetPosition.dy / 824.0) * 2 - 1,
                                            )
                                          : Alignment.center,
                                      child: IndexedStack(
                                        index: activeScreen.clamp(0, 6),
                                        children: const [
                                          HomeScreen(),
                                          EmploiScreen(),
                                          AbsencesScreen(),
                                          ResultatsScreen(),
                                          MonSoldeScreen(),
                                          NotificationsScreen(),
                                          AIChatScreen(),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Brief authentic skeleton loader shimmer on entry
                                  if (showSkeleton && activeScreen == 1)
                                    const Positioned.fill(
                                        child: EmploiSkeleton()),

                                  // Simulated Student Card Z-Lift for Scene 2
                                  if (cardLiftedInZ)
                                    Positioned(
                                      top: 110,
                                      left: 20,
                                      right: 20,
                                      height: 220,
                                      child: Transform(
                                        transform: Matrix4.identity()
                                          ..setTranslationRaw(0.0, 0.0, 60.0)
                                          ..scaleByDouble(1.04, 1.04, 1.04, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(28),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFF2D78)
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 40,
                                                offset: const Offset(0, 20),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Simulated Interactive Touch Pointer / Tap Ripple
                                  if (tapTargetPosition != null &&
                                      tapPulseScale > 0)
                                    Positioned(
                                      left: tapTargetPosition.dx - 30,
                                      top: tapTargetPosition.dy - 30,
                                      child: Opacity(
                                        opacity: tapPulseScale,
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Dynamic Island (iPhone 16 Pro)
                                  Positioned(
                                    top: 12,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 122,
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
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const Text(
                                              'PYTHA',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.2),
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

                          // ═════════════════════════════════════════════════════
                          // ── 3D NOTIFICATION CARDS BURSTING OUTSIDE THE BEZEL ──
                          // ═════════════════════════════════════════════════════
                          if (notifBurstProgress > 0) ...[
                            // Card 1: Exam announcement (Burst outside Left)
                            Positioned(
                              top: 170,
                              left: -130 * notifBurstProgress,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setTranslationRaw(
                                      0.0, 0.0, 160.0 * notifBurstProgress)
                                  ..rotateZ(-0.06),
                                child: Opacity(
                                  opacity: notifBurstProgress,
                                  child: Container(
                                    width: 330,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.75),
                                          blurRadius: 40,
                                          offset: const Offset(0, 24),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Color(0xFFEF4444),
                                          child: Icon(Icons.assignment_rounded,
                                              color: Colors.white, size: 20),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Devoir de Synthèse • Maths',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Salle B12 • 08:00 • M. Mansour',
                                                style: TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 12,
                                                ),
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

                            // Card 2: Grade 19.5/20 announcement (Burst outside Right)
                            Positioned(
                              top: 340,
                              right: -130 * notifBurstProgress,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setTranslationRaw(
                                      0.0, 0.0, 230.0 * notifBurstProgress)
                                  ..rotateZ(0.06),
                                child: Opacity(
                                  opacity: notifBurstProgress,
                                  child: Container(
                                    width: 330,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.75),
                                          blurRadius: 40,
                                          offset: const Offset(0, 24),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.4),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Color(0xFF10B981),
                                          child: Icon(Icons.star_rounded,
                                              color: Colors.white, size: 22),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Nouvelle Note : 19.5 / 20 !',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Devoir de Contrôle N°2 • Mathématiques',
                                                style: TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 12,
                                                ),
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

                            // Card 3: Nova AI Tutor Flashcard (Burst Center Elevated)
                            Positioned(
                              top: 510,
                              left: -30 * notifBurstProgress,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setTranslationRaw(
                                      0.0, 0.0, 310.0 * notifBurstProgress)
                                  ..rotateZ(-0.02),
                                child: Opacity(
                                  opacity: notifBurstProgress,
                                  child: Container(
                                    width: 350,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFFFF2D78)
                                            .withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.8),
                                          blurRadius: 45,
                                          offset: const Offset(0, 25),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFFFF2D78)
                                              .withValues(alpha: 0.45),
                                          blurRadius: 35,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Color(0xFFFF2D78),
                                          child: Icon(Icons.auto_awesome,
                                              color: Colors.white, size: 20),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Assistant Nova • Fiche de Révision',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Équations différentielles & Quiz généré',
                                                style: TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 12,
                                                ),
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

                // 4. Director HUD Controller (Bottom Master Control)
                if (!_hideHud)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.75),
                              blurRadius: 32,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Row 1: Playback Controls & Scrubber
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  onPressed: _togglePlayPause,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.replay_rounded,
                                      color: Colors.white70, size: 22),
                                  onPressed: _reset,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: screenSize.width > 900 ? 320 : 180,
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
                                  '${(t).toStringAsFixed(1)}s / ${_totalDurationSec.toInt()}s',
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
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.visibility_off_outlined,
                                      color: Colors.white54, size: 18),
                                  tooltip: 'Masquer l\'HUD (H)',
                                  onPressed: () =>
                                      setState(() => _hideHud = true),
                                ),
                              ],
                            ),

                            // Row 2: Instant Feature Jump Bar
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _jumpChip('01 Intro', 0.0),
                                  _jumpChip('02 Carte NFC', 8.0),
                                  _jumpChip('03 Emploi', 18.0),
                                  _jumpChip('04 Absences', 30.0),
                                  _jumpChip('05 Résultats', 42.0),
                                  _jumpChip('06 Solde', 54.0),
                                  _jumpChip('07 Notifs 3D', 65.5),
                                  _jumpChip('08 Nova IA', 78.5),
                                  _jumpChip('09 Outro', 87.0),
                                ],
                              ),
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
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Text(
                          'Appuyez sur H pour réafficher les contrôles',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
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

  Widget _jumpChip(String label, double seconds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _jumpTo(seconds),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
