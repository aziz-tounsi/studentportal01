import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/timetable_model.dart';
import '../../providers/student_context_provider.dart';
import '../../widgets/semester_navigator.dart';
import '../../widgets/ios_loader.dart';

final emploiSemesterProvider = StateProvider<int>((ref) => 1);

String _parseTime(String time) {
  if (time.length >= 5) {
    return time.substring(0, 5);
  }
  // Pad with leading zero if needed
  if (time.length == 4) {
    return '0$time';
  }
  return time;
}

final Map<String, Color> _subjectColors = {};

Color _getSubjectColor(String subjectCode) {
  if (!_subjectColors.containsKey(subjectCode)) {
    final palette = [
      const Color(0xFFE53935), const Color(0xFFD81B60), const Color(0xFF8E24AA),
      const Color(0xFF5E35B1), const Color(0xFF3949AB), const Color(0xFF1E88E5),
      const Color(0xFF039BE5), const Color(0xFF00ACC1), const Color(0xFF00897B),
      const Color(0xFF43A047), const Color(0xFF7CB342), const Color(0xFFC0CA33),
      const Color(0xFFFDD835), const Color(0xFFFFB300), const Color(0xFFFB8C00),
      const Color(0xFFF4511E), const Color(0xFF6D4C41), const Color(0xFF757575),
      const Color(0xFF546E7A), const Color(0xFFC2185B), const Color(0xFF512DA8),
      const Color(0xFF303F9F), const Color(0xFF1976D2), const Color(0xFF0097A7),
      const Color(0xFF388E3C), const Color(0xFFF57C00), const Color(0xFFE64A19),
    ];
    _subjectColors[subjectCode] = palette[_subjectColors.length % palette.length];
  }
  return _subjectColors[subjectCode]!;
}

final timetableProvider = FutureProvider<List<TimetableSlotModel>>((ref) async {
  final contextAsync = await ref.watch(studentContextProvider.future);

  if (contextAsync == null || contextAsync.classId == null) return [];

  try {
    final offeringsResp = await Supabase.instance.client
        .from('subject_offerings')
        .select('id')
        .eq('class_id', contextAsync.classId!)
        .eq('is_active', true);

    final offeringIds = (offeringsResp as List).map((o) => o['id'] as String).toList();
    if (offeringIds.isEmpty) return [];

    final slotsResp = await Supabase.instance.client
        .from('timetable_slots')
        .select('''
          *, subject_offerings!inner(
            subject_id, teacher_id, semester_id,
            subjects(name, code),
            users!teacher_id(full_name, photo_url)
          )
        ''')
        .inFilter('subject_offering_id', offeringIds)
        .order('day_of_week')
        .order('start_time');

      return (slotsResp as List).map((json) {
        final offering = json['subject_offerings'] as Map<String, dynamic>?;
        final subject = offering?['subjects'] as Map<String, dynamic>?;
        final teacher = offering?['users'] as Map<String, dynamic>?;
        
        debugPrint('Slot: ${subject?['name']} teacher=$teacher');

        return TimetableSlotModel(
        id: json['id'] as String,
        subjectOfferingId: json['subject_offering_id'] as String,
        groupId: json['group_id'] as String?,
        dayOfWeek: json['day_of_week'] as String,
        startTime: _parseTime(json['start_time'] as String),
        endTime: _parseTime(json['end_time'] as String),
        room: json['room'] as String?,
        teacherName: (teacher?['full_name'] as String?) ??
            (json['teacher_name'] as String?),
        teacherPhotoUrl: teacher?['photo_url'] as String?,
        sessionType: json['session_type'] as String? ?? 'CI',
        createdAt: DateTime.parse(json['created_at'] as String),
        subjectName: subject?['name'] as String?,
        subjectCode: subject?['code'] as String?,
      );
    }).toList();
  } catch (e) {
    return [];
  }
});

