/// Dynamic Semester Navigator Widget
///
/// This widget displays semester tabs dynamically based on the semesters
/// available in the database. No hardcoded "Semestre 1/2" logic.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_localizations.dart';

import '../../data/services/core_data_service.dart';
import '../providers/student_context_provider.dart';
import 'ios_loader.dart';

/// Dynamic Semester Navigator - iOS 26 Style
///
/// Fetches semesters from the database and displays them dynamically.
/// Supports 2, 3, or any number of semesters per academic year.
class DynamicSemesterNav extends ConsumerStatefulWidget {
  final int selectedSemesterNumber;
  final ValueChanged<int> onChanged;
  final Color accentColor;
  final Color secondaryColor;

  const DynamicSemesterNav({
    super.key,
    required this.selectedSemesterNumber,
    required this.onChanged,
    this.accentColor = const Color(0xFF06B6D4),
    this.secondaryColor = const Color(0xFF3B82F6),
  });

  @override
  ConsumerState<DynamicSemesterNav> createState() => _DynamicSemesterNavState();
}

class _DynamicSemesterNavState extends ConsumerState<DynamicSemesterNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousSemesterNumber = 1;

  @override
  void initState() {
    super.initState();
    _previousSemesterNumber = widget.selectedSemesterNumber;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(DynamicSemesterNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSemesterNumber != widget.selectedSemesterNumber) {
      _previousSemesterNumber = oldWidget.selectedSemesterNumber;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semestersAsync = ref.watch(semestersProvider);

    return semestersAsync.when(
      data: (semesters) => _buildNav(context, semesters),
      loading: () => _buildLoadingNav(),
      error: (_, _) => _buildNav(context, _getDefaultSemesters()),
    );
  }

  List<SemesterInfo> _getDefaultSemesters() {
    // Default fallback: 1 semester
    return [
      SemesterInfo(id: '1', name: 'Semestre 1', number: 1, isCurrent: true),
    ];
  }

  Widget _buildLoadingNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(child: IosLoader()),
        ),
      ),
    );
  }

  Widget _buildNav(BuildContext context, List<SemesterInfo> semesters) {
    if (semesters.isEmpty) {
      semesters = _getDefaultSemesters();
    }

    // Sort by number
    semesters.sort((a, b) => a.number.compareTo(b.number));
    final count = semesters.length;
    final currentIndex = _resolveSelectedIndex(
      semesters,
      widget.selectedSemesterNumber,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / count;

              return Stack(
                children: [
                  // Animated glass pill indicator
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final previousIdx = _resolveSelectedIndex(
                        semesters,
                        _previousSemesterNumber,
                      );
                      final startPos = previousIdx * tabWidth;
                      final endPos = currentIndex * tabWidth;
                      final currentPos =
                          startPos + (endPos - startPos) * _animation.value;

                      return Positioned(
                        left: currentPos,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                widget.accentColor,
                                widget.secondaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accentColor.withValues(alpha: 0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Tab labels - dynamic from semesters
                  Row(
                    textDirection: TextDirection.ltr,
                    children: semesters.asMap().entries.map((entry) {
                      final index = entry.key;
                      final semester = entry.value;
                      final localizedName = semester.name.replaceAll('Semestre', AppLocalizations.of(context).semester);
                      final isSelected = index == currentIndex;
                      return Expanded(
                        child: _SemesterTab(
                          label: localizedName,
                          isSelected: isSelected,
                          onTap: () => widget.onChanged(semester.number),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  int _resolveSelectedIndex(List<SemesterInfo> semesters, int selectedNumber) {
    final selectedIndex = semesters.indexWhere(
      (s) => s.number == selectedNumber,
    );
    if (selectedIndex != -1) return selectedIndex;

    final currentIndex = semesters.indexWhere((s) => s.isCurrent);
    if (currentIndex != -1) return currentIndex;

    return 0;
  }
}

class _SemesterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SemesterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: isArabic
              ? TextStyle(fontFamily: GoogleFonts.cairo().fontFamily, fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[600],
                  shadows: isSelected
                      ? [
                          const Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                )
              : TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  letterSpacing: -0.2,
                  shadows: isSelected
                      ? [
                          const Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Simple Semester Tab Bar for screens that need a more compact design
class SemesterTabBar extends ConsumerWidget {
  final int selectedNumber;
  final ValueChanged<int> onChanged;
  final Color? activeColor;

  const SemesterTabBar({
    super.key,
    required this.selectedNumber,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semestersAsync = ref.watch(semestersProvider);
    final color = activeColor ?? Theme.of(context).primaryColor;

    return semestersAsync.when(
      data: (semesters) {
        if (semesters.isEmpty) {
          // Fallback
          return _buildTabs(context, [
            SemesterInfo(id: '1', name: 'Sem. 1', number: 1, isCurrent: false),
            SemesterInfo(id: '2', name: 'Sem. 2', number: 2, isCurrent: false),
          ], color);
        }
        semesters.sort((a, b) => a.number.compareTo(b.number));
        return _buildTabs(context, semesters, color);
      },
      loading: () =>
          const SizedBox(height: 40, child: Center(child: IosLoader())),
      error: (_, _) => _buildTabs(context, [
        SemesterInfo(id: '1', name: 'Sem. 1', number: 1, isCurrent: false),
        SemesterInfo(id: '2', name: 'Sem. 2', number: 2, isCurrent: false),
      ], color),
    );
  }

  Widget _buildTabs(BuildContext context, List<SemesterInfo> semesters, Color color) {
    const selectedTextColor = Colors.white;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: semesters.map((semester) {
          final isSelected = selectedNumber == semester.number;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(semester.number),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  semester.name.replaceAll('Semestre', AppLocalizations.of(context).semester),
                  style: Localizations.localeOf(context).languageCode == 'ar'
                      ? TextStyle(fontFamily: GoogleFonts.cairo().fontFamily, fontSize: 12.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? selectedTextColor : Colors.grey[700],
                        )
                      : TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? selectedTextColor : Colors.grey[700],
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
