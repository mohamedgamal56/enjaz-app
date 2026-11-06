# Architecture & Design Decisions (قرارات التصميم والمعمارية)

## Decision 1: Architecture Pattern & Tech Stack
- **Context**: The application is an offline-first, single-user task and goal tracking Android app designed for honest personal tracking and feedback.
- **Decision**: 
  - State Management: Riverpod (`flutter_riverpod`) for reactive state and dependency injection.
  - Local Database: SQLite via Drift with versioned migrations and audit columns (`created_at`, `updated_at`, `deleted_at`).
  - Navigation: Material 3 Navigation Shell with 4 main tabs (`Today`, `Goals`, `Ideas`, `Stats`).
  - Localization: `flutter_localizations` with ARB files (`app_ar.arb`, `app_en.arb`) and custom typed delegator to guarantee compile-time safety and runtime live language switching.

## Decision 2: Theme System & Tokens
- **Context**: Spec Section 3 defines strict tokens for light and dark modes with 1 px borders and zero shadows.
- **Decision**: 
  - Centralized all color tokens in `AppColors` exactly matching the spec table:
    - Light Background `#FAFAF9`, Surface `#FFFFFF`, Accent Teal `#0D9488`.
    - Dark Background `#0F1412`, Surface `#1A1F1E`, Accent Teal `#2DD4BF`.
  - Defined status colors for all 7 states (`todo`, `in_progress`, `partial`, `done`, `postponed`, `waiting`, `stopped`).
  - Applied Material 3 with 16 dp card radius, 24 dp bottom sheet top radius, and fully rounded chips.

## Decision 3: Typography & Fonts
- **Context**: Cairo font for Arabic, Inter font for English, bundled as assets.
- **Decision**: 
  - Downloaded official variable TTF fonts `Cairo.ttf` and `Inter.ttf` into `assets/fonts/`.
  - Configured in `pubspec.yaml` and implemented dynamically in `AppTypography` based on the active locale.

## Decision 4: Drift Schema & Seed Data
- **Context**: Spec Section 4 requires 11 tables with specific columns, foreign keys, indexes, and initial reasons.
- **Decision**: 
  - Created full Drift schema covering: `Tasks`, `TaskEvents`, `Reasons`, `Goals`, `Milestones`, `GoalUpdates`, `Ideas`, `Tags`, `IdeaTags`, `Recurrences`, and `Settings`.
  - Implemented indexes on: `tasks.status`, `tasks.due_date`, `tasks.deleted_at`, `tasks.goal_id`, `task_events.at`, and `task_events.task_id`.
  - Seeded 10 default reasons in Arabic and English inside the database creation migration.

## Decision 5: Non-programmer CI/CD Pipeline
- **Context**: The app owner does not have a local Flutter SDK on their Windows machine and uses a Redmi 12 smartphone.
- **Decision**:
  - Provided a GitHub Actions workflow (`.github/workflows/build_apk.yml`) that triggers on push or manual trigger, sets up Flutter, generates Drift code, runs unit tests, builds the Android APK, and uploads it as an artifact.
  - Also provided a live local Web preview server running on port 8080 accessible across the local network (`http://192.168.100.11:8080`) for instant zero-setup testing.

## Decision 6: Phase 1 Tasks Core & Status Transition Engine
- **Context**: Spec Section 5 mandates strict status transition rules, append-only history tracking in `task_events`, undo mechanisms, and reasons tracking.
- **Decision**:
  - Created a pure Dart business service `TaskStatusService` to compute state transitions without UI coupling, verified by unit tests in `test/unit/task_status_service_test.dart`.
  - Status changes write atomic transactions in Drift: updating `tasks`, logging `task_events`, and incrementing reason usage counts.
  - Quick checkbox on task card marks done immediately with an 8-second SnackBar with Undo action.
  - Long press opens the comprehensive `StatusSheet` supporting the 7 statuses, reason chips, partial slider (1-99%), postpone date picker, and confirm button.

## Decision 7: Phase 2 Organization, History Search & Soft-Delete Trash Management
- **Context**: Spec Section 6.1, 6.2, 6.5, and 6.10 require organized task sections, undated inbox, multi-line notes paste import, full history search, and reason management.
- **Decision**:
  - Implemented multi-line note parsing: both automated on paste and via explicit import action, utilizing Drift's batch insert transaction for maximum SQLite write throughput.
  - History screen leverages Drift reactive streaming with SQL `LIKE` queries across title, notes, and reasonText, coupled with dynamic status and kind filters.
  - Reason management respects the strict audit rule: reasons can be archived or edited, but never hard deleted if attached to historical events.
  - Soft-delete trash management provides safe recovery and optional permanent purge.

