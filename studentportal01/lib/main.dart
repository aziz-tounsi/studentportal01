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
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/theme_provider.dart';

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

      // Initialize Supabase
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

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
      return theme.copyWith(
        textTheme: GoogleFonts.cairoTextTheme(theme.textTheme),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: GoogleFonts.cairo(
            textStyle: theme.appBarTheme.titleTextStyle,
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
    final themeNotifier = ref.watch(themeProvider.notifier);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: MaterialApp.router(
        title: 'PythaOne',
        debugShowCheckedModeBanner: false,
        theme: _applyLocaleFont(AppTheme.lightTheme, locale),
        darkTheme: _applyLocaleFont(AppTheme.darkTheme, locale),
        themeMode: themeNotifier.themeMode,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    );
  }
}
