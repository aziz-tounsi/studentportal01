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
          final mediaQuery = MediaQuery.of(context);
          final clampedTextScaler = mediaQuery.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.10,
          );
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: clampedTextScaler),
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
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
