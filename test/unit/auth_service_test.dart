import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okr_application_1/services/auth_service.dart';

// ── Throwing fakes ────────────────────────────────────────────────────────────

class _WrongPasswordAuth extends Fake implements FirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      throw FirebaseAuthException(code: 'wrong-password');

  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

class _EmailInUseAuth extends Fake implements FirebaseAuth {
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      throw FirebaseAuthException(code: 'email-already-in-use');

  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

void main() {
  group('AuthService', () {
    late MockFirebaseAuth mockAuth;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(auth: mockAuth);
    });

    // ── Sign-up ─────────────────────────────────────────────────────────────

    group('signUp', () {
      test('returns a UserCredential on success', () async {
        final result = await authService.signUp('new@test.com', 'password123');
        expect(result, isNotNull);
        expect(result.user, isNotNull);
      });

      test('newly created user email matches the supplied email', () async {
        final result = await authService.signUp('alice@test.com', 'pass1234');
        expect(result.user?.email, 'alice@test.com');
      });

      test('currentUser is set after sign-up', () async {
        await authService.signUp('bob@test.com', 'pass1234');
        expect(authService.currentUser, isNotNull);
      });
    });

    // ── Sign-in ─────────────────────────────────────────────────────────────

    group('signIn', () {
      test('returns a UserCredential when credentials are accepted', () async {
        final result = await authService.signIn('user@test.com', 'password123');
        expect(result, isNotNull);
      });

      test('currentUser is not null after sign-in', () async {
        await authService.signIn('user@test.com', 'password123');
        expect(authService.currentUser, isNotNull);
      });
    });

    // ── Sign-out ─────────────────────────────────────────────────────────────

    group('signOut', () {
      test('clears currentUser after sign-out', () async {
        final signedInAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid123', email: 'active@test.com'),
        );
        final service = AuthService(auth: signedInAuth);

        expect(service.currentUser, isNotNull);
        await service.signOut();
        expect(service.currentUser, isNull);
      });

      test('currentUser is null after sign-out', () async {
        final signedInAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid123'),
        );
        final service = AuthService(auth: signedInAuth);
        await service.signOut();
        expect(service.currentUser, isNull);
      });
    });

    // ── Initial state ────────────────────────────────────────────────────────

    group('initial state (not signed in)', () {
      test('currentUser is null', () {
        expect(authService.currentUser, isNull);
      });

      test('authStateChanges emits null', () async {
        await expectLater(
          authService.authStateChanges.first,
          completion(isNull),
        );
      });
    });

    // ── Pre-authenticated state ──────────────────────────────────────────────

    group('pre-authenticated state', () {
      test('currentUser is not null when MockFirebaseAuth starts signed in', () {
        final preAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid999', email: 'pre@test.com'),
        );
        final service = AuthService(auth: preAuth);

        expect(service.currentUser, isNotNull);
        expect(service.currentUser?.email, 'pre@test.com');
      });

      test('authStateChanges emits the signed-in user', () async {
        final preAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid999', email: 'pre@test.com'),
        );
        final service = AuthService(auth: preAuth);

        await expectLater(
          service.authStateChanges.first,
          completion(isNotNull),
        );
      });
    });

    // ── Error cases ───────────────────────────────────────────────────────────

    group('signIn error cases', () {
      test('throws FirebaseAuthException with wrong-password code', () async {
        final service = AuthService(auth: _WrongPasswordAuth());
        await expectLater(
          service.signIn('user@test.com', 'wrongpass'),
          throwsA(
            isA<FirebaseAuthException>()
                .having((e) => e.code, 'code', 'wrong-password'),
          ),
        );
      });
    });

    group('signUp error cases', () {
      test('throws FirebaseAuthException with email-already-in-use code', () async {
        final service = AuthService(auth: _EmailInUseAuth());
        await expectLater(
          service.signUp('existing@test.com', 'password123'),
          throwsA(
            isA<FirebaseAuthException>()
                .having((e) => e.code, 'code', 'email-already-in-use'),
          ),
        );
      });
    });
  });
}
