import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'core/config/supabase_config.dart';
import 'core/network/security_trace_http_client.dart';
import 'core/theme/console_theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/console_dashboard_screen.dart';
import 'presentation/screens/school_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intercept uncaught framework & platform dispatch errors for correlated telemetry
  FlutterError.onError = (details) {
    debugPrint('[CONSOLE] FlutterError: ${details.exceptionAsString()}');
    SecurityTraceHttpClient.logTelemetry(
      eventName: 'flutter_framework_error',
      severity: 'error',
      metadata: {
        'exception': details.exceptionAsString(),
        'library': details.library,
      },
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[CONSOLE] PlatformDispatcher error: $error');
    SecurityTraceHttpClient.logTelemetry(
      eventName: 'platform_dispatcher_error',
      severity: 'critical',
      metadata: {'error': error.toString()},
    );
    return true;
  };

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    httpClient: SecurityTraceHttpClient(
      appSurface: 'console_admin',
      onForceDisconnect: (reason) {
        debugPrint('[SECURITY] Console forced disconnect: $reason');
      },
    ),
  );

  runApp(const ProviderScope(child: PlatformConsoleApp()));
}

final _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (_, _) => const NoTransitionPage(child: ConsoleLoginScreen()),
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
          schoolId: state.pathParameters['schoolId']!,
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
);

class PlatformConsoleApp extends StatelessWidget {
  const PlatformConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PythaOne SaaS Console',
      debugShowCheckedModeBanner: false,
      theme: ConsoleTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
