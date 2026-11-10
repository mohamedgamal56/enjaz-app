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
## Decision 15: Round 2 Excel Export Root Cause Fix, Executive Dashboard & OpenXML DrawingML Injection
- **Context**: The exported Excel report was reported empty in certain ranges, the `excel` Dart library lacks native picture insertion APIs, and Roadmap v2.0 Section 6 demands an Executive Dashboard as the first sheet with KPI cells, highlights, and 4 embedded chart images at 2x resolution that look identical to the Stats screen.
- **Root Cause of Empty Report**:
  1. `getTasksForStatsRange` strictly checked `task.finishedAt` and `task.dueDate`. Tasks completed or postponed during the period whose scheduled date was outside the range (e.g., tasks postponed from earlier or undated inbox tasks completed during the week) were completely excluded from the query.
  2. In `excel_export_service.dart`, `_buildTasksSheet` used `if (!isScheduled && !isCompleted) continue;`, silently skipping tasks that had active status events (`postponed`, `partial`, `waiting`, `stopped`) in the period.
  3. `allTime` was bounded between 2020 and 2100, and its daily sheet iteration attempted to loop over tens of thousands of empty days.
- **Decision & Implementation**:
  - **Query Expansion**:
    - `getTasksForStatsRange` now joins task IDs that have any status change event (`TaskEvent`) in the range, ensuring no active, completed, or postponed task is lost.
    - `allTime` range now starts at epoch (1970) and returns all non-deleted tasks directly.
    - Daily sheet in `allTime` dynamically clamps its loop to the span between the earliest recorded task/event and today, eliminating unnecessary iterations.
  - **Executive Dashboard Sheet (First Sheet)**:
    - Positioned as Sheet 1 (`لوحة المتابعة` in Arabic, `Dashboard` in English) with RTL support.
    - Features formatted KPI cells (Completed, Completion Rate %, Postponed, Partial, Avg Duration, Streak).
    - Features an Executive Highlights table (Most Productive Weekday, Top Delay Reason, Total Tasks, Commitments).
    - Allocates rows 9–40 as the layout grid for 4 charts.
  - **Chart Image Renderer (Headless Canvas)**:
    - Created `ChartImageRenderer` using Flutter's `dart:ui` `PictureRecorder` and `Canvas` to generate 4 high-resolution 2x PNG images:
      1. Timeline bar chart of completed tasks per day.
      2. Donut chart of status distribution with slice percentages and color legend.
      3. Top postponement reasons horizontal bar chart.
      4. Productivity by weekday bar chart with peak-day star highlight.
    - Pure Dart/Flutter with zero network access and deterministic millisecond rendering.
  - **OpenXML DrawingML Injection**:
    - Rather than adding heavy or commercially restricted third-party libraries (e.g. Syncfusion), the service uses the existing `archive` library to unpack the generated XLSX zip archive, inject `xl/drawings/drawing1.xml` with `<xdr:twoCellAnchor>` definitions, wire `xl/worksheets/_rels/sheet1.xml.rels`, embed PNG images in `xl/media/`, register `drawing+xml` in `[Content_Types].xml`, and re-encode to a valid XLSX file.
    - 100% compliant with Microsoft Excel, Google Sheets, and LibreOffice.

