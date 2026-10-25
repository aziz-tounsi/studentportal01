import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_portal/core/l10n/app_localizations.dart';
import 'package:student_portal/data/models/grade_model.dart';
import 'package:student_portal/data/models/user_model.dart';
import 'package:student_portal/data/repositories/results_repository.dart';
import 'package:student_portal/data/services/core_data_service.dart';

void main() {
  group('StudentContext Parsing & Business Invariants', () {
    test('parses nested structure correctly with enrollment and cycle', () {
      final json = {
        'user': {
          'id': 'usr-123',
          'full_name': 'Ahmed Ben Ali',
          'email': 'ahmed@example.com',
          'student_code': 'STD-001',
        },
        'school_id': 'sch-456',
        'enrollment': {
          'id': 'enr-789',
          'class_id': 'cls-101',
          'academic_year_id': 'ay-2026',
        },
        'class': {
          'id': 'cls-101',
          'name': '3S M 1',
        },
        'niveau': {
          'id': 'niv-3s',
          'code': '3S',
          'name': '3ème Secondaire',
          'cycle': 'secondaire',
          'has_sections': true,
        },
        'section': {
          'id': 'sec-m',
          'code': 'M',
          'name': 'Mathématiques',
        },
        'academic_year': {
          'id': 'ay-2026',
          'name': '2025-2026',
          'is_current': true,
        },
      };

      final context = StudentContext.fromJson(json);

      expect(context.userId, 'usr-123');
      expect(context.schoolId, 'sch-456');
      expect(context.fullName, 'Ahmed Ben Ali');
      expect(context.email, 'ahmed@example.com');
      expect(context.studentCode, 'STD-001');
      expect(context.enrollmentId, 'enr-789');
      expect(context.classId, 'cls-101');
      expect(context.className, '3S M 1');
      expect(context.niveauCode, '3S');
      expect(context.cycle, 'secondaire');
      expect(context.hasSections, isTrue);
      expect(context.sectionCode, 'M');
      expect(context.sectionName, 'Mathématiques');
      expect(context.isCurrentYear, isTrue);
      expect(context.hasEnrollment, isTrue);
      expect(context.isSecondaire, isTrue);
      expect(context.isBase, isFalse);
    });

    test('handles missing optional fields safely', () {
      final json = {
        'user_id': 'usr-orphan',
        'school_id': 'sch-none',
      };

      final context = StudentContext.fromJson(json);

      expect(context.userId, 'usr-orphan');
      expect(context.schoolId, 'sch-none');
      expect(context.fullName, isNull);
      expect(context.hasEnrollment, isFalse);
      expect(context.isSecondaire, isFalse);
      expect(context.isBase, isFalse);
    });
  });

  group('TimetableSlotInfo Day Index', () {
    test('computes day index correctly for all days', () {
      final days = [
        ('monday', 0),
        ('Tuesday', 1),
        ('WEDNESDAY', 2),
        ('thursday', 3),
        ('Friday', 4),
        ('saturday', 5),
        ('sunday', 6),
        ('invalid_day', 0),
      ];

      for (final (dayStr, expectedIndex) in days) {
        final slot = TimetableSlotInfo(
          id: 'slot-1',
          subjectOfferingId: 'so-1',
          dayOfWeek: dayStr,
          startTime: '08:00',
          endTime: '09:00',
          sessionType: 'CI',
          subjectCode: 'MATH',
          subjectName: 'Mathématiques',
        );
        expect(slot.dayIndex, expectedIndex);
      }
    });
  });

  group('Payment Models & Calculations', () {
    test('PaymentPlanInfo calculates progressPercent properly', () {
      final plan = PaymentPlanInfo(
        planId: 'plan-1',
        planType: 'annual',
        amountTotal: 1000.0,
        currency: 'TND',
        payments: [],
        totalPaid: 250.0,
        remaining: 750.0,
      );

      expect(plan.progressPercent, 25.0);

      final zeroPlan = PaymentPlanInfo(
        planId: 'plan-zero',
        planType: 'annual',
        amountTotal: 0.0,
        currency: 'TND',
        payments: [],
        totalPaid: 0.0,
        remaining: 0.0,
      );

      expect(zeroPlan.progressPercent, 0.0);
    });

    test('PaymentInfo correctly maps status and display methods', () {
      final p1 = PaymentInfo(
        id: 'p-1',
        amount: 200,
        status: 'paid',
        method: 'cash',
      );
      expect(p1.isPaid, isTrue);
      expect(p1.isPending, isFalse);
      expect(p1.displayMethod, 'Espèces');

      final p2 = PaymentInfo(
        id: 'p-2',
        amount: 300,
        status: 'pending',
        method: 'bank_transfer',
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(p2.isPending, isTrue);
      expect(p2.isOverdue, isTrue);
      expect(p2.displayMethod, 'Virement bancaire');
    });
  });

  group('Grade Calculations (StudentResultsRepository)', () {
    final repo = StudentResultsRepository(
      SupabaseClient('https://mock.supabase.co', 'mock_anon_key'),
    );

    test('calculates weighted semester average accurately', () {
      final subjects = [
        SubjectGradesSummary(
          subjectOfferingId: 'so-1',
          subjectName: 'Math',
          coefficient: 4.0,
          weightsDisplay: '',
          components: [],
          average: 15.0, // 15 * 4 = 60
        ),
        SubjectGradesSummary(
          subjectOfferingId: 'so-2',
          subjectName: 'Physique',
          coefficient: 3.0,
          weightsDisplay: '',
          components: [],
          average: 12.0, // 12 * 3 = 36
        ),
        SubjectGradesSummary(
          subjectOfferingId: 'so-3',
          subjectName: 'Sport',
          coefficient: 1.0,
          weightsDisplay: '',
          components: [],
          average: 18.0, // 18 * 1 = 18
        ),
      ];
      // Total weighted: 114, Total coeff: 8 => 14.25
      final avg = repo.calculateSemesterAverage(subjects);
      expect(avg, closeTo(14.25, 0.001));
    });

    test('returns null if any subject average is missing or total coeff is zero', () {
      final empty = <SubjectGradesSummary>[];
      expect(repo.calculateSemesterAverage(empty), isNull);

      final uncalculated = [
        SubjectGradesSummary(
          subjectOfferingId: 'so-1',
          subjectName: 'Math',
          coefficient: 4.0,
          weightsDisplay: '',
          components: [],
          average: null,
        ),
      ];
      expect(repo.calculateSemesterAverage(uncalculated), isNull);
    });

    test('calculates Tunisian annual average formula', () {
      // 2 Semesters: (S1 + S2) / 2
      final twoSemesters = repo.calculateAnnualAverage(
        semester1Average: 14.0,
        semester2Average: 16.0,
      );
      expect(twoSemesters, 15.0);

      // 3 Trimesters: (T1 + T2 + 2*T3) / 4
      final threeTrimesters = repo.calculateAnnualAverage(
        semester1Average: 10.0,
        semester2Average: 12.0,
        semester3Average: 14.0, // 10 + 12 + 28 = 50 / 4 = 12.5
      );
      expect(threeTrimesters, 12.5);
    });
  });

  group('UserModel Serialization', () {
    test('parses json with timestamps and null dates safely', () {
      final json = {
        'id': 'usr-001',
        'email': 'user@pythaone.tn',
        'full_name': 'Karim Test',
        'role': 'student',
        'created_at': '2026-01-15T10:00:00.000Z',
        'updated_at': '2026-02-01T12:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'usr-001');
      expect(user.email, 'user@pythaone.tn');
      expect(user.fullName, 'Karim Test');
      expect(user.role, 'student');
      expect(user.dateOfBirth, isNull);

      final backToJson = user.toJson();
      expect(backToJson['id'], 'usr-001');
      expect(backToJson['email'], 'user@pythaone.tn');
    });
  });

  group('AppLocalizations Keys and Supported Locales', () {
    test('supportedLocales contains fr, ar, en', () {
      final codes = AppLocalizations.supportedLocales.map((l) => l.languageCode).toList();
      expect(codes, containsAll(['fr', 'ar', 'en']));
    });

    test('retrieves key strings across French, Arabic, and English', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      final l10nFr = AppLocalizations(const Locale('fr'));
      final l10nAr = AppLocalizations(const Locale('ar'));

      expect(l10nEn.translate('login'), 'Login');
      expect(l10nFr.translate('login'), 'Connexion');
      expect(l10nAr.translate('login'), contains('دخول'));

      expect(l10nEn.translate('absences'), isNotEmpty);
      expect(l10nFr.translate('absences'), isNotEmpty);
      expect(l10nAr.translate('absences'), isNotEmpty);
    });
  });
}
