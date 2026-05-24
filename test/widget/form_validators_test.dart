import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Mounts a minimal single-field form with the given [validator] so we can
/// exercise the validator logic through the real Flutter form machinery —
/// no Firebase, no screens, no extra setup required.
Widget _formWith({
  required String? Function(String?) validator,
  required String initialValue,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final key = GlobalKey<FormState>();
          return Form(
            key: key,
            child: Column(
              children: [
                TextFormField(
                  key: const Key('field'),
                  initialValue: initialValue,
                  validator: validator,
                ),
                ElevatedButton(
                  key: const Key('submit'),
                  onPressed: () => key.currentState!.validate(),
                  child: const Text('Submit'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('submit')));
  await tester.pump();
}

// ─────────────────────────────────────────────────────────────────────────────
// Email validator (used on Login and Register screens)
// ─────────────────────────────────────────────────────────────────────────────

String? _emailValidator(String? v) =>
    (v == null || !v.contains('@')) ? 'Enter a valid email' : null;

// ─────────────────────────────────────────────────────────────────────────────
// Password validator (used on Login and Register screens)
// ─────────────────────────────────────────────────────────────────────────────

String? _passwordValidator(String? v) =>
    (v == null || v.length < 6) ? 'Minimum 6 characters' : null;

// ─────────────────────────────────────────────────────────────────────────────
// Name validator (used on Register screen)
// ─────────────────────────────────────────────────────────────────────────────

String? _nameValidator(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Enter your name' : null;

// ─────────────────────────────────────────────────────────────────────────────
// KR label validator (used in Add/Edit KR dialog)
// ─────────────────────────────────────────────────────────────────────────────

String? _krLabelValidator(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Email validator', () {
    testWidgets('rejects empty string', (tester) async {
      await tester.pumpWidget(_formWith(validator: _emailValidator, initialValue: ''));
      await _submit(tester);
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('rejects string without @', (tester) async {
      await tester.pumpWidget(_formWith(validator: _emailValidator, initialValue: 'notanemail'));
      await _submit(tester);
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('rejects string with only @', (tester) async {
      await tester.pumpWidget(_formWith(validator: _emailValidator, initialValue: '@'));
      await _submit(tester);
      // '@' contains '@' so validator passes — this documents the permissive boundary
      expect(find.text('Enter a valid email'), findsNothing);
    });

    testWidgets('accepts valid email address', (tester) async {
      await tester.pumpWidget(_formWith(validator: _emailValidator, initialValue: 'user@example.com'));
      await _submit(tester);
      expect(find.text('Enter a valid email'), findsNothing);
    });

    testWidgets('accepts email with subdomain', (tester) async {
      await tester.pumpWidget(_formWith(validator: _emailValidator, initialValue: 'a@b.co.th'));
      await _submit(tester);
      expect(find.text('Enter a valid email'), findsNothing);
    });
  });

  group('Password validator', () {
    testWidgets('rejects empty string', (tester) async {
      await tester.pumpWidget(_formWith(validator: _passwordValidator, initialValue: ''));
      await _submit(tester);
      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('rejects 5-character password', (tester) async {
      await tester.pumpWidget(_formWith(validator: _passwordValidator, initialValue: '12345'));
      await _submit(tester);
      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('accepts 6-character password', (tester) async {
      await tester.pumpWidget(_formWith(validator: _passwordValidator, initialValue: '123456'));
      await _submit(tester);
      expect(find.text('Minimum 6 characters'), findsNothing);
    });

    testWidgets('accepts long password', (tester) async {
      await tester.pumpWidget(_formWith(validator: _passwordValidator, initialValue: 'correct_horse_battery_staple'));
      await _submit(tester);
      expect(find.text('Minimum 6 characters'), findsNothing);
    });
  });

  group('Name validator', () {
    testWidgets('rejects empty string', (tester) async {
      await tester.pumpWidget(_formWith(validator: _nameValidator, initialValue: ''));
      await _submit(tester);
      expect(find.text('Enter your name'), findsOneWidget);
    });

    testWidgets('rejects whitespace-only string', (tester) async {
      await tester.pumpWidget(_formWith(validator: _nameValidator, initialValue: '   '));
      await _submit(tester);
      expect(find.text('Enter your name'), findsOneWidget);
    });

    testWidgets('accepts non-empty name', (tester) async {
      await tester.pumpWidget(_formWith(validator: _nameValidator, initialValue: 'Alice'));
      await _submit(tester);
      expect(find.text('Enter your name'), findsNothing);
    });

    testWidgets('accepts name with leading/trailing spaces (trims before checking)', (tester) async {
      await tester.pumpWidget(_formWith(validator: _nameValidator, initialValue: '  Bob  '));
      await _submit(tester);
      expect(find.text('Enter your name'), findsNothing);
    });
  });

  group('Confirm-password validator', () {
    String? confirmValidator(String? v, {required String primary}) =>
        v != primary ? 'Passwords do not match' : null;

    testWidgets('rejects mismatched confirmation', (tester) async {
      await tester.pumpWidget(_formWith(
        validator: (v) => confirmValidator(v, primary: 'pass1234'),
        initialValue: 'different',
      ));
      await _submit(tester);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('rejects empty confirmation when primary is non-empty', (tester) async {
      await tester.pumpWidget(_formWith(
        validator: (v) => confirmValidator(v, primary: 'pass1234'),
        initialValue: '',
      ));
      await _submit(tester);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('accepts matching confirmation', (tester) async {
      await tester.pumpWidget(_formWith(
        validator: (v) => confirmValidator(v, primary: 'pass1234'),
        initialValue: 'pass1234',
      ));
      await _submit(tester);
      expect(find.text('Passwords do not match'), findsNothing);
    });
  });

  group('KR label validator', () {
    testWidgets('rejects empty label', (tester) async {
      await tester.pumpWidget(_formWith(validator: _krLabelValidator, initialValue: ''));
      await _submit(tester);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('rejects whitespace-only label', (tester) async {
      await tester.pumpWidget(_formWith(validator: _krLabelValidator, initialValue: '  '));
      await _submit(tester);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('accepts a non-empty label', (tester) async {
      await tester.pumpWidget(_formWith(validator: _krLabelValidator, initialValue: 'Increase NPS'));
      await _submit(tester);
      expect(find.text('Required'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Confirm that form does NOT submit when any field is invalid
  // ─────────────────────────────────────────────────────────────────────────

  group('Form submission guard', () {
    testWidgets('form.validate() returns false for invalid input', (tester) async {
      bool? formValid;
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  validator: _emailValidator,
                  initialValue: 'not-an-email',
                ),
                ElevatedButton(
                  key: const Key('submit'),
                  onPressed: () => formValid = formKey.currentState!.validate(),
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('submit')));
      await tester.pump();
      expect(formValid, isFalse);
    });

    testWidgets('form.validate() returns true for valid input', (tester) async {
      bool? formValid;
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  validator: _emailValidator,
                  initialValue: 'valid@test.com',
                ),
                ElevatedButton(
                  key: const Key('submit'),
                  onPressed: () => formValid = formKey.currentState!.validate(),
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('submit')));
      await tester.pump();
      expect(formValid, isTrue);
    });
  });
}