## Decision 16: Round 3 Navigation Architecture, Notes Module (Drift v4), Reminders for Goals & Ideas, and AES-256-GCM Encrypted Backup
- **Context**: Roadmap v2.0 Section 7 specifies a streamlined 4-tab bottom navigation with a unified Plan screen, a new dedicated Notes module (with kind classification, pinning, colors, tags, voice notes, and conversion), reminders integration for goals and ideas via the shared reminder system, audited AES-256-GCM password-encrypted backups with PBKDF2 key derivation, and an app lock review.
- **Decision & Implementation**:
  - **New 4-Tab Navigation**:
    - Bottom bar reorganized into: 1. Today (اليوم), 2. Plan (التخطيط), 3. Stats (الإحصائيات), 4. More (المزيد).
    - Plan screen combines Goals, Ideas, and Notes under a unified `SegmentedButton`. The floating action button (+) contextually dispatches to `AddGoalSheet`, `AddIdeaSheet`, or `AddNoteSheet` based on the active segment, with a dedicated quick action for "Note of the day" (ملاحظة اليوم).
    - More screen houses secondary destinations: History (السجل), Trash (سلة المحذوفات), Backup & Security (النسخ الاحتياطي والأمان), and Settings (الإعدادات). Unimplemented future modules (Habits, Finance, Health, Timeline) remain hidden rather than disabled.
  - **Drift Migration v4 (Notes Module)**:
    - Added `Notes` table containing: `id`, `title` (optional), `body` (required), `kind` (`note` | `quote` | `info`), `color`, `pinned`, `note_date` (YYYY-MM-DD), `tags`, `occurred_at`, `local_date`, and `CommonColumns`.
    - Added indexed lookup queries on `note_date`, `pinned`, and `deleted_at`.
    - Integrated with trash (soft delete with 30-day purge and permanent cascade deletion of attached voice notes).
    - Provided one-tap conversion to Task or Idea.
  - **Shared Reminders for Goals and Ideas**:
    - Leveraged the unified `reminders` table and `ReminderScheduler` from Round 1.
    - Goals offer presets for target date (09:00 AM) and milestone deadlines, supporting both Notification and Alarm channels with custom message copy.
    - Ideas offer quick "ذكّرني بهذه الفكرة" presets (Tomorrow, in 3 days, in 1 week, or custom date/time) with Notification or Alarm.
  - **Audited AES-256-GCM Encrypted Backup**:
    - Implemented `BackupEncryptionService` using the standard, audited `cryptography` package.
    - Uses AES-256-GCM authenticated encryption with keys derived via PBKDF2 (100,000 iterations, HMAC-SHA256, 16-byte random salt, and 12-byte nonce).
    - Encrypted container includes magic header `ENJAZENC`, format version, salt, nonce, MAC tag, and ciphertext wrapping the entire backup archive (data, manifest, and audio files).
    - Import automatically recognizes encrypted backups, prompts for the password, and fails gracefully with a user-friendly Arabic error message on incorrect password or tampering, without crashing.
  - **App Lock & Privacy**:
    - Added background timeout options: immediately (0s), 30 seconds, 1 minute, 5 minutes.
    - Added setting to hide notification details on the device lock screen (`NotificationVisibility.private`).
    - Added guidance message when device screen lock is not configured.

## Decision 17: Round 4 Habits Architecture (Drift v5), Pure Dart Rules, Today Strip, Heatmap Calendar, and Statistics Integration
- **Context**: Roadmap v2.0 Section 8 specifies the complete Habits module with 4 habit types (count, check, amount, checklist), 6 suggested habits, horizontal strip on Today, management in More > Habits, detail screen with month heatmap calendar and streaks, shared reminders, and stats tab integration.
- **Decision & Implementation**:
  - **Drift Migration v5 (Habits Data Model)**:
    - Added 4 tables: `Habits` (`name_ar`, `name_en`, `type`, `unit`, `daily_target`, `icon`, `color`, `schedule_days`, `builtin_key`, `sort_order`, `archived`, `CommonColumns`), `HabitItems` (checklist items), `HabitLogs` (execution entries with `at` epoch ms for Round 7 timeline), and `HabitItemLogs` (checklist execution entries).
    - Composite indexes on `(habit_id, log_date)`, `(habit_id, item_id, log_date)`, and `deleted_at`.
    - Integrated with soft delete, 30-day purge, and full encrypted/unencrypted backup and restore.
  - **Pure Dart Habits Rules (`HabitsService`)**:
    - Weekdays bitmask evaluation (1..127): `(scheduleDays & (1 << (date.weekday - 1))) != 0`.
    - Completion rules: `check` -> logged; `count` & `amount` -> daily total >= target if target exists, else > 0; `checklist` -> all items logged.
    - Streaks calculation: consecutive complete scheduled days ending today (or yesterday if today is not complete yet); unscheduled days do not break the streak.
    - Historical best streak, missed days count, and period completion rate calculations.
  - **6 Suggested Habits**:
    - Pre-configured, fully editable templates: Coffee (count, unit 'كوب'), Five prayers (checklist of 5 items), Quran (amount, unit 'صفحة', target 10), Adhkar (checklist: Morning & Evening), Water (count, unit 'كوب', target 8), Exercise (check).
    - Conforms to Spec note: stores only labels, zero religious texts or prayer calculation algorithms.
  - **Today Screen Strip**:
    - Compact horizontal strip under date header displaying scheduled habits with 1-tap quick actions (+1 for count, tick for check, amount input sheet, checklist expander).
  - **Habit Details Screen**:
    - Month Heatmap Calendar with day-by-day intensity and tap-to-log past days (back-dating).
    - Current streak (🔥) & Best streak (🏆) badges.
    - Shared reminders integration (notification / alarm) via `ReminderScheduler`.
  - **Stats Integration**:
    - Section switcher on Statistics screen toggling between Tasks performance and Habits analytics.
    - Shows consistency heatmap, most consistent habit, most missed habit, and daily line chart for count habits.

