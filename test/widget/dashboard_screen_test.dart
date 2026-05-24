import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:okr_application_1/screens/dashboard_screen.dart';
import 'package:okr_application_1/screens/kr_detail_screen.dart';
import 'package:okr_application_1/services/database_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });

  setUp(() async {
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
  });

  // Helper: build a DashboardScreen wired to a given DatabaseService and auth.
  Widget buildDashboard({
    required DatabaseService db,
    MockFirebaseAuth? auth,
  }) {
    return MaterialApp(
      home: DashboardScreen(db: db, auth: auth),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────

  group('DashboardScreen — empty state', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseService db;
    late MockFirebaseAuth auth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      db = DatabaseService(db: fakeFirestore);
      auth = MockFirebaseAuth(); // not signed in → uid falls back to 'guest'
    });

    testWidgets('shows No priorities yet when priorities list is empty',
        (tester) async {
      await tester.pumpWidget(buildDashboard(db: db, auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('No priorities yet'), findsOneWidget);
    });

    testWidgets('shows No projects yet when projects list is empty',
        (tester) async {
      await tester.pumpWidget(buildDashboard(db: db, auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('shows No key results yet when key results list is empty',
        (tester) async {
      await tester.pumpWidget(buildDashboard(db: db, auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('No key results yet'), findsOneWidget);
    });

    testWidgets('shows No health items yet when health list is empty',
        (tester) async {
      await tester.pumpWidget(buildDashboard(db: db, auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('No health items yet'), findsOneWidget);
    });
  });

  // ── KR row tap → navigates to KrDetailScreen ───────────────────────────────

  group('DashboardScreen — KR row tap', () {
    testWidgets('tapping a KR row navigates to KrDetailScreen', (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid_test', email: 'user@test.com'),
      );

      // Pre-populate dashboard data for this user.
      await fakeFirestore
          .collection('users')
          .doc('uid_test')
          .collection('data')
          .doc('dashboard')
          .set({
        'objective': 'Grow revenue',
        'priorities': <String>[],
        'keyResults': [
          {'label': 'Sample KR', 'current': 3, 'target': 10}
        ],
        'projects': <String>[],
        'health': <Map<String, dynamic>>[],
      });

      // Also create the tasks collection so KrDetailScreen stream works.
      await fakeFirestore
          .collection('users')
          .doc('uid_test')
          .collection('objectives')
          .doc('demo_objective')
          .collection('keyResults')
          .doc('sample_kr')
          .collection('tasks')
          .add({
        'keyResultId': 'sample_kr',
        'title': 'Seed task',
        'completionPercentage': 0,
        'status': 'todo',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'dueDate': null,
      });

      final db = DatabaseService(db: fakeFirestore);
      await tester.pumpWidget(buildDashboard(db: db, auth: auth));
      await tester.pumpAndSettle();

      // The KR row text starts with "KR: ".
      expect(find.textContaining('Sample KR'), findsOneWidget);

      await tester.tap(find.textContaining('Sample KR'));
      // Use pump() rather than pumpAndSettle(): KrDetailScreen's StreamBuilder
      // shows a CircularProgressIndicator while waiting for the first Firestore
      // event, which continuously schedules frames and would cause pumpAndSettle
      // to time out.
      await tester.pump();           // kick off navigation
      await tester.pump();           // complete the push

      expect(find.byType(KrDetailScreen), findsOneWidget);
    });
  });
}
