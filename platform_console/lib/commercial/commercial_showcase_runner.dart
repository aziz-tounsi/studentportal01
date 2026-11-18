import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/theme/console_theme.dart';
import '../presentation/providers/console_auth_provider.dart';
import '../presentation/providers/platform_provider.dart';
import '../presentation/screens/console_dashboard_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/school_profile_screen.dart';
import 'commercial_demo_data.dart';
import 'commercial_director_widget.dart';

// ═══════════════════════════════════════════════════════════════════
// MOCK PROVIDERS FOR HIGH-FIDELITY COMMERCIAL RECORDING
// ═══════════════════════════════════════════════════════════════════

class ShowcaseConsoleAuthNotifier extends ConsoleAuthNotifier {
  @override
  ConsoleAuthState build() {
    return ConsoleAuthState(
      isLoading: false,
      isInitialized: true,
      isAuthenticated: true,
      user: {
        'id': 'super-admin-001',
        'email': 'direction.executive@pythagore.tn',
        'full_name': 'Alexandre Vance',
        'role': 'super_admin',
      },
    );
  }
}

class ShowcasePlatformNotifier extends PlatformNotifier {
  @override
  PlatformState build() {
    return CommercialDemoData.buildState();
  }

  @override
  Future<void> loadAll() async {
    state = CommercialDemoData.buildState();
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
          return CommercialDirectorWidget(
            router: _showcaseRouter,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/login',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ConsoleLoginScreen()),
          ),
          GoRoute(
            path: '/',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/dashboard'),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/dashboard'),
            ),
          ),
          GoRoute(
            path: '/schools',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/schools'),
            ),
          ),
          GoRoute(
            path: '/schools/:schoolId',
            pageBuilder: (context, state) => NoTransitionPage(
              child: SchoolProfileScreen(
                schoolId: state.pathParameters['schoolId'] ??
                    CommercialDemoData.schoolCarthageId,
              ),
            ),
          ),
          GoRoute(
            path: '/billing',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/billing'),
            ),
          ),
          GoRoute(
            path: '/ai-telemetry',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/ai-telemetry'),
            ),
          ),
          GoRoute(
            path: '/audit',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/audit'),
            ),
          ),
          GoRoute(
            path: '/bugs',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/bugs'),
            ),
          ),
          GoRoute(
            path: '/security',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/security'),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ConsoleDashboardScreen(currentRoute: '/settings'),
            ),
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

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('[SHOWCASE] Supabase initialization notice: $e');
  }

  _initRouter();

  runApp(
    ProviderScope(
      overrides: [
        consoleAuthProvider.overrideWith(ShowcaseConsoleAuthNotifier.new),
        platformProvider.overrideWith(ShowcasePlatformNotifier.new),
        schoolProfileDataProvider.overrideWith(
          (ref, schoolId) async =>
              CommercialDemoData.getSchoolProfile(schoolId),
        ),
      ],
      child: const CommercialShowcaseApp(),
    ),
  );
}

class CommercialShowcaseApp extends StatelessWidget {
  const CommercialShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pythagore Commercial Showcase',
      debugShowCheckedModeBanner: false,
      theme: ConsoleTheme.lightTheme,
      routerConfig: _showcaseRouter,
    );
  }
}
