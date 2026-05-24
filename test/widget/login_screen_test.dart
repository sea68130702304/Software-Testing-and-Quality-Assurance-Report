import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okr_application_1/screens/login_screen.dart';
import 'package:okr_application_1/screens/register_screen.dart';

// Sets up a mock Firebase Core so screens that access FirebaseAuth.instance
// can be mounted without a real Firebase project or google-services.json.
void setupFirebase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
}

void main() {
  setUpAll(setupFirebase);

  setUp(() async {
    await Firebase.initializeApp();
  });

  // ── LoginScreen ───────────────────────────────────────────────────────────

  group('LoginScreen', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('renders Sign In and Create Account buttons', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Create Account'), findsOneWidget);
    });

    testWidgets('shows email error when submitted with empty email', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      // Leave fields empty and tap Sign In
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('shows password error when submitted with short password', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'user@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('shows both errors when both fields are invalid', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('no validation errors when fields are valid', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'user@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');

      // Do not tap submit — just verify no pre-existing errors
      await tester.pump();

      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('Minimum 6 characters'), findsNothing);
    });

    testWidgets('tapping Create Account navigates to RegisterScreen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  // ── RegisterScreen ────────────────────────────────────────────────────────

  group('RegisterScreen', () {
    testWidgets('renders all four input fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirm Password'), findsOneWidget);
    });

    testWidgets('shows name error when name is empty', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Enter your name'), findsOneWidget);
    });

    testWidgets('shows all errors when form is submitted empty', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('shows password mismatch error when passwords differ', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Alice');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'alice@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'different');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('no errors when all fields are valid and matching', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Alice');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'alice@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'password123');

      await tester.pump();

      expect(find.text('Enter your name'), findsNothing);
      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('Minimum 6 characters'), findsNothing);
      expect(find.text('Passwords do not match'), findsNothing);
    });

    testWidgets('back button returns to LoginScreen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Create Account'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
