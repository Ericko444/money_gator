# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

**money_gator** is an Android "spending gatekeeper" app. It uses an Android Accessibility Service to intercept when the user opens tracked social media apps (Facebook, Messenger, Instagram). If the user hasn't logged a spending entry or done a "no spend" check-in within the past 2 hours, the app launches a blocking screen that forces them to log before continuing.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build Android APK
flutter build apk --release

# Re-generate Isar schema code (required after any changes to transaction.dart)
dart run build_runner build

# Static analysis / linting
flutter analyze

# Run tests
flutter test
```

## Architecture

### Flutter Layer (`lib/`)

- **`main.dart`** — App entry point and `GatekeeperScreen` (the keypad). Initializes Isar at startup, requests storage permissions (Android 11+ uses `MANAGE_EXTERNAL_STORAGE`). The database lives at `/storage/emulated/0/Documents/MoneyGate` (survives app uninstall). Declares a global `late Isar isar` accessed directly by all screens.

- **`history_screen.dart`** — Transaction list. Uses `StreamBuilder` on the Isar `watch()` stream for live updates. Tap a row to edit or delete via a dialog.

- **`dashboard_screen.dart`** — Statistics view using `fl_chart`. Shows monthly total, today's total (color-coded green/orange/red by amount), a pie chart by category, and a 7-day bar chart. Refreshes on demand via a button since it uses `FutureBuilder`, not a stream.

- **`services/dashboard_service.dart`** — Aggregation logic. Isar doesn't support `groupBy`, so monthly transactions are fetched in full and grouped manually in Dart for the category breakdown.

- **`collections/transaction.dart`** — Isar collection schema. Fields: `amount`, `category`, `timestamp` (indexed), `hourOfDay`, `dayOfWeek`. `transaction.g.dart` is generated code — never edit it manually.

### Android Native Layer (`android/`)

- **`MainActivity.kt`** — Exposes a `MethodChannel` (`com.example.money_gator/app_control`) with one method: `closeApp`, which calls `moveTaskToBack(true)` to reveal the underlying app without killing Flutter.

- **`AppDetectorService.kt`** — Android `AccessibilityService`. Listens for `TYPE_WINDOW_STATE_CHANGED` events. When the user switches to a tracked app (Facebook, Messenger, Instagram), it reads `flutter.last_paid_timestamp` from `FlutterSharedPreferences` and either allows use for the remaining session time or immediately launches `MainActivity` to block.

### Key Design Decisions

- **Global Isar instance**: `isar` is a package-level variable in `main.dart`. All screens import `main.dart` to access it directly — there's no dependency injection.
- **Session timer**: `SESSION_LIMIT_MS = 7_200_000L` (2 hours). The comment in the file saying "15 Seconds" is stale.
- **SharedPreferences key**: The Accessibility Service reads the key as `flutter.last_paid_timestamp` (Flutter adds the `flutter.` prefix automatically).
- **`moveTaskToBack` instead of `finish()`**: Closing the gatekeeper reveals whatever app is beneath it in the task stack rather than returning to the launcher.

## Schema Changes

Any change to `lib/collections/transaction.dart` requires regenerating `transaction.g.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```
