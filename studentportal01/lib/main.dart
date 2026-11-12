import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/services/notification_service.dart';
import 'data/services/offline_cache_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/widgets/offline_indicator_banner.dart';

void main() {
  // runZonedGuarded must wrap EVERYTHING including ensureInitialized so that
  // the binding and runApp are in the same zone (prevents "Zone mismatch" crash).
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting();

      // Catch all unhandled Flutter framework errors (prevent crashes)
      FlutterError.onError = (details) {
        debugPrint('FlutterError caught: ${details.exceptionAsString()}');
      };

      // Initialize persistent offline cache
      await OfflineCacheService.instance.init();

      // Initialize Supabase
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

      // Initialize native local notifications for system alerts
      await LocalNotificationService.init();

      // Set system UI overlay style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      runApp(
        const ProviderScope(
          child: StudentPortalApp(),
        ),
      );
    },
    (error, stack) {
      // Log but do NOT rethrow — prevents "Lost connection to device" crashes
      // caused by AuthRetryableFetchException from GoTrue auto-refresh.
      debugPrint('Unhandled async error (zone): $error');
    },
  );
}



class StudentPortalApp extends ConsumerWidget {
  const StudentPortalApp({super.key});

  ThemeData _applyLocaleFont(ThemeData theme, Locale? locale) {
    if (locale?.languageCode == 'ar') {
      final isDark = theme.brightness == Brightness.dark;
      final pColor = isDark ? Colors.white : AppColors.textPrimary;
      final sColor = isDark ? Colors.grey[400]! : AppColors.textSecondary;

      final arabicText = AppTheme.arabicTextTheme(
        theme.textTheme,
        primaryColor: pColor,
        secondaryColor: sColor,
      );

      return theme.copyWith(
        textTheme: arabicText,
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: pColor,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          labelStyle: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: sColor,
          ),
          hintStyle: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: pColor,
          ),
          contentTextStyle: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: sColor,
          ),
        ),
      );
    }
    return theme;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: MaterialApp.router(
        title: 'PythaOne',
        debugShowCheckedModeBanner: false,
        theme: _applyLocaleFont(AppTheme.lightTheme, locale),
        darkTheme: _applyLocaleFont(AppTheme.lightTheme, locale),
        themeMode: ThemeMode.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
        builder: (context, child) {
          final authState = ref.watch(authProvider);
          final mediaQuery = MediaQuery.of(context);
          final clampedTextScaler = mediaQuery.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.10,
          );

          Widget body = child ?? const SizedBox.shrink();
          if (authState.isAuthenticated &&
              (authState.schoolSuspended ||
                  authState.user?.accountStatus == 'paused_unpaid')) {
            body = _AccessLockedScreen(
              isSchoolSuspended: authState.schoolSuspended,
              onRefresh: () => ref.read(authProvider.notifier).refreshUserData(),
              onSignOut: () => ref.read(authProvider.notifier).signOut(),
            );
          }

          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: clampedTextScaler),
            child: Stack(
              children: [
                body,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: OfflineIndicatorBanner(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccessLockedScreen extends StatelessWidget {
  final bool isSchoolSuspended;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  const _AccessLockedScreen({
    required this.isSchoolSuspended,
    required this.onRefresh,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 32,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isSchoolSuspended
                        ? 'Accès établissement suspendu'
                        : 'Accès temporairement suspendu',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isSchoolSuspended
                        ? 'Les services de votre établissement sont temporairement suspendus. Veuillez contacter la direction de votre école.'
                        : 'Votre accès aux notes, emplois du temps, absences et documents est mis en pause en raison de frais de scolarité impayés. Veuillez régulariser auprès de l\'administration.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Vérifier mon accès'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text(
                      'Se déconnecter',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
