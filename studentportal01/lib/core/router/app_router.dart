import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/messages/messages_screen_new.dart';
import '../../presentation/screens/suggestions/suggestions_screen_new.dart';
import '../../presentation/screens/suggestions/write_suggestion_screen.dart';
import '../../presentation/screens/absences/absences_screen.dart';
import '../../presentation/screens/absences/absence_detail_screen.dart';
import '../../presentation/screens/resultats/resultats_screen_v2.dart';
import '../../presentation/screens/emploi/emploi_screen.dart';
import '../../presentation/screens/courses/courses_screen.dart';
import '../../presentation/screens/courses/course_detail_screen.dart';
import '../../presentation/screens/mon_solde/mon_solde_screen.dart';
import '../../presentation/screens/documents/documents_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/contact/contact_screen.dart';
import '../../presentation/screens/about/about_screen.dart';
import '../../presentation/screens/bug_report/report_bug_screen.dart';
import '../../presentation/screens/stats/stats_screen.dart';
import '../../presentation/screens/ai_chat/ai_chat_screen.dart';
import '../../presentation/widgets/bubble_nav_bar.dart';
import '../../presentation/widgets/ios_edge_swipe_back.dart';
import '../../presentation/providers/nav_bar_provider.dart';

// Navigator keys for clean overlay/popup dismissal across tabs
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shellNav');

/// Dismisses any open menus, dialogs, bottom sheets or popup overlays
void dismissAllOverlaysAndPopups() {
  try {
    final rootNav = rootNavigatorKey.currentState;
    while (rootNav != null && rootNav.canPop()) {
      rootNav.pop();
    }
  } catch (_) {}
  try {
    final shellNav = shellNavigatorKey.currentState;
    while (shellNav != null && shellNav.canPop()) {
      shellNav.pop();
    }
  } catch (_) {}
}