const List<String> _timeSlots = [
  '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00',
];
const List<String> _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
const List<String> _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

class EmploiScreen extends ConsumerStatefulWidget {
  const EmploiScreen({super.key});

  @override
  ConsumerState<EmploiScreen> createState() => _EmploiScreenState();
}

class _EmploiScreenState extends ConsumerState<EmploiScreen> {
  String? _expandedSlotId;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timetableAsync = ref.watch(timetableProvider);
    final selectedSemester = ref.watch(emploiSemesterProvider);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F0FC),
              Color(0xFFF0E6F8),
              Color(0xFFEAF0FA),
              Color(0xFFF4F8FC),
              Color(0xFFFAFCFD),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: PopScope(
          canPop: !_isExpanded,
          onPopInvoked: (didPop) {
            if (didPop) return;
            setState(() {
              _isExpanded = false;
            });
          },
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: SizedBox(
                        height: 64,
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.emploi,
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1F2937), letterSpacing: -0.8),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Emploi du temps de la classe',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: DynamicSemesterNav(
                        selectedSemesterNumber: selectedSemester,
                        accentColor: const Color(0xFF10B981),
                        secondaryColor: const Color(0xFF059669),
                        onChanged: (v) => ref.read(emploiSemesterProvider.notifier).state = v,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: timetableAsync.when(
                        loading: () => const Center(child: IosLoader(color: Color(0xFF10B981))),
                        error: (e, _) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text('Erreur: $e', style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        data: (slots) {
                          if (slots.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text('Aucun cours planifié', style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }
                          return _buildScrollableTimetable(context, slots);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_isExpanded)
                timetableAsync.when(
                  data: (slots) => Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF8F0FC),
                            Color(0xFFF0E6F8),
                            Color(0xFFEAF0FA),
                            Color(0xFFF4F8FC),
                            Color(0xFFFAFCFD),
                          ],
                          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                      ),
                      child: SafeArea(
                        child: _buildScrollableTimetable(context, slots, isFullScreen: true),
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableTimetable(BuildContext context, List<TimetableSlotModel> slots, {bool isFullScreen = false}) {
    final container = Container(
      margin: isFullScreen 
          ? const EdgeInsets.fromLTRB(16, 60, 16, 16)
          : const EdgeInsets.fromLTRB(20, 0, 20, 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          const timeColWidth = 35.0;
          const headerHeight = 40.0;
          
          final dayColWidth = (availableWidth - timeColWidth) / _dayKeys.length;
          final gridHeight = availableHeight - headerHeight;
          final rowHeight = gridHeight / _timeSlots.length;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: availableWidth,
                height: gridHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...List.generate(_timeSlots.length * 2 + 1, (i) {
                      final isHour = i % 2 == 0;
                      return Positioned(
                        left: timeColWidth,
                        right: 0,
                        bottom: i * (rowHeight / 2),
                        child: Container(
                          height: isHour ? 1.5 : 0.5,
                          color: isHour 
                              ? Colors.grey.withValues(alpha: 0.35) 
                              : Colors.grey.withValues(alpha: 0.1),
                        ),
                      );
                    }),
                    ...List.generate(_dayKeys.length + 1, (i) {
                      return Positioned(
                        left: timeColWidth + i * dayColWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1.0,
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      );
                    }),
                    // Current time - highlight remaining study time with green gradient
                    if (_isCurrentTimeInRange())
                      Positioned(
                        left: timeColWidth,
                        right: 0,
                        bottom: _getCurrentTimePosition(rowHeight),
                        top: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color(0xFF10B981).withValues(alpha: 0.10),
                                const Color(0xFF10B981).withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ...List.generate(_timeSlots.length, (i) {
                      final isCurrentHour = _isCurrentHour(i);
                      return Positioned(
                        left: 0,
                        bottom: i * rowHeight,
                        width: timeColWidth,
                        height: rowHeight,
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              _timeSlots[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrentHour ? FontWeight.w800 : FontWeight.w600,
                                color: isCurrentHour ? const Color(0xFF10B981) : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    ...slots.map((s) {
                      final dayIndex = _dayKeys.indexOf(s.dayOfWeek.toLowerCase());
                      if (dayIndex == -1) return const SizedBox.shrink();

                      final startMin = _timeToMinutes(s.startTime);
                      final endMin = _timeToMinutes(s.endTime);
                      final dayStartMin = _timeToMinutes(_timeSlots.first); 
                      
                      final visibleStartMin = startMin < dayStartMin ? dayStartMin : startMin;
                      
                      final bottom = ((visibleStartMin - dayStartMin) / 60) * rowHeight;
                      final height = ((endMin - visibleStartMin) / 60) * rowHeight;

                      return Positioned(
                        left: timeColWidth + dayIndex * dayColWidth,
                        bottom: bottom,
                        width: dayColWidth,
                        height: height,
                        child: _buildSlotCell(s, height, dayColWidth),
                      );
                    }),
                  ],
                ),
              ),
              Container(
                height: headerHeight,
                width: availableWidth,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: timeColWidth),
                    ...List.generate(_dayKeys.length, (dayIndex) {
                      final isToday = DateTime.now().weekday == dayIndex + 1;
                      return SizedBox(
                        width: dayColWidth,
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              _dayLabels[dayIndex],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                color: isToday ? const Color(0xFF10B981) : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (isFullScreen) {
      return Stack(
        children: [
          Positioned.fill(child: container),
          Positioned(
            top: 10,
            right: 24,
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = false),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.close, size: 24, color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20.0, bottom: 12.0),
          child: InkWell(
            onTap: () => setState(() => _isExpanded = true),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)], // Green gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24), // Pill shape
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Plein écran", 
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.w700, 
                      color: Colors.white
                    )
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.fullscreen, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: container),
      ],
    );
  }

  Widget _buildSlotCell(TimetableSlotModel slot, double height, double width) {
    final color = _getSubjectColor(slot.subjectCode ?? 'DEFAULT');
    final isExpanded = _expandedSlotId == slot.id;
    final timeRange = '${_formatTime(slot.startTime)}-${_formatTime(slot.endTime)}';

    return GestureDetector(
      onTap: () {
        _showSlotDetails(context, slot, color, timeRange);
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot.subjectCode ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (slot.teacherName != null && slot.teacherName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    slot.teacherName!,
                    style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (slot.room != null && slot.room!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    slot.room!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSlotDetails(BuildContext context, TimetableSlotModel slot, Color color, String timeRange) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    slot.subjectCode ?? 'Matière',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (slot.subjectName != null && slot.subjectName!.isNotEmpty) ...[
                  Text(
                    slot.subjectName!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time_filled, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      timeRange,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (slot.room != null && slot.room!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.room, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Salle: ${slot.room}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Enseignant',
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: slot.teacherPhotoUrl != null
                          ? NetworkImage(slot.teacherPhotoUrl!)
                          : null,
                      child: slot.teacherPhotoUrl == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      slot.teacherName ?? 'Non assigné',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * animation.value,
            sigmaY: 8 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    return '${parts[0]}:${parts[1]}';
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool _isCurrentTimeInRange() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeToMinutes(_timeSlots.first);
    final endMinutes = _timeToMinutes(_timeSlots.last) + 60; // Add 1 hour for the last slot
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  double _getCurrentTimePosition(double rowHeight) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeToMinutes(_timeSlots.first);
    return ((currentMinutes - startMinutes) / 60) * rowHeight;
  }

  bool _isCurrentHour(int slotIndex) {
    final now = DateTime.now();
    final currentHour = now.hour;
    final slotHour = _timeToMinutes(_timeSlots[slotIndex]) ~/ 60;
    return currentHour == slotHour;
  }
}