## Decision 8: Phase 3 Goals, Milestones & Dual Progress Tracking
- **Context**: Spec Section 4, 6.6, and 6.7 define Life Goals with two distinct tracking modes: Milestones (weighted steps) and Numeric targets (current vs target with units and update logs), with lifecycle management (Active, Paused, Done, Abandoned) and task linking.
- **Decision**:
  - Isolated progress logic in `GoalProgressService`: calculates weighted milestones completion `(sum(done_weights) / sum(total_weights)) * 100` and numeric progress `(current / target) * 100` clamped to 100%, alongside target date proximity and overdue calculations.
  - Ticking the last pending milestone triggers an explicit user prompt: "خلص؟ الهدف / Mark goal as completed?".
  - Numeric progress changes are recorded atomically: updating `goals.current_value` and appending an audit record in `goal_updates`.
  - Status changes to `paused` and `abandoned` mandate specifying a reason.
  - Main navigation FAB contextually launches `AddGoalSheet` when on the Goals tab and `QuickAddSheet` when on other tabs.
  - Tasks can be linked directly to goals via `goal_id` foreign key.

## Decision 9: Phase 4 Ideas & Voice Notes (v1.1) Architecture & Storage Strategy
- **Context**: Spec Section 6.8 and Addendum v1.1 introduce Ideas tracking with Tags, conversion to Tasks or Goals, and an offline Audio Recording & Playback system attached across Tasks, Goals, and Ideas.
- **Decision**:
  - Audio Engine Packages:
    - `record: ^5.1.2` for foreground audio recording in AAC-LC (.m4a) mono at 64kbps.
    - `just_audio: ^0.9.39` for feature-rich, low-latency playback with variable speed support (1.0x, 1.5x, 2.0x) and seeking.
    - `permission_handler: ^11.3.1` for clean Android runtime microphone permission requesting.
  - Storage & Privacy (Spec 14.2):
    - All audio files are stored strictly inside the app-private document directory (`path_provider.getApplicationDocumentsDirectory()`) under the `voice/` subfolder.
    - No `INTERNET` permission added to `AndroidManifest.xml` - audio stays 100% on-device offline.
  - Database Migration Strategy:
    - Drift schema version bumped from 1 to 2.
    - `onUpgrade` hook dynamically detects `from < 2` and creates the `voice_notes` table and composite index on `(parent_type, parent_id)` without dropping or resetting any existing user data.
  - Cross-Entity Attachment & Idea Conversion:
    - Audio recordings are linked polymorphically via `(parent_type, parent_id)`.
    - When converting an Idea to a Task or Goal, all associated voice notes are updated atomically to point to the new entity (`db.moveVoiceNotes(...)`), and the idea status is updated to `converted` with `converted_type` and `converted_id` audit pointers.
  - Voice-Only Capture:
    - When recording without typing a title in Quick Add or Add Idea, a localized placeholder title is automatically generated (`تسجيل صوتي — 3 نوفمبر 12:15 ص`).
  - Discard Protection:
    - Discarding or canceling any active recording longer than 5 seconds triggers an explicit confirmation modal to prevent accidental loss of user speech.

