import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:okr_application_1/screens/profile_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });

  setUp(() async {
    await Firebase.initializeApp();
    // Provide empty SharedPreferences so _loadName() succeeds synchronously.
    SharedPreferences.setMockInitialValues({});
  });

  // ── Sign-out dialog ─────────────────────────────────────────────────────────

  group('ProfileScreen — sign-out dialog', () {
    testWidgets('tapping Sign Out button shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      // The button may be below the fold — scroll it into view first.
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
    });

    testWidgets('tapping Cancel dismisses the dialog without navigating away',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      // Dialog is visible.
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed; ProfileScreen is still on screen.
      expect(find.text('Are you sure you want to sign out?'), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
