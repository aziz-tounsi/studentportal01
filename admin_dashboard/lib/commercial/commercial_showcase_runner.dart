import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/config/supabase_config.dart';
import '../core/theme/app_theme.dart';
import '../data/services/school_branding_service.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/dashboard_provider.dart';
import '../presentation/screens/absences/absences_screen.dart';
import '../presentation/screens/classes/classes_screen.dart';
import '../presentation/screens/dashboard/dashboard_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/payments/payments_screen.dart';
import '../presentation/screens/results_screen.dart';
import '../presentation/screens/settings/password_reset_requests_screen.dart';
import '../presentation/screens/timetables/timetables_screen.dart';
import '../presentation/screens/users/users_screen.dart';
import 'commercial_demo_data.dart';
import 'commercial_director_widget.dart';

// ═══════════════════════════════════════════════════════════════════
// MOCK PROVIDERS FOR SEEDED 4K COMMERCIAL DEMO RECORDING
// ═══════════════════════════════════════════════════════════════════

class ShowcaseAuthNotifier extends AuthNotifier {
  @override
  AdminAuthState build() {
    return AdminAuthState(
      isLoading: false,
      isAuthenticated: true,
      user: CommercialAdminDemoData.demoDirectorUser,
      schoolSubscriptionStatus: 'active',
      schoolIsActive: true,
    );
  }
}

class ShowcaseDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async {
    return CommercialAdminDemoData.buildDashboardState();
  }
}

// ═══════════════════════════════════════════════════════════════════
// ROUTER CONFIGURED WITH PERSISTENT COMMERCIAL DIRECTOR OVERLAY
// ═══════════════════════════════════════════════════════════════════

late final GoRouter _showcaseRouter;

void _initRouter() {
  _showcaseRouter = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AdminCommercialDirectorWidget(
            router: _showcaseRouter,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/login',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: LoginScreen()),
          ),
          GoRoute(
            path: '/',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: UsersScreen()),
          ),
          GoRoute(
            path: '/classes',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ClassesScreen()),
          ),
          GoRoute(
            path: '/timetables',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: TimetablesScreen()),
          ),
          GoRoute(
            path: '/results',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ResultsScreen()),
          ),
          GoRoute(
            path: '/absences',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AbsencesScreen()),
          ),
          GoRoute(
            path: '/payments',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: PaymentsScreen()),
          ),
        ],
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════
// SHOWCASE MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr_FR', null);

  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('[SHOWCASE] Supabase initialization notice: $e');
  }

  _initRouter();

  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(ShowcaseAuthNotifier.new),
        dashboardProvider.overrideWith(ShowcaseDashboardNotifier.new),
        currentSchoolBrandingProvider.overrideWith(
          (ref) async => CommercialAdminDemoData.demoSchoolBranding,
        ),
        pendingPasswordResetCountProvider.overrideWith((ref) async => 0),
      ],
      child: const AdminCommercialShowcaseApp(),
    ),
  );
}

class AdminCommercialShowcaseApp extends StatelessWidget {
  const AdminCommercialShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pythagore School Admin Commercial Showcase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _showcaseRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
    );
  }
}
