import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:student_portal/core/l10n/app_localizations.dart';
import 'package:student_portal/presentation/providers/announcements_provider.dart';
import 'package:student_portal/presentation/screens/documents/documents_screen.dart';
import 'package:student_portal/data/models/document_model.dart';
import 'package:student_portal/data/services/core_data_service.dart';
import 'package:student_portal/presentation/providers/student_context_provider.dart';
import 'package:student_portal/presentation/widgets/bouncy_dropdown_selector.dart';
import 'package:student_portal/presentation/widgets/bubble_nav_bar.dart';
import 'package:student_portal/presentation/widgets/glass_card.dart';
import 'package:student_portal/presentation/widgets/ios_edge_swipe_back.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('DocumentsScreen dropdown opens directly below All types button', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Stub document that is visible to any student (no tags, school-wide)
    final stubDoc = DocumentModel(
      id: 'test-1',
      schoolId: 'school-1',
      classId: null,
      title: 'Test Document',
      description: 'A sample document',
      category: 'administrative',
      semester: null,
      fileUrl: 'https://example.com/file.pdf',
      fileName: 'file.pdf',
      fileSize: 1024,
      mimeType: 'application/pdf',
      uploadedBy: null,
      studentId: null,
      studentName: null,
      studentCode: null,
      createdAt: DateTime(2026, 1, 1),
    );

    final stubSemesters = [
      SemesterInfo(
        id: 's1',
        name: 'Semestre 1',
        number: 1,
        isCurrent: true,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2027, 1, 31),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allStudentDocumentsProvider.overrideWith((_) async => [stubDoc]),
          semestersProvider.overrideWith((_) async => stubSemesters),
          readDocumentsProvider.overrideWith((ref) => ReadDocumentsNotifier('test_user')),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: IosEdgeSwipeBack(
              onReturn: () {},
              child: const DocumentsScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final selectorFinder = find.byType(BouncyDropdownSelector<String>);
    expect(selectorFinder, findsOneWidget);
    final triggerRect = tester.getRect(selectorFinder);

    await tester.tap(selectorFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final listViewFinder = find.byType(ListView);
    final menuRect = tester.getRect(listViewFinder.last);

    // Dropdown should open cleanly ~6px directly below the trigger (menu ListView has 6px internal top padding)
    expect(menuRect.top - triggerRect.bottom, inInclusiveRange(4.0, 16.0));
    expect((menuRect.right - triggerRect.right).abs(), lessThan(5.0));

    // Close overlay cleanly before teardown
    BouncyDropdownSelector.closeAll();
    await tester.pump();
  });

  testWidgets('BubbleNavBar pill width is trimmed while keeping button centers unchanged', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classMessagesCountProvider.overrideWithValue(0),
          globalAnnouncementsCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: BubbleNavBar(currentIndex: 0),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final homeIcon = tester.getCenter(find.byIcon(Icons.home_rounded));
    final mailIcon = tester.getCenter(find.byIcon(Icons.mail_rounded));
    final notifIcon = tester.getCenter(find.byIcon(Icons.notifications_rounded));
    final aiIcon = tester.getCenter(find.byIcon(Icons.auto_awesome));
    final pillRect = tester.getRect(find.byType(BackdropFilter));

    expect(pillRect.width, lessThan(325.0));
    expect((homeIcon.dx + aiIcon.dx) / 2, closeTo(220.0, 0.5));
    expect((mailIcon.dx + notifIcon.dx) / 2, closeTo(220.0, 0.5));
  });

  testWidgets('GlassCard preserves proportional text scaling across screen sizes despite OS textScaler', (tester) async {
    Future<(double title, double subtitle, TextScaler scaler)> pumpAndMeasure(
        double width, double height, double osTextScale) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(osTextScale)),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: GlassCard(
                    icon: Icons.lightbulb_rounded,
                    label: 'Suggestions',
                    subtitle: 'Share your ideas',
                    gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    badgeCount: 2,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final titleEl = tester.element(find.text('Suggestions'));
      final titleWidget = titleEl.widget as Text;
      final subtitleWidget = tester.widget<Text>(find.text('Share your ideas'));
      final effectiveScaler = MediaQuery.textScalerOf(titleEl);
      return (titleWidget.style!.fontSize!, subtitleWidget.style!.fontSize!, effectiveScaler);
    }

    // Standard iPhone 16 Pro Max card width (189.0) -> exact 22.0 / 15.5 regardless of OS textScaler
    final res189 = await pumpAndMeasure(189.0, 205.0, 1.35);
    expect(res189.$1, closeTo(22.0, 0.01));
    expect(res189.$2, closeTo(15.5, 0.01));
    expect(res189.$3, TextScaler.noScaling);

    // Emulator 412dp card width (179.0) -> scaled proportionally
    final res179 = await pumpAndMeasure(179.0, 194.6, 1.0);
    expect(res179.$1, closeTo(22.0 * (179.0 / 189.0), 0.01));
    expect(res179.$2, closeTo(15.5 * (179.0 / 189.0), 0.01));

    // Infinix Smart 8 card width (159.0) -> scaled proportionally despite 1.2x OS font scale
    final res159 = await pumpAndMeasure(159.0, 187.1, 1.2);
    expect(res159.$1, closeTo(22.0 * (159.0 / 189.0), 0.01));
    expect(res159.$2, closeTo(15.5 * (159.0 / 189.0), 0.01));
    expect(res159.$3, TextScaler.noScaling);
  });

  testWidgets('GlassCard aligns Arabic title, subtitle, icon, and badge cleanly in RTL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 179.0,
                height: 194.6,
                child: GlassCard(
                  icon: Icons.lightbulb_rounded,
                  label: 'الاقتراحات',
                  subtitle: 'شارك أفكارك',
                  gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  badgeCount: 2,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cardRect = tester.getRect(find.byType(GlassCard));
    final iconRect = tester.getRect(find.byIcon(Icons.lightbulb_rounded));
    final titleRect = tester.getRect(find.text('الاقتراحات'));
    final subtitleRect = tester.getRect(find.text('شارك أفكارك'));
    final badgeRect = tester.getRect(find.text('2'));

    // Icon must sit in top-right (RTL start)
    expect(iconRect.center.dx, greaterThan(cardRect.center.dx));
    // Badge must sit in top-left (RTL end), opposite the icon
    expect(badgeRect.center.dx, lessThan(cardRect.center.dx));
    // Title and subtitle must both align on the right edge (within inner padding)
    expect(cardRect.right - titleRect.right, lessThan(22.0));
    expect((titleRect.right - subtitleRect.right).abs(), lessThan(4.0));
    // Subtitle sits cleanly below title without overlapping
    expect(subtitleRect.top, greaterThan(titleRect.bottom));
  });
}
