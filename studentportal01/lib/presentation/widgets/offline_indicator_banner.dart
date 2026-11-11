import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/arabic_typography.dart';
import '../providers/connectivity_provider.dart';

/// An elegant, unobtrusive floating pill indicator displayed at the top
/// of the app when the device is offline or the server is down.
class OfflineIndicatorBanner extends ConsumerWidget {
  const OfflineIndicatorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    final isServerDown = ref.watch(isServerDownProvider);
    final isRecentlyRestored = ref.watch(isRecentlyRestoredProvider);
    final connectivityService = ref.watch(connectivityServiceProvider);
    final isChecking = connectivityService.isChecking;

    final isVisible = isOffline || isRecentlyRestored;
    final isArabic = ArabicTypography.isArabic(context);

    final String message;
    if (isRecentlyRestored) {
      message = AppLocalizations.of(context).translate('online_restored');
    } else if (isServerDown) {
      message = AppLocalizations.of(context).translate('server_down_short');
    } else {
      message = AppLocalizations.of(context).translate('offline_short');
    }

    final isOnline = isRecentlyRestored;
    final dotColor = isOnline ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    final icon = isOnline
        ? Icons.check_rounded
        : (isServerDown ? Icons.cloud_off_rounded : Icons.wifi_off_rounded);

    final textStyle = isArabic
        ? GoogleFonts.tajawal(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          );

    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, -1.5),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: isVisible ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: isChecking
                          ? null
                          : () => connectivityService.checkConnection(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isChecking)
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(dotColor),
                                ),
                              )
                            else
                              Icon(
                                icon,
                                size: 12,
                                color: dotColor,
                              ),
                            const SizedBox(width: 5),
                            Text(
                              message,
                              style: textStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
