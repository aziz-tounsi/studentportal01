import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart' show AppColors;
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/users/users_screen.dart';
import '../../presentation/screens/users/user_profile_screen.dart';
import '../../presentation/screens/users/bulk_photo_upload_screen.dart';
import '../../presentation/screens/users/simple_bulk_import_screen.dart';
import '../../presentation/screens/classes/classes_screen.dart';
import '../../presentation/screens/classes/class_detail_screen.dart';
import '../../presentation/screens/grade_levels/grade_levels_screen.dart';
import '../../presentation/screens/semesters/semesters_screen.dart';
import '../../presentation/screens/subjects/subjects_management_screen.dart';
import '../../presentation/screens/timetables/timetables_screen.dart';
import '../../presentation/screens/announcements/announcements_screen.dart';
import '../../presentation/screens/absences/absences_screen.dart';
import '../../presentation/screens/absences/student_absences_screen.dart';
import '../../presentation/screens/results_screen.dart';
import '../../presentation/screens/suggestions/suggestions_screen.dart';
import '../../presentation/screens/payments/payments_screen.dart';
import '../../presentation/screens/documents/documents_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/contact_info_screen.dart';
import '../../presentation/screens/settings/school_info_screen.dart';
import '../../presentation/screens/settings/password_reset_requests_screen.dart';
import '../../presentation/screens/structure/building_structure_screen.dart';
import '../../presentation/screens/teachers/teacher_profile_screen.dart';
import '../../presentation/screens/teachers/professors_screen.dart';
import '../../presentation/screens/subscription/subscription_screen.dart';
import '../../presentation/screens/platform_console/platform_console_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  debugLogDiagnostics: true, // Enable debug logging
  errorBuilder: (context, state) {
    debugPrint('GoRouter ERROR: ${state.error}');
    debugPrint('GoRouter ERROR path: ${state.uri}');
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Route non trouvée: ${state.uri}'),
            const SizedBox(height: 8),
            Text('${state.error}', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  },
  routes: [
    GoRoute(path: '/login', pageBuilder: (_, _) => const NoTransitionPage(child: LoginScreen())),
    GoRoute(path: '/', pageBuilder: (_, _) => const NoTransitionPage(child: DashboardScreen())),
    GoRoute(path: '/dashboard', pageBuilder: (_, _) => const NoTransitionPage(child: DashboardScreen())),
    GoRoute(path: '/users', pageBuilder: (_, _) => const NoTransitionPage(child: UsersScreen())),
    GoRoute(
      path: '/users/bulk-photos',
      pageBuilder: (_, _) => const NoTransitionPage(child: BulkPhotoUploadScreen()),
    ),
    GoRoute(
      path: '/users/bulk-import',
      pageBuilder: (_, _) => const NoTransitionPage(child: SimpleBulkImportScreen()),
    ),
    GoRoute(path: '/classes', pageBuilder: (_, _) => const NoTransitionPage(child: ClassesScreen())),
    GoRoute(
      path: '/classes/:classId',
      pageBuilder: (context, state) => NoTransitionPage(
        child: ClassDetailScreen(classId: state.pathParameters['classId']!),
      ),
    ),
    GoRoute(
      path: '/grade-levels',
      pageBuilder: (_, _) => const NoTransitionPage(child: GradeLevelsScreen()),
    ),
    GoRoute(path: '/semesters', pageBuilder: (_, _) => const NoTransitionPage(child: SemestersScreen())),
    GoRoute(
      path: '/subjects',
      pageBuilder: (_, _) => const NoTransitionPage(child: SubjectsManagementScreen()),
    ),
    GoRoute(path: '/timetables', pageBuilder: (_, _) => const NoTransitionPage(child: TimetablesScreen())),
    GoRoute(
      path: '/announcements',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        debugPrint('Router: Announcements route - extra data: $extra');
        final scope = extra?['initialScope'] ?? extra?['scope'];
        final studentId = extra?['preSelectedStudentId'] ?? extra?['studentId'];
        return NoTransitionPage(
          child: AnnouncementsScreen(
            initialScope: scope as String?,
            preSelectedStudentId: studentId as String?,
          ),
        );
      },
    ),
    GoRoute(path: '/absences', pageBuilder: (_, _) => const NoTransitionPage(child: AbsencesScreen())),
    GoRoute(
      path: '/student-absences/:studentId',
      pageBuilder: (context, state) => NoTransitionPage(
        child: StudentAbsencesScreen(studentId: state.pathParameters['studentId']!),
      ),
    ),
    GoRoute(path: '/results', pageBuilder: (_, _) => const NoTransitionPage(child: ResultsScreen())),
    GoRoute(path: '/suggestions', pageBuilder: (_, _) => const NoTransitionPage(child: SuggestionsScreen())),
    GoRoute(path: '/payments', pageBuilder: (_, _) => const NoTransitionPage(child: PaymentsScreen())),
    GoRoute(path: '/subscription', pageBuilder: (_, _) => const NoTransitionPage(child: SubscriptionScreen())),
    GoRoute(path: '/platform-console', pageBuilder: (_, _) => const NoTransitionPage(child: PlatformConsoleScreen())),
    GoRoute(path: '/documents', pageBuilder: (_, _) => const NoTransitionPage(child: DocumentsScreen())),
    GoRoute(
      path: '/structure',
      pageBuilder: (_, _) => const NoTransitionPage(child: BuildingStructureScreen()),
    ),
    GoRoute(path: '/settings', pageBuilder: (_, _) => const NoTransitionPage(child: SettingsScreen())),
    GoRoute(
      path: '/settings/contact-info',
      pageBuilder: (_, _) => const NoTransitionPage(child: ContactInfoScreen()),
    ),
    GoRoute(
      path: '/settings/school-info',
      pageBuilder: (_, _) => const NoTransitionPage(child: SchoolInfoScreen()),
    ),
    GoRoute(
      path: '/password-resets',
      pageBuilder: (_, _) => const NoTransitionPage(child: PasswordResetRequestsScreen()),
    ),
    GoRoute(
      path: '/teachers/:teacherId',
      pageBuilder: (context, state) => NoTransitionPage(
        child: TeacherProfileScreen(teacherId: state.pathParameters['teacherId']!),
      ),
    ),
    GoRoute(path: '/professors', pageBuilder: (_, _) => const NoTransitionPage(child: ProfessorsScreen())),
    GoRoute(
      path: '/users/:userId',
      pageBuilder: (context, state) => NoTransitionPage(
        child: UserProfileScreen(userId: state.pathParameters['userId']!),
      ),
    ),
  ],
);
