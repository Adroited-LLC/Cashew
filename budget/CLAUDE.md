# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cashew is a Flutter/Dart personal finance and budget tracking app. It targets Android, iOS, and Web. The app uses Drift (SQLite ORM) for local data, Firebase Auth for accounts, Google Drive for cross-device sync, and `easy_localization` for i18n.

## Commands

```bash
# Run the app
flutter run

# Build
flutter build apk
flutter build ios
flutter build web

# Analyze / lint
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Regenerate Drift database code (after changing tables.dart)
dart run build_runner build

# Dump Drift schema (after bumping schema version, before committing)
dart run drift_dev schema dump lib/database/tables.dart drift_schemas/
```

## Architecture

### Directory Structure

- `lib/main.dart` — App entry point; initializes Firebase, Drift DB, notifications, settings, and localization
- `lib/colors.dart` — Theme color system using `AppColors` extension on `ThemeData`; use `getColor(context, "colorName")` to access theme colors
- `lib/functions.dart` — Shared utility functions and Dart extensions
- `lib/pages/` — Full-screen pages (one file per screen)
- `lib/pages/homePage/` — Home screen split into per-widget files
- `lib/widgets/` — Reusable UI components
- `lib/widgets/framework/` — Core layout wrappers (`PageFramework`, `PopupFramework`)
- `lib/widgets/transactionEntry/` — Transaction list item components
- `lib/widgets/util/` — Low-level utilities (debouncer, app links, etc.)
- `lib/struct/` — Global app state and services
- `lib/database/` — Drift schema, migrations, and generated code
- `lib/database/platform/` — Platform-conditional DB initialization (native/web/unsupported)
- `lib/modified/` — Modified third-party code
- `packages/` — Local package overrides (`sliding_sheet`, `implicitly_animated_reorderable_list`)
- `drift_schemas/` — Drift schema JSON snapshots for each schema version
- `assets/translations/generated/` — Localization JSON files

### Global State

Key globals defined in `lib/struct/databaseGlobal.dart` and initialized in `main.dart`:

- `database` — The `FinanceDatabase` Drift instance (type: `FinanceDatabase`)
- `sharedPreferences` — SharedPreferences instance
- `clientID` — Unique device identifier used for sync file naming
- `appStateSettings` — `Map<String, dynamic>` holding all user settings, loaded from SharedPreferences via `initializeSettings()` in `lib/struct/settings.dart`

### Database (Drift)

- Schema defined in `lib/database/tables.dart`; generated code is `tables.g.dart`
- Current schema version: `schemaVersionGlobal` (int at top of `tables.dart`)
- Migrations live in `migrationSteps(...)` inside the `FinanceDatabase` class

**To add a database migration:**
1. Make schema changes in `tables.dart`
2. Increment `schemaVersionGlobal`
3. Add a migration step in `migrationSteps`
4. Run `dart run build_runner build` to regenerate `tables.g.dart`
5. Run `dart run drift_dev schema dump lib/database/tables.dart drift_schemas/` to save a schema snapshot

### UI Patterns

- All full-screen pages wrap content in `PageFramework` (`lib/widgets/framework/pageFramework.dart`)
- Bottom sheets and modal dialogs use `PopupFramework` (`lib/widgets/framework/popupFramework.dart`)
- Access theme colors via `getColor(context, "colorName")` — never hardcode colors
- Localization strings: use `.tr()` extension from `easy_localization` on string keys

### Sync

`lib/struct/syncClient.dart` handles Google Drive-based multi-device sync. Each device uploads a file named `sync-{clientID}.sqlite` to Google Drive. Firebase is used only for authentication (Google Sign-In); Firestore is used for shared budgets.

### SimpleFIN Bank Sync

Located in `lib/simplefin/`. Adds read-only bank sync via the SimpleFIN Bridge protocol.

**Flow**: User pastes a one-time Setup Token → `SimplefinClient.exchangeSetupToken()` POSTs to the claim URL and returns a permanent Access URL → stored in `flutter_secure_storage` → daily `GET {accessUrl}/accounts` with Basic Auth fetches transactions as JSON.

Key files:
- `lib/simplefin/simplefin_client.dart` — HTTP client (token exchange + account fetch)
- `lib/simplefin/simplefin_storage.dart` — secure storage (Access URL) + SharedPreferences (account mappings, last sync time, default category)
- `lib/simplefin/simplefin_service.dart` — sync orchestration; calls `database.createOrUpdateTransaction()` with `transactionPk: 'sf-{simplefinId}'` for natural deduplication via `insertOrReplace`
- `lib/pages/simpleFinSyncPage.dart` — settings UI (connect, account→wallet mapping, manual sync)

**Deduplication**: SimpleFIN transaction IDs are prefixed with `sf-` and used as `transactionPk`. Calling `createOrUpdateTransaction` with the same `transactionPk` (default `insert: false`) is idempotent via Drift's `insertOrReplace`.

**Background sync**: Triggered from the `OnAppResume` callback in `main.dart` if `SimplefinService.shouldAutoSync()` (≥24h since last sync and mappings configured). Silent — no UI shown.

**Linux dependency**: `flutter_secure_storage` on Linux requires `libsecret` (`sudo dnf install libsecret-devel` on Fedora).

### Settings

`appStateSettings` is the central settings map. Default values and keys are in `lib/struct/defaultPreferences.dart`. To read a setting: `appStateSettings["keyName"]`. To persist a change, use `updateSettings("keyName", value)` from `lib/struct/settings.dart`.