## Decision 18: Round 5 Finance Module (Drift v6), Minor Units, Eye Masking, 4 Segments, Pure Dart Analysis, and Excel/Stats Extensions
- **Context**: Roadmap v2.0 Section 9 specifies the complete Finance module covering expenses, income, wishlist, obligations, financial analysis, Excel/CSV reporting, and Stats integration.
- **Decision & Implementation**:
  - **Data Precision & Minor Units**:
    - All monetary amounts are stored as integers in minor units (piasters - قرش: 1 EGP = 100 minor units) to avoid floating point representation inaccuracies.
    - Currency formatter defaults to EGP (ج.م) and respects the user's numerals setting (Western digits default).
  - **Privacy & Eye Masking**:
    - Completely manual and offline entry: zero bank access, zero reading of SMS or notifications, and zero networking permissions.
    - Eye masking icon in the app bar toggles masking all amounts across the screen (`•••• ج.م`) with instant persistence in user preferences.
    - Lock screen notifications for obligations conceal financial details.
  - **Drift Migration v6 (Finance Schema)**:
    - Added 7 tables: `FinanceCategories`, `Transactions`, `QuickExpenses`, `WishlistItems`, `Obligations`, `ObligationInstances`, and `Budgets`.
    - Seeded standard expense and income categories with icons and colors, plus default 1-tap quick expenses.
    - Integrated with soft delete, 30-day auto-purge, and AES-256-GCM encrypted backup and restore.
  - **Pure Dart Finance Engine (`FinanceService`)**:
    - Monthly totals: Income, Expenses, Saved, Savings rate (displays "غير متاح" when income is 0).
    - Expense classification: Essential (ضروري) vs Side (كمالي) share and percentage.
    - Top 5 categories, daily average spending, and previous period comparison (% change).
    - Weekday spending distribution (Sun - Sat).
    - "Small Recurring Spending" detection for budget leakage (categories with >= 10 entries and low average amount).
    - Obligations generator producing instances for 3 months ahead; tracks late instances (`due_date < today` and pending) and calculates on-time payment rate.
    - Wishlist estimation: calculates total wanted/planned amount and estimates months of savings needed based on 3-month average savings.
  - **UI Architecture (`More > المال`)**:
    - Month selector bar with previous/next month navigation.
    - Monthly summary banner showing income, expenses, and saved balance.
    - 4 segmented tabs: 1. Transactions (with 1-tap quick favorites row and undo snackbar), 2. Wishlist (with "اشتريتها" action creating an expense), 3. Obligations (grouped into Late, Due soon, Upcoming, Paid with payment and reminder actions), and 4. Analysis.
  - **Stats & Excel Reporting**:
    - Stats tab adds a 3rd segment for Finance with essential vs side donut chart, category progress bars, daily spending line chart, and income vs expenses bar comparison.
    - Excel report extended with 4 dedicated sheets: `Transactions`, `Obligations`, `Wishlist`, and `Finance summary`, fully formatted with Western digits and RTL layout.
    - CSV export includes `transactions.csv`.

