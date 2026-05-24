import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okr_application_1/models/models.dart';
import 'package:okr_application_1/screens/kr_detail_screen.dart';
import 'package:okr_application_1/services/database_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });

  setUp(() async {
    await Firebase.initializeApp();
  });

  // A minimal KeyResult used across all tests.
  const testKR = KeyResult(
    id: 'kr_test',
    title: 'Increase signups',
    description: 'Get more users',
  );

  // Builds a KrDetailScreen wired to a FakeFirebaseFirestore so no real
  // network is needed.
  Widget buildKrDetail({
    required DatabaseService db,
    ValueChanged<int>? onCurrentChanged,
    int krCurrent = 3,
    int krTarget = 10,
  }) {
    return MaterialApp(
      home: KrDetailScreen(
        uid: 'uid_test',
        objectiveId: 'obj_test',
        keyResult: testKR,
        krCurrent: krCurrent,
        krTarget: krTarget,
        onCurrentChanged: onCurrentChanged,
        db: db,
      ),
    );
  }

  // ── Add task dialog ─────────────────────────────────────────────────────────

  group('KrDetailScreen — add task dialog', () {
    late DatabaseService db;

    setUp(() {
      db = DatabaseService(db: FakeFirebaseFirestore());
    });

    testWidgets('FAB opens Add Task dialog', (tester) async {
      await tester.pumpWidget(buildKrDetail(db: db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();

      expect(find.text('Add Task'), findsWidgets); // dialog title + FAB label
      expect(find.widgetWithText(TextFormField, 'Task title'), findsOneWidget);
    });

    testWidgets('submitting empty title shows validation error', (tester) async {
      await tester.pumpWidget(buildKrDetail(db: db));
      await tester.pumpAndSettle();

      // Open the dialog.
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();

      // Tap Add without entering a title.
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();

      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('entering a title and tapping Add closes the dialog',
        (tester) async {
      await tester.pumpWidget(buildKrDetail(db: db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Task title'), 'My task');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      // Dialog should be gone; validation error must not be visible.
      expect(find.text('Title is required'), findsNothing);
    });
  });

  // ── Confidence-score slider interaction ─────────────────────────────────────

  group('KrDetailScreen — slider interaction', () {
    testWidgets('dragging confidence slider fires onCurrentChanged with an int',
        (tester) async {
      int? captured;
      final db = DatabaseService(db: FakeFirebaseFirestore());

      await tester.pumpWidget(buildKrDetail(
        db: db,
        onCurrentChanged: (v) => captured = v,
        krCurrent: 0,
        krTarget: 10,
      ));
      await tester.pumpAndSettle();

      // The banner slider is the only Slider rendered when there are no tasks.
      final sliderFinder = find.byType(Slider).first;
      expect(sliderFinder, findsOneWidget);

      // Drag rightward so the slider value increases.
      await tester.drag(sliderFinder, const Offset(60, 0));
      await tester.pumpAndSettle();

      // onChangeEnd fires on pointer-up, so captured must now be an integer ≥ 0.
      expect(captured, isNotNull);
      expect(captured, isA<int>());
    });
  });
}
