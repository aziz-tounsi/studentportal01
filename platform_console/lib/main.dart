import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/console_theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/console_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: PlatformConsoleApp()));
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (_, _) => const NoTransitionPage(child: ConsoleLoginScreen()),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (_, _) => const NoTransitionPage(child: ConsoleDashboardScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (_, _) => const NoTransitionPage(child: ConsoleDashboardScreen()),
    ),
  ],
);

class PlatformConsoleApp extends StatelessWidget {
  const PlatformConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pythagore Platform Console',
      debugShowCheckedModeBanner: false,
      theme: ConsoleTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