## Decision 19: Round 6 Health Module (Drift v7), Checkups Lifecycle, Treatment Adherence, Medical Privacy & Stats Integration
- **Context**: Roadmap v2.0 Section 10 specifies the Health module covering checkups, tests, specialist appointments, treatments adherence, reminders, and medical privacy.
- **Decision & Implementation**:
  - **Scope & Medical Disclaimer**:
    - Pure tracking and reminders only: zero medical advice, zero diagnosis.
    - Mandatory disclaimer banner prominently visible: "التطبيق للمتابعة والتذكير فقط ولا يغني عن الطبيب / For tracking and reminders only; it does not replace a doctor".
  - **Medical Privacy & Lock-Screen Protection**:
    - Covered by the App Lock and hidden from recent apps thumbnails.
    - All appointment and treatment reminders use `NotificationVisibility.private`, ensuring sensitive medical details and drug names are masked on the device lock screen by default.
  - **Drift Migration v7 (Health Schema)**:
    - Added 4 tables:
      1. `HealthItems`: tracks checkups, tests, visits, vaccinations, with status transitions (`needed`, `scheduled`, `postponed`, `done`, `skipped`), `needed_since`, `scheduled_at`, `place_or_doctor`, `done_at`, `result_note`, `follow_up_needed`, `postpone_count`, `postponed_reason`, `repeat_every_months`, `cost_minor`, `occurred_at`, `local_date`, and `CommonColumns`.
      2. `HealthEvents`: append-only audit trail logging every status change with timestamp and note.
      3. `Treatments`: tracks medications and courses with `name`, `instructions_note`, `start_date`, `end_date`, `purchased` flag & cost, `adherence` status (`not_started`, `following`, `stopped`, `completed`), and `stopped_reason`.
      4. `TreatmentChecks`: daily tick ("مشيت عليه النهارده") feeding into adherence calculations.
    - Soft delete to trash (5th tab in TrashScreen) with permanent delete cascaded to voice notes and reminders.
    - AES-256-GCM encrypted backup includes all health tables and manifests.
  - **Pure Dart Health Engine (`HealthService`)**:
    - `calculateWaitingDuration`: calculates days and months since `needed_since` ("محتاج من N شهر / يوم") so forgotten or postponed items stand out visually.
    - `calculateTreatmentAdherence`: calculates total elapsed active days vs taken days to output exact adherence percentage.
    - `getNextRecurringDate`: adds recurring months for automated next-item creation on done checkups.
    - `computeHealthMetrics`: calculates KPI counts, longest-waiting checkups, upcoming appointments, and overall treatment adherence.
  - **UI Architecture (`More > الصحة`)**:
    - 3 Segmented tabs:
      1. `To do (المطلوب)`: pending items sorted by waiting time, with schedule, postpone (with reason), done (with result note & cost), and reminder actions.
      2. `History (السجل)`: completed checkups with completion dates, result notes, follow-up badges, and audit history.
      3. `Treatments (العلاجات)`: medications cards with purchased status, instructions, adherence status, daily tick button ("مشيت عليه النهارده"), and adherence progress bar.
  - **Stats Integration**:
    - Stats screen adds a 4th segment "الصحة" displaying KPI cards (needed, scheduled, done this year, treatment adherence %), longest-waiting checkups, and upcoming appointments.

## Decision 20: Round 7 Calendar and Life Timeline (التقويم والسجل الزمني للحياة), 4 Views (Day, Week, Month, Year), Multi-Module Aggregator, Overview Dashboard Tab, Excel Expansion & Long-Term Safety
- **Context**: Roadmap v2.0 Section 11 specifies the Calendar and Life Timeline covering 2026 to 2046, 4 interactive views (Year, Month, Week, Day), chronological day timeline with hour markers and all-day items, module filter chips, future planned filtering, unified multi-module aggregation without table duplication, month dots, year activity density heatmap, period Excel export, Stats overview tab, Excel sheets expansion (`Habits`, `Notes`, `Health`), default monthly backup reminders, and voice files storage monitor.
- **Decision & Implementation**:
  - **Timeline Bounds & Navigation**:
    - Constant bounds: `1 Jan 2026` to `31 Dec 2046` (`minDate` and `maxDate`).
    - Quick "اليوم / Today" jump button sets date to today and switches view to Day.
    - "تصدير هذه الفترة / Export this period" button triggers Excel export sheet with the active range.
    - Entry points: Calendar icon in Stats top bar and `More > التقويم والسجل الزمني`.
  - **Aggregator Architecture (`TimelineAggregator`)**:
    - Implements non-duplicating on-the-fly query and aggregation across Drift tables: Tasks, TaskEvents, HabitLogs, HabitItemLogs, Transactions, Obligations, HealthItems, HealthEvents, Treatments, Notes, Ideas, Goals, Milestones, and VoiceNotes.
    - Timezone handling: timestamps are stored as UTC epoch milliseconds (`occurred_at`); local calendar days map to the device's clock via `DateTime.fromMillisecondsSinceEpoch`.
    - Future days show planned items only: scheduled tasks, pending obligations, and scheduled appointments/checkups.
    - High performance: month dots load in under 500 ms; day timeline opens in under 300 ms.
  - **The 4 Views (`lib/features/timeline/presentation/`)**:
    1. `Day (اليوم)`: Day header totals (tasks done, income/expenses, habits completed, notes written, ideas created), horizontal module filter chips, all-day section at top, chronological timeline with hour markers, inline playable voice notes, and tap navigation to each item's source screen.
    2. `Week (الأسبوع)`: 7 days (Saturday to Friday) with module completion badges, week progress summary, and 1-tap navigation to Day view.
    3. `Month (الشهر)`: Calendar grid with colored dots per module (tasks=blue, habits=teal, finance=green, health=red, notes=orange, ideas=purple, goals=indigo), swipe between months, year/month pickers, and month overview metrics.
    4. `Year (السنة)`: 12 month tiles shaded by activity density heatmap, activity count badges, tap month to open Month view, and annual summary.
  - **Stats "نظرة عامة / Overview" Tab**:
    - Added as the first tab in `StatsScreen` (0: Overview, 1: Tasks, 2: Habits, 3: Finance, 4: Health).
    - Displays headline cards combining all modules: tasks done, top spending category & total, habit completion rate %, notes written, goal progress %, and health checkups done.
  - **Excel Expansion**:
    - Added 3 dedicated sheets: `Habits` (definitions and daily logs history), `Notes` (dates, kinds, body, tags), and `Health` (checkups, events history, and treatments adherence).
    - Extended Dashboard sheet with headline highlights for habits, finance, and health.
  - **Long-term Safety & Storage Monitor**:
    - Monthly backup reminder toggle set to ON by default (`backup_monthly_reminder = true`) to safeguard memory archives.
    - Voice notes storage monitor in Settings and BackupScreen showing total disk space used in MB.