// Helper to determine the nav bar index based on current location
int _getNavBarIndex(String location) {
  if (location == '/') return 0;
  if (location == '/messages') return 1;
  if (location == '/notifications') return 2;
  if (location == '/ai-chat') return 3;
  return 0;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      if (isLoggedIn && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final fromAIChat = ref.watch(navigatedFromAIChatProvider);
              final isHome = state.matchedLocation == '/';
              final isAIChat = state.matchedLocation == '/ai-chat';
              final isWriteSuggestion =
                  state.matchedLocation == '/write-suggestion';
              final isReportBug = state.matchedLocation == '/report-bug';
              final isAbsenceDetail =
                  state.matchedLocation.startsWith('/absences/');
              final hideNavBar = ref.watch(navBarHiddenProvider) ||
                  isWriteSuggestion ||
                  isReportBug ||
                  isAbsenceDetail ||
                  isAIChat;

              const homeGradient = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8D5F2),
                  Color(0xFFD4C4E8),
                  Color(0xFFC9D6F0),
                  Color(0xFFE0EAF5),
                  Color(0xFFF0F5FA),
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              );

              const aiChatGradient = LinearGradient(
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
              );

              final isSideNavPage = const [
                '/settings',
                '/contact',
                '/about',
                '/profile',
              ].contains(state.matchedLocation);

              final backSwipeInterceptor = ref.watch(backSwipeInterceptorProvider);

              final backgroundWidget = isWriteSuggestion
                  ? const SuggestionsScreen()
                  : isReportBug
                      ? const AboutScreen()
                      : isAbsenceDetail
                          ? (fromAIChat ? const AIChatScreen() : const AbsencesScreen())
                          : fromAIChat
                              ? const AIChatScreen()
                              : isSideNavPage
                                  ? const HomeScreen(forceDrawerOpen: true)
                                  : const HomeScreen();

              final backgroundGradient = fromAIChat ? aiChatGradient : homeGradient;

              final onReturnCallback = isWriteSuggestion
                  ? () => context.go('/suggestions')
                  : isReportBug
                      ? () => context.go('/about')
                      : isAbsenceDetail
                          ? () {
                              if (fromAIChat) {
                                ref.read(navigatedFromAIChatProvider.notifier).state = false;
                                context.go('/ai-chat');
                              } else {
                                context.go('/absences');
                              }
                            }
                  : isAIChat
                      ? () {
                          ref.read(navBarHiddenProvider.notifier).state = false;
                          context.go('/');
                        }
                      : fromAIChat
                          ? () {
                              ref.read(navigatedFromAIChatProvider.notifier).state = false;
                              context.go('/ai-chat');
                            }
                          : isSideNavPage
                              ? () {
                                  ref.read(sideDrawerOpenProvider.notifier).state = true;
                                  ref.read(navBarHiddenProvider.notifier).state = true;
                                  context.go('/');
                                }
                              : () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  } else if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/');
                                  }
                                };

              if (isAIChat) {
                return IosEdgeSwipeBack(
                  key: const ValueKey('/ai-chat'),
                  backgroundPage: const HomeScreen(),
                  backgroundGradient: homeGradient,
                  onReturn: onReturnCallback,
                  onInterceptSwipe: () {
                    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 50;
                    if (isKeyboardOpen) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      return true;
                    }
                    return backSwipeInterceptor != null ? backSwipeInterceptor() : false;
                  },
                  child: child,
                );
              }

              return Scaffold(
                extendBody: true,
                body: isHome
                    ? child
                    : IosEdgeSwipeBack(
                        key: ValueKey(state.matchedLocation),
                        backgroundPage: backgroundWidget,
                        backgroundGradient: backgroundGradient,
                        onReturn: onReturnCallback,
                        onInterceptSwipe: isSideNavPage ? null : backSwipeInterceptor,
                        child: child,
                      ),
                bottomNavigationBar: hideNavBar
                    ? null
                    : AnimatedSlide(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        offset: Offset.zero,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: 1.0,
                          child: IgnorePointer(
                            ignoring: false,
                            child: BubbleNavBar(
                              currentIndex: _getNavBarIndex(state.matchedLocation),
                            ),
                          ),
                        ),
                      ),
              );
            },
          );
        },
        routes: [
          // Main Nav Bar Routes
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const HomeScreen()),
          ),
          GoRoute(
            path: '/messages',
            name: 'messages',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const MessagesScreen()),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const NotificationsScreen()),
          ),
          GoRoute(
            path: '/stats',
            name: 'stats',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const StatsScreen()),
          ),
          GoRoute(
            path: '/courses',
            name: 'courses',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const CoursesScreen()),
          ),
          GoRoute(
            path: '/suggestions',
            name: 'suggestions',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const SuggestionsScreen()),
          ),
          GoRoute(
            path: '/write-suggestion',
            name: 'write-suggestion',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const WriteSuggestionScreen()),
          ),
          GoRoute(
            path: '/report-bug',
            name: 'report-bug',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ReportBugScreen()),
          ),
          // Feature pages WITH nav bar
          GoRoute(
            path: '/absences',
            name: 'absences',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const AbsencesScreen()),
          ),
          GoRoute(
            path: '/absences/:offeringId',
            name: 'absence-detail',
            pageBuilder: (context, state) {
              final offeringId = state.pathParameters['offeringId']!;
              return NoTransitionPage(
                child: AbsenceDetailScreen(subjectOfferingId: offeringId),
              );
            },
          ),
          GoRoute(
            path: '/resultats',
            name: 'resultats',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ResultatsScreenV2()),
          ),
          GoRoute(
            path: '/emploi',
            name: 'emploi',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const EmploiScreen()),
          ),
          GoRoute(
            path: '/mon-solde',
            name: 'mon-solde',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const MonSoldeScreen()),
          ),
          GoRoute(
            path: '/documents',
            name: 'documents',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const DocumentsScreen()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ProfileScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const SettingsScreen()),
          ),
          GoRoute(
            path: '/contact',
            name: 'contact',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ContactScreen()),
          ),
          GoRoute(
            path: '/about',
            name: 'about',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const AboutScreen()),
          ),
          GoRoute(
            path: '/ai-chat',
            name: 'ai-chat',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const AIChatScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/courses/:courseId',
        name: 'course-detail',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CourseDetailScreen(courseId: courseId);
        },
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
  );
});
