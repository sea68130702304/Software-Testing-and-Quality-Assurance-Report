// Integration tests – Radical OKR app
//
// Prerequisites (already done before running):
//   firebase emulators:start --only auth,firestore --project okr-app-e5b16
//
// Run on Android:
//   flutter test integration_test/app_test.dart -d emulator-5554
//
// Run on Web (Chrome):
//   flutter test integration_test/app_test.dart -d chrome

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:okr_application_1/firebase_options.dart';
import 'package:okr_application_1/main.dart' show OKRApp, themeModeNotifier;

// ── Emulator host ─────────────────────────────────────────────────────────────
// Android emulator reaches the host machine via 10.0.2.2.
// Web (Chrome) and other targets use localhost directly.
String get _emulatorHost {
  if (kIsWeb) return 'localhost';
  return Platform.isAndroid ? '10.0.2.2' : 'localhost';
}

// ── Unique e-mail per test run ────────────────────────────────────────────────
// Using a timestamp suffix avoids "email-already-in-use" when tests are re-run
// without resetting the emulator between runs.
String _email(String tag) =>
    'test_${tag}_${DateTime.now().millisecondsSinceEpoch}@example.com';

const _password = 'Test1234!';

// ── One-time setup ────────────────────────────────────────────────────────────

bool _firebaseReady = false;

Future<void> _ensureFirebase() async {
  if (_firebaseReady) return;
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance
      .useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance
      .useFirestoreEmulator(_emulatorHost, 8080);
  _firebaseReady = true;
}

// ── Helper: pump the full app ─────────────────────────────────────────────────
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ValueListenableBuilder(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => const OKRApp(),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 4));
}

// ── Helper: sign out between tests ───────────────────────────────────────────
Future<void> signOutIfNeeded() async {
  if (FirebaseAuth.instance.currentUser != null) {
    await FirebaseAuth.instance.signOut();
  }
}

// =============================================================================
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _ensureFirebase();
  });

  setUp(() async {
    await signOutIfNeeded();
  });

  // ── 1. Full registration flow ─────────────────────────────────────────────

  testWidgets('1 — registration: fills form and lands on dashboard',
      (tester) async {
    final email = _email('reg');

    await pumpApp(tester);
    expect(find.text('Radical OKR'), findsOneWidget);

    // Go to RegisterScreen.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create Account'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'), 'Test User');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), _password);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'), _password);

    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('OKR Radical Dashboard'), findsOneWidget);
  });

  // ── 2. Login with existing credentials ───────────────────────────────────

  testWidgets('2 — login: existing account signs in and shows dashboard',
      (tester) async {
    final email = _email('login');

    // Create account first via the Auth emulator API.
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: _password);
    await signOutIfNeeded();

    await pumpApp(tester);
    expect(find.text('Radical OKR'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), _password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('OKR Radical Dashboard'), findsOneWidget);
  });

  // ── 3. Dashboard save and reload ─────────────────────────────────────────

  testWidgets('3 — dashboard: typed objective appears after save',
      (tester) async {
    final email = _email('obj');
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: _password);

    await pumpApp(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('OKR Radical Dashboard'), findsOneWidget);

    // Tap the edit objective icon (tooltip distinguishes it from Priorities/Projects edit icons).
    await tester.tap(find.byTooltip('Edit objective'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Objective'), 'Ship v2.0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ship v2.0'), findsOneWidget);
  });

  // ── 4. KR score update ───────────────────────────────────────────────────

  testWidgets('4 — dashboard: adding a KR shows it in the OKR card',
      (tester) async {
    final email = _email('kr');
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: _password);

    await pumpApp(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Add KR'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'KR Label'), 'Revenue 100k');

    // Drag the slider to a non-zero score.
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Revenue 100k'), findsOneWidget);
  });

  // ── 5. Task creation and completion ──────────────────────────────────────

  testWidgets('5 — KR detail: task created and completed shows Done chip',
      (tester) async {
    final email = _email('task');
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: _password);

    await pumpApp(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Add a KR.
    await tester.tap(find.text('Add KR'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'KR Label'), 'Launch feature');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Open KR detail.
    await tester.tap(find.textContaining('Launch feature'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Add a task.
    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Task title'), 'Write tests');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Write tests'), findsOneWidget);

    // Drag task slider to 100 %.
    // Web mouse-drag semantics need a larger offset than Android touch drag.
    const sliderDragOffset = kIsWeb ? Offset(2000, 0) : Offset(500, 0);
    await tester.drag(find.byType(Slider).last, sliderDragOffset);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Done'), findsOneWidget);
  });

  // ── 6. Sign-out flow ─────────────────────────────────────────────────────

  testWidgets('6 — sign-out: confirms dialog then returns to login screen',
      (tester) async {
    final email = _email('signout');
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: _password);

    await pumpApp(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap the CircleAvatar to open Profile.
    await tester.tap(find.byType(CircleAvatar).first);
    await tester.pumpAndSettle();

    // Scroll to and tap Sign Out.
    await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
    await tester.pumpAndSettle();

    // Confirm in dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('Radical OKR'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });
}
