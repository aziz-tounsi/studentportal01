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

    String message;
    IconData icon;
    Color primaryColor;
    Color bgTint;
    Color borderColor;

    if (isRecentlyRestored) {
      message = AppLocalizations.of(context).translate('online_restored');
      icon = Icons.check_circle_rounded;
      primaryColor = const Color(0xFF059669); // Emerald 600
      bgTint = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
    } else if (isServerDown) {
      message = AppLocalizations.of(context).translate('server_down_short');
      icon = Icons.cloud_off_rounded;
      primaryColor = const Color(0xFFD97706); // Amber 600
      bgTint = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.45);
    } else {
      message = AppLocalizations.of(context).translate('offline_short');
      icon = Icons.wifi_off_rounded;
      primaryColor = const Color(0xFFD97706); // Amber 600
      bgTint = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.45);
    }

    final textStyle = isArabic
        ? GoogleFonts.tajawal(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: primaryColor,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          );

    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        offset: isVisible ? const Offset(0, 0.15) : const Offset(0, -1.8),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isVisible ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: bgTint.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing / Status dot & icon
                        Icon(
                          icon,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        // Label text
                        Text(
                          message,
                          style: textStyle,
                        ),
                        if (isOffline) ...[
                          const SizedBox(width: 8),
                          // Retry button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isChecking
                                  ? null
                                  : () => connectivityService.checkConnection(),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: isChecking
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            primaryColor,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                        color: primaryColor,
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
            ),
          ),
        ),
      ),
    );
  }
}
