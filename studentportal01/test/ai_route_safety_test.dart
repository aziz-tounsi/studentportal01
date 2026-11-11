import 'package:flutter_test/flutter_test.dart';
import 'package:student_portal/presentation/screens/ai_chat/ai_chat_screen.dart';

void main() {
  group('AI Route Safety & Hallucination Prevention', () {
    test('resolveSafeStudentRoute approves valid student routes', () {
      expect(resolveSafeStudentRoute('/emploi'), '/emploi');
      expect(resolveSafeStudentRoute('/resultats'), '/resultats');
      expect(resolveSafeStudentRoute('/absences'), '/absences');
      expect(resolveSafeStudentRoute('/absences/offering-123'), '/absences/offering-123');
      expect(resolveSafeStudentRoute('/mon-solde'), '/mon-solde');
      expect(resolveSafeStudentRoute('/documents'), '/documents');
      expect(resolveSafeStudentRoute('/messages'), '/messages');
      expect(resolveSafeStudentRoute('/notifications'), '/notifications');
      expect(resolveSafeStudentRoute('/suggestions'), '/suggestions');
      expect(resolveSafeStudentRoute('/profile'), '/profile');
      expect(resolveSafeStudentRoute('/settings'), '/settings');
      expect(resolveSafeStudentRoute('/contact'), '/contact');
      expect(resolveSafeStudentRoute('/about'), '/about');
    });

    test('resolveSafeStudentRoute safely redirects legacy/obsolete routes', () {
      // /courses and /courses/:id safely redirect to timetable /emploi
      expect(resolveSafeStudentRoute('/courses'), '/emploi');
      expect(resolveSafeStudentRoute('/courses/course-abc-123'), '/emploi');
      // /stats safely redirects to /resultats
      expect(resolveSafeStudentRoute('/stats'), '/resultats');
    });

    test('resolveSafeStudentRoute rejects unknown/hallucinated routes', () {
      expect(resolveSafeStudentRoute('/unknown_route'), isNull);
      expect(resolveSafeStudentRoute('/admin'), isNull);
      expect(resolveSafeStudentRoute('/forum'), isNull);
      expect(resolveSafeStudentRoute('/fake-module'), isNull);
    });

    test('detectAIRoutesForLanguage never emits /courses or /stats', () {
      const texts = [
        'Ton cours de Mathématiques commence à 08:30.',
        'Mes cours sont tous validés.',
        'Here are your courses for this semester.',
        'دروسك لهذا اليوم تم تحديثها.',
        'Voici les statistiques de tes résultats.',
        'Consulter les cours disponibles.',
      ];

      for (final text in texts) {
        final routesFr = detectAIRoutesForLanguage(text, 'fr');
        final routesAr = detectAIRoutesForLanguage(text, 'ar');
        final routesEn = detectAIRoutesForLanguage(text, 'en');

        expect(routesFr.contains('/courses'), isFalse);
        expect(routesFr.contains('/stats'), isFalse);
        expect(routesAr.contains('/courses'), isFalse);
        expect(routesAr.contains('/stats'), isFalse);
        expect(routesEn.contains('/courses'), isFalse);
        expect(routesEn.contains('/stats'), isFalse);
      }
    });

    test('detectAIRoutesForLanguage maps next class questions to /emploi', () {
      final routesFr = detectAIRoutesForLanguage('Ton prochain cours est à 10:00.', 'fr');
      expect(routesFr, contains('/emploi'));

      final routesAr = detectAIRoutesForLanguage('حصتي القادمة تبدأ في العاشرة صباحاً.', 'ar');
      expect(routesAr, contains('/emploi'));
    });
  });
}
