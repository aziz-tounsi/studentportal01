import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_portal/core/services/connectivity_service.dart';
import 'package:student_portal/data/models/absence_model.dart';
import 'package:student_portal/data/models/course_model.dart';
import 'package:student_portal/data/models/grade_model.dart';
import 'package:student_portal/data/models/timetable_model.dart';
import 'package:student_portal/data/services/offline_cache_service.dart';
import 'package:student_portal/presentation/providers/announcements_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineCacheService Unit Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await OfflineCacheService.instance.init();
      await OfflineCacheService.instance.clearAll();
    });

    test('stores and retrieves Map data correctly', () async {
      final cache = OfflineCacheService.instance;
      const key = 'test_profile_map';
      final data = {'id': 'user-1', 'name': 'Sami', 'active': true};

      expect(cache.has(key), isFalse);
      expect(cache.getMap(key), isNull);

      await cache.setJson(key, data);
      expect(cache.has(key), isTrue);

      final retrieved = cache.getMap(key);
      expect(retrieved, isNotNull);
      expect(retrieved!['id'], 'user-1');
      expect(retrieved['name'], 'Sami');
      expect(retrieved['active'], true);
    });

    test('stores and retrieves List of Maps correctly', () async {
      final cache = OfflineCacheService.instance;
      const key = 'test_list_maps';
      final list = [
        {'id': 'item-1', 'value': 10},
        {'id': 'item-2', 'value': 20},
      ];

      await cache.setJson(key, list);
      final retrieved = cache.getListOfMaps(key);

      expect(retrieved, isNotNull);
      expect(retrieved!.length, 2);
      expect(retrieved[0]['id'], 'item-1');
      expect(retrieved[1]['value'], 20);
    });

    test('clears all cached items on logout', () async {
      final cache = OfflineCacheService.instance;
      await cache.setJson('key1', {'a': 1});
      await cache.setJson('key2', ['x', 'y']);

      expect(cache.has('key1'), isTrue);
      expect(cache.has('key2'), isTrue);

      await cache.clearAll();

      expect(cache.has('key1'), isFalse);
      expect(cache.has('key2'), isFalse);
      expect(cache.getMap('key1'), isNull);
    });
  });

  group('Offline Model Serialization Roundtrips', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await OfflineCacheService.instance.init();
    });

    test('SubjectAbsenceSummary serialization and deserialization', () async {
      final summary = SubjectAbsenceSummary(
        subjectOfferingId: 'off-1',
        subjectName: 'Physique-Chimie',
        subjectCode: 'PHY',
        totalHours: 60.0,
        weeklyCiHours: 2.0,
        weeklyTpHours: 1.5,
        weeks: 14,
        totalAbsentHours: 4.5,
        absencePercent: 7.5,
        level: AbsenceLevel.normal,
        warningMessage: null,
        teacherName: 'M. Ben Salem',
      );

      final json = summary.toJson();
      await OfflineCacheService.instance.setJson('summary_test', json);

      final cached = OfflineCacheService.instance.getMap('summary_test');
      expect(cached, isNotNull);

      final restored = SubjectAbsenceSummary.fromJson(cached!);
      expect(restored.subjectOfferingId, summary.subjectOfferingId);
      expect(restored.subjectName, summary.subjectName);
      expect(restored.totalAbsentHours, 4.5);
      expect(restored.absencePercent, 7.5);
      expect(restored.level, AbsenceLevel.normal);
      expect(restored.teacherName, 'M. Ben Salem');
    });

    test('TimetableSlotModel serialization with teacher and subject name', () async {
      final slot = TimetableSlotModel(
        id: 'slot-101',
        subjectOfferingId: 'off-1',
        dayOfWeek: 'lundi',
        startTime: '08:00',
        endTime: '10:00',
        room: 'Salle B12',
        sessionType: 'CI',
        subjectName: 'Informatique',
        subjectCode: 'INFO',
        teacherName: 'Mme. Dupont',
        teacherPhotoUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2026, 9, 1),
      );

      final json = slot.toJson();
      await OfflineCacheService.instance.setJson('slot_test', json);

      final cached = OfflineCacheService.instance.getMap('slot_test');
      expect(cached, isNotNull);

      final restored = TimetableSlotModel.fromJson(cached!);
      expect(restored.id, 'slot-101');
      expect(restored.subjectName, 'Informatique');
      expect(restored.teacherName, 'Mme. Dupont');
      expect(restored.room, 'Salle B12');
    });

    test('SubjectGradesSummary serialization with component grades', () async {
      final gradeSummary = SubjectGradesSummary(
        subjectOfferingId: 'off-grade-1',
        subjectName: 'Mathématiques',
        subjectCode: 'MATH',
        coefficient: 4.0,
        weightsDisplay: 'DC: 25% | DS: 75%',
        components: [
          ComponentGrade(
            componentId: 'c1',
            componentName: 'Devoir de Contrôle 1',
            weightPercent: 25,
            grade: 16.5,
            status: 'OK',
          ),
          ComponentGrade(
            componentId: 'c2',
            componentName: 'Devoir de Synthèse',
            weightPercent: 75,
            grade: 14.0,
            status: 'OK',
          ),
        ],
        average: 14.625,
        teacherName: 'M. Mansour',
      );

      final json = gradeSummary.toJson();
      await OfflineCacheService.instance.setJson('grade_test', json);

      final cached = OfflineCacheService.instance.getMap('grade_test');
      expect(cached, isNotNull);

      final restored = SubjectGradesSummary.fromJson(cached!);
      expect(restored.subjectOfferingId, 'off-grade-1');
      expect(restored.subjectName, 'Mathématiques');
      expect(restored.average, 14.625);
      expect(restored.components.length, 2);
      expect(restored.components[0].grade, 16.5);
    });

    test('StudentAnnouncement serialization roundtrip', () async {
      final ann = StudentAnnouncement(
        id: 'ann-1',
        title: 'Examen Blanc',
        body: 'L\'examen blanc de math aura lieu lundi prochain.',
        announcementType: 'exam',
        isImportant: true,
        publishedAt: DateTime(2026, 11, 15, 9, 30),
        createdAt: DateTime(2026, 11, 15, 9, 30),
        attachments: [
          AnnouncementAttachment(
            id: 'att-1',
            fileName: 'calendrier.pdf',
            fileUrl: 'https://example.com/cal.pdf',
            fileType: 'pdf',
          ),
        ],
      );

      final json = ann.toJson();
      final restored = StudentAnnouncement.fromJson(json);

      expect(restored.id, 'ann-1');
      expect(restored.title, 'Examen Blanc');
      expect(restored.body, 'L\'examen blanc de math aura lieu lundi prochain.');
      expect(restored.attachments.length, 1);
      expect(restored.attachments[0].fileName, 'calendrier.pdf');
    });

    test('CourseModel serialization roundtrip', () async {
      final course = CourseModel(
        id: 'course-1',
        schoolId: 'sch-1',
        classId: 'cls-1',
        subject: 'Sciences',
        teacherName: 'Prof. Martin',
        title: 'Chapitre 3: Génétique',
        description: 'Supports et exercices du chapitre 3.',
        publishedAt: DateTime(2026, 11, 1),
        createdBy: 'usr-prof',
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
        isPublished: true,
      );

      final json = course.toJson();
      final restored = CourseModel.fromJson(json);

      expect(restored.id, 'course-1');
      expect(restored.subject, 'Sciences');
      expect(restored.title, 'Chapitre 3: Génétique');
    });
  });

  group('ConnectivityService State Transitions', () {
    test('reports network error and switches to offlineNoInternet on SocketException', () {
      final service = ConnectivityService.instance;
      service.reportNetworkError(const SocketException('Failed host lookup'));

      expect(service.state, NetworkState.offlineNoInternet);
      expect(service.isOffline, isTrue);
      expect(service.isServerDown, isFalse);
    });

    test('reports server down on 500 error or server response failure', () {
      final service = ConnectivityService.instance;
      service.reportNetworkError(const HttpException('500 Internal Server Error'));

      expect(service.state, NetworkState.offlineServerDown);
      expect(service.isOffline, isTrue);
      expect(service.isServerDown, isTrue);
    });

    test('reports network success and transitions back to online with restoration pulse', () {
      final service = ConnectivityService.instance;
      service.reportNetworkError(const SocketException('Connection lost'));
      expect(service.isOffline, isTrue);

      service.reportNetworkSuccess();
      expect(service.state, NetworkState.online);
      expect(service.isOffline, isFalse);
      expect(service.isRecentlyRestored, isTrue);
    });
  });
}