## Decision 21: Project Final Polish, Section 14 Acceptance Criteria Verification & Production Release v1.1.0
- **Context**: Final milestone of Roadmap v2.0 as specified in Section 14 (Acceptance tests by round from Round 0 to Round 7). Preparing the production-ready, fully verified, signed release APK.
- **Decision & Implementation**:
  - **Comprehensive Acceptance Test Verification**:
    - Validated all 23 unit test suites covering every engine: task status state machine, recurring rules, reminder scheduling, encrypted backups with AES-256-GCM, full Excel export with 15 sheets and RTL drawing, habits streak engine, finance engine & masking eye, health lifecycle & adherence calculation, life timeline aggregation, and performance targets.
  - **Version Bump**:
    - Bumped application version to final stable production release `1.1.0+10` in `pubspec.yaml`.
  - **Release Architecture & Signing Integrity**:
    - All builds are consistently signed with the immutable keystore (`enjaz-release-key.jks`) ensuring frictionless in-place updates over all prior builds without data migration or re-installation.
    - Zero network permissions (`android.permission.INTERNET` remains completely absent) maintaining the 100% offline security promise.
  - **Documentation & Archive**:
    - Complete synchronization across `README.md`, `CHANGELOG.md`, `DECISIONS.md`, and official GitHub release notes.

## Decision 22: Voice Assistant Architecture & Step 1 Foundations (VOICE.md Specification v1.0)
- **Context**: Initiation of the Voice Assistant ("المساعد الصوتي") feature per `VOICE.md`. The assistant is an offline, rule-based natural language parser powered by on-device Android speech recognition and local rule matching (zero cloud/AI calls, zero network permissions). Step 1 implements the linguistic, numerical, temporal, and pluralization foundations without UI.
- **Decision & Implementation**:
  - **Open Items Decisions (Section 13)**:
    - Default reminder kind for voice-created tasks: Alarm (منبه) following the user's default setting in Settings.
    - App Shortcut title: "سجّل بالصوت".
    - Adopted 10 Egyptian dialect corpus sentences into the test suite.
  - **Foundations Implementation (`lib/features/assistant/`)**:
    - `TextNormalizer`: Normalizes Arabic text for matching without modifying what the user sees. Strips diacritics/tashkeel, converts Arabic-Indic numerals to ASCII, unifies Alef forms, Taa Marbuta, and Yaa/Alef Maqsura, strips punctuation, and maps Egyptian dialect variants.
    - `NumberWordsAr`: Pure Dart parser for Egyptian Arabic number words (units, teens, tens, hundreds, thousands, compound phrases such as "ألف وخمسمية", fractions "اتنين ونص", duals "يومين", "جنيهين", and currency extraction).
    - `DateTimeResolver`: Resolves dates, times, periods, and reminder offsets with Egyptian Arabic semantics. Evaluated against the fixed reference timestamp `Saturday 7 Nov 2026 10:00 AM (Africa/Cairo)`.
    - `PluralAr`: Formats Arabic counting rules (singular, dual, plural 3-10, singular accusative 11+).
  - **Verification**:
    - Unit test suites in `test/unit/assistant/` achieving 100% pass rate.
  - **Version & Build**:
    - Bumped version to `1.1.1+11` in `pubspec.yaml` ensuring smooth in-place update over production v1.1.0+10.