## Decision 10: Phase 5 Stats Dashboard & Excel Export (v1.2) Engine & Packages
- **Context**: Spec Section 7 and Addendum v1.2 require an offline honest statistical dashboard (completed trend, status donut, top reasons, weekday productivity, streaks) and an offline real `.xlsx` generator with 7 dedicated worksheets, RTL support, and Android system sharing.
- **Decision**:
  - Visualization Engine (`fl_chart: ^0.68.0`):
    - Chosen for rich, reactive, performant rendering of bar charts, pie/donut charts, and horizontal progress bars without internet access or webview wrappers.
    - Status distribution donut utilizes exact theme tokens defined in `AppColors`.
  - Excel Generation Engine (`excel: ^4.0.6`):
    - Generates genuine OpenXML `.xlsx` files 100% offline using pure Dart.
    - Supports setting `sheet.isRTL = true` when the user's active locale is Arabic, ensuring native Right-to-Left orientation in Microsoft Excel and Google Sheets.
    - All 7 sheets conform to Addendum 15.3 specification: Summary, Tasks, History, Daily, Reasons, Goals, Ideas.
    - Numerical data is strictly written using Western digits (123) inside the spreadsheet regardless of display numerals setting, guaranteeing compatibility with Excel formulas, Pivot Tables, and Google Sheets charts.
  - Safe Sharing & Privacy:
    - Utilizes `share_plus: ^9.0.0` to invoke the native Android share sheet.
    - Enjaz maintains zero `INTERNET` permission in its manifest; the OS-level share sheet handles handing off the generated file to Drive, Gmail, or WhatsApp upon explicit user request.
  - Core Statistics Mathematical Integrity:
    - Implemented in pure Dart service `StatsService`:
      - Denominator for completion rate strictly excludes future scheduled tasks.
      - Streak engine accounts for continuous active days, allowing today's task completion or yesterday's ongoing streak without penalty.
      - Unit tests verified in `test/unit/stats_service_test.dart`.

## Decision 11: Phase 6 Reminders, Notifications & Recurring Tasks Architecture
- **Context**: Spec Section 8 and Addendum v1.2 require local notifications for task deadlines, morning summary (08:00), evening review (21:00), and weekly Friday Excel report reminder (18:00), along with full recurrence rules (daily, weekly, monthly with short-month clamping, and end dates).
- **Decision**:
  - Local Notification Framework (`flutter_local_notifications: ^17.2.2` & `timezone: ^0.9.4`):
    - Completely offline notification scheduling using Android `AlarmManager`.
    - Notification Action Buttons: includes 'تمت / Done' (marks task done in Drift database and writes event directly in background without opening full app UI) and 'فتح / Open' (navigates to task or Today screen).
    - Respects Android 13+ permission requirements (`POST_NOTIFICATIONS`) with a polite explanatory sheet before system dialog prompt.
    - Fallback architecture: schedules exact alarms when granted (`SCHEDULE_EXACT_ALARM`), gracefully falling back to inexact alarms otherwise.
    - Reboot Resilience: declared `RECEIVE_BOOT_COMPLETED` receiver in `AndroidManifest.xml` and automated `NotificationService.rescheduleAll(db)` on device startup and app launch.
  - Recurring Task Instance Generation:
    - Pure Dart domain service `RecurrenceService`:
      - Rules: `daily`, `weekly` (multi-day selection via bitmask), `monthly` (with day clamping for months with fewer days such as Feb 28/29 and Apr 30).
      - Generates real task instances in `tasks` table for today + 7 upcoming days on app launch and midnight crossover.
      - Each instance has independent status, history, and postponement reasons.
      - Series editing & deletion: provides user choice between 'This one only' (detaches recurrence) and 'All future' (updates series and upcoming uncompleted tasks).
      - Fully unit tested in `test/unit/recurrence_service_test.dart`.

## Decision 12: Phase 7 Backup & Restore Architecture, App Lock & Privacy Strategy
- **Context**: Spec Section 9, Addendum v1.1, and Addendum v1.2 require a complete, rock-solid offline backup and restore system, privacy protection (app lock + task switcher blackout), CSV exports with voice note count, and physical cleanup of orphaned audio files.
- **Decision**:
  - Archive Format & Integrity:
    - Standard `.zip` format using `archive: ^3.6.1`.
    - Every backup contains `manifest.json` (schema version, app version, entity counts, and SHA-256 hashes of all bundled files), `data.json` (full serialization of Drift database tables), and `voice/` (actual audio recordings).
    - Lightweight toggle allows excluding audio files when only database records are desired.
  - Restoration Safety:
    - Before wiping or replacing the local SQLite database, the system automatically creates a local safety snapshot (`safety_pre_restore_*.zip`) in the app documents directory to protect user data against accidental restoration of incorrect files.
    - Database replacement occurs inside a single atomic Drift `transaction()`, followed by audio files extraction and reminder rescheduling via `NotificationService.instance.rescheduleAll(db)`.
  - App Lock & Task-Switcher Privacy (`FLAG_SECURE`):
    - Biometrics and PIN authentication via `local_auth: ^2.2.0`.
    - Integrated with Android native window flags through a Kotlin `MethodChannel` (`com.enjaz.app/privacy`) toggling `WindowManager.LayoutParams.FLAG_SECURE`.
    - When App Lock is active, `FLAG_SECURE` prevents screenshots, screen recording, and blacks out the app preview in Android's recent apps switcher.
    - `AppLockNotifier` observes `WidgetsBindingObserver` lifecycle: when app is paused/backgrounded, it locks immediately, showing `AppLockScreen` upon resumption.
  - Trash Physical File Cleanup:
    - `db.purgeTrashDetailed()` identifies all voice notes that were soft-deleted or whose parent task/goal/idea was soft-deleted, deletes the SQLite records, and permanently deletes the `.m4a` files from device storage via `File.delete()`.

