# Radical OKR — Mobile Application

A cross-platform Flutter application for personal and small-team OKR (Objectives and Key Results) tracking, backed by Firebase Authentication and Cloud Firestore.

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Flutter SDK | ≥ 3.x | Build and run the app |
| Dart SDK | ≥ 3.x | Included with Flutter |
| Firebase CLI | latest | Start local emulators |
| Android Emulator | API 33+ | Integration tests on Android |
| Google Chrome | any | Run app and tests on Web |
| ChromeDriver | must match Chrome | Web integration tests via `flutter drive` |
| Node.js | ≥ 16 | Required by Firebase CLI |

Install Firebase CLI:
```bash
npm install -g firebase-tools
```

## Getting Started

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Run on Android

```bash
flutter run -d emulator-5554
```

### 3. Run on Web (Chrome)

```bash
flutter run -d chrome
```

---

## Running Tests

### Unit & Widget Tests

No device or emulator required. Runs entirely on the host machine.

```bash
flutter test test/
```

Expected output:
```
+81: All tests passed!
```

| Layer | Files | Cases |
|---|---|---|
| Unit | 2 | 36 |
| Widget | 5 | 45 |
| **Total** | **7** | **81** |

---

### Integration Tests (Android Emulator)

Integration tests require Firebase emulators running locally before starting.

**Step 1 — Start Firebase emulators:**

```bash
firebase emulators:start --only auth,firestore --project okr-app-e5b16
```

Wait until the terminal confirms both services are ready:
- Auth emulator: `localhost:9099`
- Firestore emulator: `localhost:8080`

**Step 2 — Run integration tests on Android:**

```bash
flutter test integration_test/app_test.dart -d emulator-5554
```

Expected output:
```
+6: All tests passed!
```

> The Android emulator reaches the host machine via `10.0.2.2`. Cleartext HTTP is permitted in the debug `AndroidManifest.xml` for this connection.

---

### Integration Tests (Web — Chrome)

**Step 1 — Start Firebase emulators** (same as above, skip if already running):

```bash
firebase emulators:start --only auth,firestore --project okr-app-e5b16
```

**Step 2 — Start ChromeDriver** (open a separate terminal):

ChromeDriver version must match your installed Chrome version.

```bash
chromedriver --port=4444
```

**Step 3 — Run integration tests on Chrome:**

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d chrome
```

Expected output:
```
+8: All tests passed!
```

> The `+8` count includes `setUpAll` and `tearDownAll` in addition to the 6 test cases.

---

## Test Summary

| Layer | Files | Cases | Android | Web (Chrome) |
|---|---|---|---|---|
| Unit | 2 | 36 | PASS (Dart VM) | PASS (Dart VM) |
| Widget | 5 | 45 | PASS (Dart VM) | PASS (Dart VM) |
| Integration | 1 | 6 | PASS | PASS |
| **Total** | **8** | **87** | **All passed** | **All passed** |

---

## Project Structure

```
lib/
  main.dart                    # App entry point, theme setup, root StreamBuilder
  firebase_options.dart        # FlutterFire auto-generated config
  models/
    models.dart                # Task, KeyResult, Objective data models
  services/
    auth_service.dart          # Firebase Auth wrapper (signIn, signUp, signOut)
    database_service.dart      # Firestore read/write operations
  screens/
    login_screen.dart          # Login entry point
    register_screen.dart       # Account creation form
    dashboard_screen.dart      # Main OKR dashboard (four editable cards)
    kr_detail_screen.dart      # Key Result detail with real-time task list
    profile_screen.dart        # User profile, theme switcher, sign-out

test/
  unit/
    auth_service_test.dart     # AuthService unit tests (13 cases)
    models_test.dart           # Data model serialisation tests (23 cases)
  widget/
    login_screen_test.dart     # LoginScreen & RegisterScreen widget tests (13 cases)
    dashboard_screen_test.dart # DashboardScreen widget tests (5 cases)
    kr_detail_screen_test.dart # KrDetailScreen widget tests (4 cases)
    profile_screen_test.dart   # ProfileScreen widget tests (2 cases)
    form_validators_test.dart  # Standalone validator tests (21 cases)

integration_test/
  app_test.dart                # End-to-end integration tests (6 flows)

test_driver/
  integration_test.dart        # flutter drive entry point (required for Web)
```

---

## Firebase Configuration

The app connects to Firebase project `okr-app-e5b16`. Options are pre-configured in `lib/firebase_options.dart` via FlutterFire CLI.

**Emulator ports used during testing:**

| Service | Port | Android address | Web/Desktop address |
|---|---|---|---|
| Auth | 9099 | `10.0.2.2:9099` | `localhost:9099` |
| Firestore | 8080 | `10.0.2.2:8080` | `localhost:8080` |