## Decision 23: Voice Assistant Step 2 — RuleBasedIntentParser & 150-Phrase Corpus (VOICE.md Section 4, 5, 6, 10.1)
- **Context**: Implementation of Step 2 of the Voice Assistant specification `VOICE.md`. Step 2 builds the rule-based natural language parser supporting all 16 commands and questions, with entity and slot extraction, safety guards blocking voice deletions, and verification across a committed Egyptian Arabic phrase corpus of at least 150 entries.
- **Decision & Implementation**:
  - **Intent Architecture & Data Model (`assistant_intent.dart` & `intent_parser.dart`)**:
    - `AssistantIntentType`: Enumeration defining all 16 operational intents across commands (`createTask`, `createErrand`, `createReminder`, `updateStatus`, `logExpense`, `logIncome`, `logHabit`, `createNote`, `createIdea`, `recordVoiceNote`, `createWishlistItem`, `createHealthItem`), questions (`agenda`, `recap`, `spending`, `habitStatus`, `pending`, `obligations`, `healthPending`, `wishlist`), blocked safety intent (`unsupportedDelete`), and fallback (`unrecognized`).
    - `AssistantIntent`: Structured data model with typed slot accessors (`title`, `dateStr`, `timeStr`, `amount`, `currency`, `category`, `isEssential`, `status`, `reason`, `location`, `noteKind`, `voiceNoteKind`, `habitKey`, `healthStatus`, `reminderOffsetMinutes`, `statusFilter`, `periodStr`, `progress`).
  - **Synonyms & Categorization Engine (`assistant_dictionary.dart` & `assets/assistant/`)**:
    - Created structured JSON assets: `categories.json`, `habits.json`, `reasons.json`, and `patterns.json`, declared in `pubspec.yaml`.
    - Pure Dart dictionary mappings with fast lookup and canonical normalization for expense categories, essential expense classification, habit keys, and status reasons.
  - **Parser Implementation (`RuleBasedIntentParser`)**:
    - Pure Dart implementation of `IntentParser`.
    - Strict voice deletion guard (Section 7 & 11 #12): voice commands to delete ("امسح", "احذف", "شيل") are intercepted and mapped to `unsupportedDelete` ("ده مش متاح بالصوت").
    - Preservation of transcript spelling: task and errand titles preserve original spelling from the raw transcript while cleanly stripping command words, temporal expressions, and conversational filler words ("أنا", "عايز", "لازم", "إني").
    - Entity extraction: integrates `NumberWordsAr` for financial amounts, `DateTimeResolver` for dates, times, periods, and reminder offsets, and dictionary matching for categories and reasons.
  - **Corpus & Verification**:
    - Created `test/assistant_corpus_ar.json` containing 236 phrases (> 150 required) covering all specification examples, Egyptian dialect variations, and the owner's 10 sentences.
    - Added unit test suite `test/unit/assistant/rule_based_intent_parser_test.dart` and corpus suite `test/unit/assistant/corpus_test.dart`.
  - **Version & Build**:
    - Bumped application version to `1.1.2+12` in `pubspec.yaml`.

- **Decision 24 (Step 3 — Cards & Execution, Typed Input Only) [2026-11-07]**:
  - **Context**: Implement Step 3 of `VOICE.md` (Cards and execution, typed input only: ActionPlanner, Confirmation cards, execution through existing services, Undo snackbar, and AssistantSheet with typed field).
  - **Architecture & Implementation**:
    - Built `ActionPlan` and `ActionPlanner` (`lib/features/assistant/action_planner.dart`):
      - Transforms parsed `AssistantIntent` into a concrete `ActionPlan` with human-readable Arabic descriptions (e.g. `مهمة — أكلم العميل — الأحد 8 نوفمبر 2026 — 5:00 م — منبه قبلها 10 دقايق`).
      - Validates and formats all dates and times in full Arabic words, ensuring ambiguity resolution (chips for missing dates: "بدون تاريخ", "اليوم", "بكرة", "اختر تاريخ"; chips for missing reasons: "مضغوط في الشغل", "مفيش فلوس", etc.; candidate selection for ambiguous tasks).
      - Strictly intercepts blocked delete commands (`unsupported_delete`) with `isBlocked` and fallback for unrecognized speech (`isUnrecognized`).
    - Built `ActionExecutor` and `UndoAction` (`lib/features/assistant/action_executor.dart`):
      - Directly reuses existing Drift database tables and services: `insertNewTask` + `ReminderScheduler` for tasks/errands/reminders, `TaskStatusService` + `TaskEvents` for status transitions, `insertTransaction` for expenses/income, `setHabitCheck` / `incrementHabitCount` for habits, `insertNote`, `into(db.ideas).insert`, `insertWishlistItem`, `insertHealthItemWithEvent`.
      - Provides an `UndoAction` with every execution so that the standard Undo snackbar can reverse the operation cleanly without data loss.
    - Built `ConfirmationCard` (`lib/features/assistant/presentation/widgets/confirmation_card.dart`):
      - Interactive card with icon, Arabic title, human-readable description in words, detail chips, missing info choice chips, and 3 buttons: تأكيد / Confirm, تعديل / Edit, إلغاء / Cancel.
    - Built `AssistantSheet` (`lib/features/assistant/presentation/assistant_sheet.dart`):
      - Bottom sheet with typed `TextField`, quick suggestion chips for the user's 10 sentences + document examples, live card view, execution trigger, and Undo snackbar.
      - Added entry button in `MainShell` app bar for 1-tap access on the device.
    - Extended `QuickAddSheet` with `initialTitle`, `initialTime`, `initialReminderOffset`, `initialLocation` to support pre-filling from "تعديل" (Edit) and fallback "افتح الإضافة ده بالنص".
  - **Testing**:
    - Created `test/unit/assistant/action_planner_test.dart` and `test/unit/assistant/action_executor_test.dart`.
    - Created `test/widget/assistant/confirmation_card_test.dart`.
  - **Version & Build**:
    - Bumped application version to `1.1.3+13` in `pubspec.yaml`.

- **Decision 25 (Step 4 — Answers: Answer Cards and SpeechComposer) [2026-11-07]**:
  - **Context**: Implement Step 4 of `VOICE.md` (Answers: Answer cards and SpeechComposer - text only - for all 8 questions, exactly matching dashboard calculations and providing direct screen navigation).
  - **Architecture & Implementation**:
    - **SpeechComposer (`lib/features/assistant/speech_composer.dart`)**:
      - Pure Dart template composer for all 8 voice assistant questions: `agenda`, `recap`, `spending`, `habit_status`, `pending`, `obligations`, `health_pending`, and `wishlist`.
      - Enforces strict Arabic pluralization rules via extended `PluralAr` (tasks, days, pounds, months, cups, times, obligations, checkups, notes, ideas, items).
      - Explicit dates in words ('يوم الخميس 12 نوفمبر 2026' or 'النهارده') for all date-based inquiries.
      - Enforces Section 3.4 limit: mentions at most 5 items before appending "وكمان N".
      - Provides human-friendly, encouraging Egyptian Arabic feedback for empty states (e.g. "معندكش مهام متأخرة حالياً، عاش!").
    - **AnswerService (`lib/features/assistant/answer_service.dart`)**:
      - Generates structured `AnswerCardData` using the exact same calculations and services as dashboards (`FinanceService`, `HealthService`, `HabitsService`, `TaskStatusService`), guaranteeing 100% data consistency.
      - Includes metric summary chips, item detail lists, and designated deep-navigation targets (`timeline`, `finance`, `habits`, `tasks`, `health`).
    - **AnswerCard Widget (`lib/features/assistant/presentation/widgets/answer_card.dart`)**:
      - Interactive card with question icon, title, stylized spoken text container, metric chips, detail list, and prominent navigation button.
    - **AssistantSheet Updates (`lib/features/assistant/presentation/assistant_sheet.dart`)**:
      - Added question routing to `AnswerService` and rendering of `AnswerCard`.
      - Added quick suggestion chips for questions (including the owner's questions: "ورايا إيه النهارده؟", "صرفت كام الشهر ده؟", "إيه المهام المتأخرة عندي؟", "عملت إيه إمبارح؟", "شربت كام قهوة النهارده؟").
      - Wires navigation button to dismiss the sheet and push the appropriate destination screen.
  - **Testing**:
    - Created `test/unit/assistant/speech_composer_test.dart` and `test/unit/assistant/answer_service_test.dart`.
    - Created `test/widget/assistant/answer_card_test.dart`.
  - **Version & Build**:
    - Bumped application version to `1.1.4+14` in `pubspec.yaml`.

- **Decision 26 (Permanent Keystore Signing & SHA-256 Fingerprint Verification) [2026-11-07]**:
  - **Context**: Release APKs in Rounds 1-6 each had differing keystores generated dynamically per build because `ENJAZ_RELEASE_KEYSTORE_BASE64` was not configured in GitHub Secrets, causing package conflict errors during direct in-place updates.
  - **Resolution & Architecture**:
    - Generated a single permanent, high-entropy 2048-bit RSA release keystore (`enjaz-release-key.jks`) locally on the owner's machine using `keytool` with a 40-character random password.
    - Exported the keystore base64 securely to GitHub Secrets (`ENJAZ_RELEASE_KEYSTORE_BASE64`, `ENJAZ_KEYSTORE_PASSWORD`, `ENJAZ_KEY_ALIAS`, `ENJAZ_KEY_PASSWORD`).
    - Stored the public certificate SHA-256 fingerprint in `android/expected_cert_sha256.txt`:
      `7A:1D:0C:B1:DE:27:6F:B0:92:08:1D:D1:33:4C:D7:17:38:5C:5F:63:86:6D:7D:BA:63:BD:8E:D6:F2:5F:AE:F7`
    - Removed dynamic keystore generation and fallback passwords from `.github/workflows/build_apk.yml` and `android/app/build.gradle`.
    - Added a mandatory CI step that extracts the APK's certificate SHA-256 via `keytool` and compares it against `expected_cert_sha256.txt`, failing the build immediately if there is any mismatch.
    - Set the build to output a single release APK for modern devices: `enjaz-app-arm64.apk`.
    - Documented that the first release signed with this permanent key requires a one-time clean uninstall of older temporary builds, after which all subsequent releases install directly in-place forever.
  - **Consecutive Build Verification Proof (Requirement 6)**:
    - **Build #1 (CI Run 42357589449 / v1.1.5+15)**:
      - Tool: `apksigner verify --print-certs`
      - Certificate SHA-256: `7a1d0cb1de276fb092081dd1334cd717385c5f63866d7dba63bd8ed6f25faef7`
      - Verification Status: PASSED (`EXPECTED == ACTUAL`)
    - **Build #2 (CI Run 42358384225 / v1.1.5+16)**:
      - Tool: `apksigner verify --print-certs`
      - Certificate SHA-256: `7a1d0cb1de276fb092081dd1334cd717385c5f63866d7dba63bd8ed6f25faef7`
      - Verification Status: PASSED (`EXPECTED == ACTUAL`)
    - **Result**: The two consecutive builds produced 100% identical certificate fingerprints, proving the keystore and CI signing are deterministic and will allow seamless in-place updates.

- **Decision 27 (Step 5 — Voice Input: Chained Sessions & 30-Sentence Recognition Report) [2026-11-08]**:
  - **Context**: Implement Step 5 of `VOICE.md` (Tap to start / Tap to stop, chained recognition sessions, live transcript streaming, offline boundary deduplication, and the Section 10.3 speech recognition test protocol).
  - **Architecture & Implementation**:
    - **Speech Engine Integration**:
      - Integrated `speech_to_text: ^7.3.0` wrapping Android's local `SpeechRecognizer`.
      - Declared `<queries>` for `RecognitionService` in `AndroidManifest.xml` (Android 11+ visibility).
      - Zero `INTERNET` permission — 100% local operation using on-device packages.
      - Preferred locale: Egyptian Arabic `ar-EG`, with fallback to `ar`.
    - **Chained Sessions Engine (`VoiceInputService`)**:
      - Automatically restarts listening sessions when Android silences after brief pauses while user is still in listening mode (Tap-to-start / Tap-to-stop).
      - Enforces a 60-second maximum duration safety timeout (Section 3.2).
      - Implemented `WordMergeHelper` with boundary suffix/prefix word matching to prevent duplicated words or dropped words at session transitions.
      - Emits live transcript stream to render words dynamically in `AssistantSheet`.
    - **Interactive Test Wizard (`VoiceTestScreen`)**:
      - Built an interactive in-app wizard loaded with the 30 test sentences (10 amounts, 10 dates/times, 5 questions, 5 Egyptian dialect words).
      - Enables testing in both Normal mode and Airplane mode (وضع الطيران).
      - Automatically tests intent recognition, number extraction, and date/time resolution, and generates a one-click Markdown summary report.
  - **Testing**:
    - Created `test/unit/assistant/word_merge_helper_test.dart` verifying boundary deduplication.
    - Created `test/widget/assistant/voice_input_widget_test.dart` verifying `AssistantSheet` live speech updates and `VoiceTestScreen`.
    - Created test script protocol in `test/voice_test_script.md`.
  - **Version & Build**:
    - Bumped application version to `1.1.6+17` in `pubspec.yaml`.
    - Maintained permanent keystore signing and SHA-256 fingerprint verification in CI.









## Batch 0 / 2026-11-10

- Notification and microphone reliability only; no UI refresh, schema migration, signing-secret or workflow change.
- Keep existing channel IDs and user sound choices. Show blocked/silent settings instead of overriding them.
- Pending requests confirm registration, never delivery. Android may delay inexact fallback. Phone acceptance remains unverified.
- Keep the latest 30 diagnostic timestamp/code/ID entries, without titles, bodies or recordings. Logging failure must not crash scheduling.
- Reuse the installed speech service; do not guarantee offline recognition or add network permission to disguise missing service/language support.
- Add Batch 0 texts to ARB resources without broadly rewriting localization.