## Decision 13: Round 0 Fixed Release Keystore, ABI Split & Data Continuity
- **Context**: The Phase 7 APK was signed with an ephemeral debug key that changes on every build, preventing in-place Android updates. Furthermore, the universal APK carried 3 CPU architectures (79 MB), Today numerals were mismatched due to default intl Arabic-Indic date formatting, and the Quick Add sheet lacked dedicated forms for Goals and Ideas.
- **Decision**:
  - Release Keystore & Secrets:
    - Configured `signingConfigs.release` in `android/app/build.gradle` reading `enjaz-release-key.jks`.
    - Added an automated CI step that decodes from `ENJAZ_RELEASE_KEYSTORE_BASE64` or deterministically provisions the fixed release keystore.
    - Added `.jks` and `.keystore` to `.gitignore`.
    - Documented two offline copies strategy in `README.md`.
  - Architecture Split:
    - Added `--split-per-abi` in `flutter build apk`, outputting `app-arm64-v8a-release.apk` (packaged as `enjaz-app-arm64.apk` and `enjaz-app.apk`), shrinking download size from 79 MB down to ~20-25 MB.
  - Numerals Normalization:
    - In `AppFormatter`, added bidirectional mapping `_arabicToWesternDigits` to ensure that when `NumeralsFormat.western` is active (the default), any Arabic-Indic digits produced by `DateFormat` in Arabic locale are normalized to Western digits (e.g. "6 نوفمبر 2026").
  - Quick Add Architecture:
    - Segregated form state in `QuickAddSheet` to dynamically render dedicated form controls for Goals (target date, description) and Ideas (tags, details) while hiding Task-only controls, and restricted the multi-line import action exclusively to Tasks and Errands.

## Decision 14: Round 1 Shared Reminders, Alarms, Edit-After-Save, Trash & Bulk Selection
- **Context**: Task details previously did not permit editing all fields (due date/time, priority, goal link, started/finished times) with an explicit save button, alarms only showed as silent shade notifications, reminder channel attributes were immutable on Android 8+, and bulk management actions were unavailable.
- **Decision**:
  - Drift Schema Version 3 Migration:
    - Introduced a dedicated, shared 
eminders table (owner_type, owner_id, kind, 	rigger_type, offset_minutes, bsolute_time, message, enabled).
    - Implemented onUpgrade step from version 2 to 3 migrating existing task reminders.
  - Alarm Channel & Insistent Notification Strategy:
    - Created new channel IDs enjaz_alarm_v2 and enjaz_reminders_v2 and deleted deprecated channels so that audio attributes and high importance take effect on device.
    - Configured enjaz_alarm_v2 with Importance.max, AudioAttributesUsage.alarm, ongoing: true, and FLAG_INSISTENT = 4 (dditionalFlags: Int32List.fromList([4])), ensuring continuous ringing and vibration until explicit user action (Done, Snooze, Stop).
    - Avoided full-screen intent permissions (USE_FULL_SCREEN_INTENT) to protect battery and prevent disruptive overlays, adhering to Google Play policies.
    - Switched from USE_EXACT_ALARM to SCHEDULE_EXACT_ALARM with a runtime verification screen and direct shortcut to Android system settings.
  - Task Editing & Exit Protection:
    - All task fields are now fully editable with an explicit 'حفظ التعديلات / Save Changes' action.
    - Added PopScope exit interception: if unsaved modifications exist, a confirmation dialog warns the user before discarding.
    - Recurring tasks prompt the user with 'هذه المهمة فقط' or 'كل المهام القادمة'.
  - Bulk Selection Engine:
    - Built 	askSelectionProvider and BulkSelectionBar enabling long-press selection on Today, History, and Inbox with bulk done, bulk move, bulk status change, and bulk soft-delete actions, each supported with an 8-second Undo mechanism.

