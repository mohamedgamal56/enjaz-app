# Page 1

Enjaz — Change Requests and | إﻧﺠﺎز
Roadmap v2.0
Prepared for Mohamed Gamal — 4 Nov 2026 — Companion to SPEC.md (sections 0–15).
Save this file in the repository root as CHANGES.md.
وﻧﺼﻮص  ﺑﺪﻗﺔ،  ﻳﻔﻬﻤﻪ(  Antigravity) اﻟﻮﻛﻴﻞ  ﻋﺸﺎن  ﺑﺎﻟﺈﻧﺠﻠﻴﺰي  ﻣﻜﺘﻮب  ده  اﻟﻤﻠﻒ:  ﺑﺎﻟﻌﺮﺑﻲ  ﻣﻼﺣﻈﺔ
ﻋﻠﻰ  ﺑﺘﺠﺮّﺑﻬﺎ  ﻗﺒﻮل  اﺧﺘﺒﺎرات  ﻟﻴﻬﺎ  ﺟﻮﻟﺔ  وﻛﻞ  ﻟﺠﻮﻻت،  ﻣﻘﺴّﻢ  اﻟﺸﻐﻞ.  واﻟﺈﻧﺠﻠﻴﺰي  ﺑﺎﻟﻌﺮﺑﻲ  ﺟﻮاه  اﻟﻮاﺟﻬﺔ
.اﻟﺸﺎت  ﻓﻲ  اﺳﺄﻟﻨﻲ  واﺿﺤﺔ،  ﻣﺶ  ﺣﺎﺟﺔ  أي  ﻟﻮ.  ﻧﻜﻤﻞ  ﻣﺎ  ﻗﺒﻞ  ﻣﻮﺑﺎﻳﻠﻚ
0. Instructions to the AI coding agent (read first)
1. SPEC.md stays the reference for everything already built. This document adds change
requests and new modules. If the two conflict, this document wins.
2. The owner is NOT a programmer. Talk to him in simple Egyptian Arabic. Give every
action he must take as short numbered steps.
3. Work in the rounds of section 3, one round at a time. At the end of a round: run all
tests, update README.md, CHANGELOG.md and DECISIONS.md, commit, tag
(round-0, round-1...), let CI build the APK, give a plain-Arabic test checklist for that
round, and wait for approval.
4. Do not start the next round and do not add features outside the current round. If
something is unclear, or you want a different approach, stop and ask first with 2 or 3
options and a recommendation.
5. Never wipe or reset user data. Every database change is a NEW Drift migration with a
test that migrates a copy of the previous schema filled with sample data.
6. Before the owner installs any new build he exports a backup. Each round summary
must say whether the new APK installs over the previous one (same signing key) and
warn him if it does not.
7. All coding rules of SPEC.md section 10 still apply (ARB strings, theme tokens, pure-
Dart services with unit tests, accessibility, performance). The cross-cutting rules of
section 13 of this document apply from Round 1.
8. Be honest about what you could not test on a real device (alarms, notifications, Xiaomi
behavior). Never claim a feature works on his phone unless it was verified.
9. The release manifest must keep having no INTERNET permission. Do not add
networking, analytics or ads libraries.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 1 of 18

---

# Page 2

1. Current state (facts from inspecting the owner's APK on 4 Nov
2026)
Package com.enjaz.app, app name إﻧﺠﺎز ,version 1.0.0 (1), minSdk 24, targetSdk 34,
compileSdk 36, about 79 MB because it carries three CPU architectures.
Built and present: Today, quick add, status sheet, task details, history, reasons
manager, trash, goals and goal details, ideas and idea details, stats, Excel export,
backup (.zip), voice notes (recorder and player), recurrence, reminders, app lock,
settings.
Permissions: RECORD_AUDIO, POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM,
USE_EXACT_ALARM, USE_BIOMETRIC, USE_FINGERPRINT, VIBRATE,
RECEIVE_BOOT_COMPLETED, ACCESS_NETWORK_STATE. There is no INTERNET
permission and no networking library. Keep it that way.
Signed with an auto-generated Android Debug certificate (SHA-256
87ef1b3a36974ca02464379bee4166309fa58a0763c390d416673b0ce087ddae, created
2026-11-03). It is probably regenerated on every CI run, which would block installing a
newer APK over an older one.
The backup screen says the file is encrypted with SHA-256, but no encryption library
exists in the app. SHA-256 is a checksum, not encryption.
Problems the owner reported after testing on his Xiaomi phone:
1. Task reminders appear only as a silent notification in the shade, with no sound.
2. After saving a task, its reminder and the reminder's repeat cannot be edited. Other
fields (name, voice notes, execution time) are not editable after saving either.
3. Notification and alert times cannot be changed freely.
4. The exported Excel report is empty.
5. Delete offers only 'delete task': no clear confirmation and no permanent delete.
6. Numerals are inconsistent on Today (Arabic-Indic date and counter, Western digits
elsewhere).
7. A 'Management' card (Reasons manager, Trash) sits on the Today screen. SPEC.md
puts it in Settings.
8. Quick add on the Goal tab shows task fields (today / tomorrow chips, time, priority)
instead of the goal form.
9. Some user-visible texts are in English or mixed.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 2 of 18

---

# Page 3

2. Decisions made by the owner
3. Rounds overview
Topic Decision
Delete Confirmation before moving anything to the trash.
In the trash: restore, permanent delete of one item
(with confirmation), empty trash (with
confirmation).
Task and errand reminders Alarm style: a continuous alarm sound until the
owner acts. NOT full screen. Morning summary,
evening review and weekly report stay normal
notifications with a sound.
Excel report Add a dashboard sheet with chart images that look
like the app.
Build order after the fixes Habits and notes first.
Finance Record income as well and analyze savings.
Navigation Fewer bottom tabs, everything else in a More
menu.
Privacy App lock with the phone PIN, pattern or
fingerprint.
General Arabic + English, both themes, Western digits by
default.
Round Content Depends on
0 Safety and housekeeping: signing, backup text,
numerals, misplaced screens, language cleanup
—
1 Tasks: edit after save, shared reminder system,
alarm style, reminder times, delete and trash, bulk
select
0
2 Excel: fix the empty report, dashboard sheet with
chart images
1
3 New navigation, Notes, reminders for goals and
ideas, encrypted backup, app lock review
1
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 3 of 18

---

# Page 4

Each round must leave the app working and installable. The owner may pause after any
round.
4. Round 0 — Safety and housekeeping
0.1 Signing. Create a fixed release keystore and store it in GitHub Secrets (never commit
it). CI signs the release APK with it. Document in README.md how the owner keeps two
offline copies of the keystore and its password. Bump versionName and versionCode on
every build (1.0.1 (2), 1.0.2 (3)...) so Android accepts updates. The first build with the new
key will NOT install over the debug-signed build: tell the owner to export a backup, install
the new build, then import the backup.
0.2 Smaller builds. CI produces one APK per CPU architecture (arm64-v8a is the main one
for modern phones) instead of one 79 MB universal APK.
0.3 Backup wording. Replace any text claiming the file is encrypted. Use: 'ﻓﻴﻪ  ﻣﻀﻐﻮط  ﻣﻠﻒ
ﺳﻠﻴﻢ  إﻧﻪ  ﻟﻠﺘﺄﻛﺪ  ﺗﺤﻘﻖ  ﺑﺼﻤﺔ  ﻣﻊ  وﺗﺴﺠﻴﻼت،  ﺑﻴﺎﻧﺎت / Compressed file with a checksum for
integrity'. Real encryption comes in Round 3.
0.4 Numerals. Every number and date goes through the shared formatter and follows the
numerals setting (default Western). Fix the Today header, counters and chips.
0.5 Misplaced entries. Move 'اﻟﺘﺄﺟﻴﻞ  أﺳﺒﺎب  إدارة 'and 'اﻟﻤﺤﺬوﻓﺎت  ﺳﻠﺔ 'from the Today screen
into Settings under a 'اﻟﺈدارة / Management' section.
0.6 Quick add forms. The Goal tab shows the goal form (title, optional description,
optional target date). The Idea tab shows the idea form (title, optional description, tags).
The 'import notes' button appears only on the Task and Errand tabs.
0.7 Language cleanup. No hardcoded text. Remove stray English from Arabic mode
(examples found: Task Reminders, Weekly Report, Daily Summary & Review, Selected file
does not exist). Bilingual labels follow SPEC.md section 3.
Round Content Depends on
4 Habits 3
5 Finance: expenses, income, wishlist, obligations,
analysis
3
6 Health: checkups, appointments, treatments 3
7 Calendar and life timeline, overview dashboard,
expanded Excel
4, 5, 6
8 Release preparation (only when the owner asks) 7
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 4 of 18

---

# Page 5

Done when: a new release APK installs, shows the correct goal form, consistent digits,
and Management inside Settings, and the README explains the signing setup.
5. Round 1 — Tasks: editing, reminders, alarm, delete, bulk select
1.1 Edit after save. In Task details every field is editable after saving: title, kind, notes, date,
time, priority, location, goal link, started and finished times, reminders (type and time),
recurrence, and voice notes (add, rename, delete; re-record = add a new one and delete
the old one). Use an explicit 'ﺣﻔﻆ / Save' button and ask before leaving with unsaved
changes. Recurring tasks keep the 'this one only / all future' choice.
1.2 Shared reminder system. Create a reminders table used by tasks now and by goals,
ideas, habits, obligations and health later: id, owner_type (task | goal | idea | habit |
obligation | health_item | treatment), owner_id, kind (notification | alarm), trigger
(offset_minutes before the due moment, or an absolute date-time), message (nullable,
default = item title), enabled, and the common columns. Migrate the existing task
reminders into it with a tested migration. One ReminderScheduler service owns all
scheduling. Rules:
On any edit: cancel the old schedule, create the new one. No stale notification may
fire at the old time.
On delete or trash: cancel. On restore: schedule again.
On done: cancel the remaining reminders of that task. On postpone: reschedule
relative to the new date.
After reboot, app update, timezone change or backup restore: reschedule everything.
Up to 3 reminders per item. Options: at the time, 10 minutes, 30 minutes, 1 hour or 1
day before, or a custom date-time.
Unit tests: edit the time and verify exactly one notification at the new time; delete
and verify none remains.
1.3 Reminder type per item. Each reminder is either 'إﺷﻌﺎر / Notification' or 'ﻣﻨﺒﻪ / Alarm'.
The default type is set in Settings (default: Alarm for items that have a time, Notification
for date-only items).
1.4 Alarm behavior (not full screen).
A dedicated notification channel for alarms with maximum importance, alarm audio
attributes (USAGE_ALARM), the system default alarm sound, vibration, alarm
category, ongoing so it is not swiped away by accident, and the insistent flag so the
sound repeats until the owner acts.
Automatically stops after N minutes (default 5, setting 1–30).
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 5 of 18

---

# Page 6

Action buttons: 'ﺗﻤﺖ / Done', 'ﺗﺄﺟﻴﻞ / Snooze' (default 10 minutes, setting), 'إﻳﻘﺎف / Stop'.
Tapping the body opens the item and stops the sound.
No full-screen intent and no USE_FULL_SCREEN_INTENT permission. Review
USE_EXACT_ALARM and SCHEDULE_EXACT_ALARM: use
SCHEDULE_EXACT_ALARM with a runtime check and a shortcut to the system
setting, and explain the choice in DECISIONS.md.
Android fixes a channel's importance and sound after it is created. Create NEW
channel ids (for example enjaz_alarm_v2 and enjaz_reminders_v2) and delete the old
channels.
Normal notifications (summaries, weekly report, Notification-type reminders) use a
separate channel with high importance, sound and vibration so they show on screen
with a sound.
If this approach proves unreliable on the owner's phone, propose a foreground-
service alternative and ask before building it.
1.5 Reminder health check. Settings > Reminders > 'اﻟﺘﻨﺒﻴﻬﺎت  ﻓﺤﺺ / Reminder check':
shows the status of the notification permission, the exact-alarm permission, whether the
channels are enabled and not muted, and battery optimization. Each row has a button that
opens the matching system screen. Add short Arabic guidance for Xiaomi
(MIUI/HyperOS): autostart on, battery 'No restrictions', show on lock screen, pop-up
notifications. Add a 'ﺛﻮاﻧﻲ  10 ﺑﻌﺪ  اﻟﻤﻨﺒﻪ  اﺧﺘﺒﺎر / Test alarm in 10 seconds' button.
1.6 Editable times in Settings. Time pickers, with immediate rescheduling, for: morning
summary (default 08:00, on/off), evening review (21:00, on/off), weekly Excel report
reminder (Friday 18:00, on/off), default time for date-only reminders (09:00), snooze
length, alarm auto-stop time.
1.7 Delete and trash.
Deleting any task, errand, goal or idea asks 'ﻣﺘﺄﻛﺪ؟  أﻧﺖ  ﻫﻞ / Are you sure?' and then
moves it to the trash with an 8-second undo.
Trash screen: restore, 'ﻧﻬﺎﺋﻲ  ﺣﺬف / Delete permanently' for one item (with
confirmation), 'اﻟﺴﻠﺔ  ﺗﻔﺮﻳﻎ / Empty trash' (with confirmation). Permanent deletion also
removes the item's voice files and its reminders.
Items stay in the trash for 30 days, then are purged.
1.8 Bulk select. Long-press a card to enter selection mode: a checkbox on each card, the
top bar shows the number selected and 'اﻟﻜﻞ  ﺗﺤﺪﻳﺪ / Select all'. Actions: delete (with
confirmation, goes to trash), mark done, change status (opens the status sheet; the same
reason applies to all), move to a date. Works on Today, History and the Inbox list. Undo
restores the whole batch. Back exits selection mode.
Done when: all Round 1 acceptance tests in section 14 pass.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 6 of 18

---

# Page 7

6. Round 2 — Excel report: fix and dashboard sheet
2.1 Fix the empty report. Reproduce it, find the root cause, write it in DECISIONS.md, and
add a unit test with a sample dataset (completed, postponed, partial and undated tasks)
for week, month, year and all-time ranges. The 'no data' message appears only when the
range is truly empty. Check that queries use the right fields (due date, created date,
finished events).
2.2 Dashboard sheet. A first sheet named 'اﻟﻤﺘﺎﺑﻌﺔ  ﻟﻮﺣﺔ / Dashboard' with: KPI cells
(completed, completion rate, postponed, partial, average duration, streak); chart images
rendered off-screen with the same chart widgets, colors and Cairo font as the Stats
screen (bar chart of completed tasks over time, donut of status distribution, top
postponement reasons, most productive weekday); and a table of highlights. Images are
PNG at 2x resolution on a light background so they read well in Excel and Google Sheets.
The sheet is right-to-left when the app language is Arabic.
2.3 Library check. Confirm the xlsx library in use can embed images. If not, choose a
maintained library with a permissive license or write the minimal drawing XML, and record
the decision. Do not add a library whose license restricts the owner's use without asking
him first.
2.4 Unchanged. The other sheets and rules of SPEC.md section 15 stay as they are.
Numbers inside the file are Western digits.
Done when: the exported file is not empty, opens in Excel and Google Sheets with the
dashboard sheet first, and its numbers match the Stats screen.
7. Round 3 — Navigation, Notes, goal and idea reminders,
encrypted backup
3.1 New navigation. Bottom bar with 4 tabs:
 .1.Today / اﻟﻴﻮم
. 2Notes. The '+' / ﻣﻼﺣﻈﺎت,  Ideas / أﻓﻜﺎر,  Goals / أﻫﺪاف  Plan: a segmented control / اﻟﺘﺨﻄﻴﻂ
.button adds an item of the selected segment
 .3Stats. A calendar icon in its top bar opens the Timeline (hidden until Round / اﻟﺈﺣﺼﺎﺋﻴﺎت
.7)
 .4ﺳﻠﺔ,  History / اﻟﺴﺠﻞ,  اﻟﺰﻣﻨﻲ  واﻟﺴﺠﻞ  اﻟﺘﻘﻮﻳﻢ,  اﻟﺼﺤﺔ,  اﻟﻤﺎل,  اﻟﻌﺎدات  More: a list with / اﻟﻤﺰﻳﺪ
Entries for modules that are not built yet stay hidden, not . اﻟﺈﻋﺪادات,  اﻟﻤﺤﺬوﻓﺎت
.disabled
3.2 Notes (ﻣﻼﺣﻈﺎت.) Notes that are not tasks or ideas: daily notes, information, wisdom,
quotes, things to remember.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 7 of 18

---

# Page 8

Table notes: title (optional), body, kind (note | quote | info → / اﻗﺘﺒﺎس  أو  ﺣﻜﻤﺔ /  ﻣﻼﺣﻈﺔ
ﻣﻌﻠﻮﻣﺔ ,)color (optional), pinned, note_date (the day it belongs to, default today,
editable), tags (reuse tags), and the common columns.
Notes list: pinned first, search, tag and kind filters, newest first.
Add note sheet: multi-line body, kind chips, tags, and a mic button. A note can be
voice-only; it gets an automatic title with its date and time. Voice notes get
parent_type 'note' (SPEC.md section 14 applies).
Convert a note to a task or an idea. Delete goes to the trash. A quick 'اﻟﻴﻮم  ﻣﻼﺣﻈﺔ/ 
Note of the day' action sits in the Plan tab.
3.3 Reminders for goals and ideas. Use the shared reminder system of Round 1. Each goal
or idea can have reminders with a type (notification or alarm) and a custom message text.
For goals, offer 'at the target date' and 'at a milestone due date'. For ideas, a one-time
'دي  ﺑﺎﻟﻔﻜﺮة  ذﻛﺮﻧﻲ / Remind me about this idea'.
3.4 Encrypted backup.
Export offers '( ﺑﻬﺎ  ﻣﻮﺻﻰ ) ﺳﺮ  ﺑﻜﻠﻤﺔ  ﻣﺸﻔﺮة / Password-encrypted (recommended)', ON
by default.
Use an audited, widely used cryptography library: AES-256-GCM with a key derived
from the password using PBKDF2 or Argon2. No home-made cryptography. The file
format has a version, salt and nonce, and the encrypted container includes the voice
files. Keep the SHA-256 manifest inside for integrity checks.
Import detects an encrypted file and asks for the password. A wrong password shows
a clear message, never a crash. The password is never stored. Warn: a lost password
means the backup cannot be recovered.
Unencrypted export stays available behind a warning.
3.5 App lock review. Use the phone's own credential: local_auth with device-credential
fallback (PIN, pattern or password) in addition to fingerprint. Settings: lock on start, and
after a background timeout (immediately, 30 seconds, 1 minute, 5 minutes). Hide the app
content in the recent-apps screen. If the phone has no screen lock set, show guidance.
Add 'اﻟﻘﻔﻞ  ﺷﺎﺷﺔ  ﻋﻠﻰ  اﻟﺘﻨﺒﻴﻬﺎت  ﺗﻔﺎﺻﻴﻞ  إﺧﻔﺎء / Hide notification details on the lock screen', ON
by default for finance and health reminders.
Done when: the Round 3 acceptance tests in section 14 pass and a backup made with a
password restores correctly.
8. Round 4 — Habits (اﻟﻌﺎدات)
4.1 Habit types. The owner writes his own habits. Four types:
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 8 of 18

---

# Page 9

count (ﻋﺪّاد+ :)1 per tap, for example cups of coffee. Each tap stores its own
timestamp.
check (ﻟﺴﻪ /  ﺗﻤّﺖ :)done or not done for the day.
amount (ﻛﻤﻴﺔ :)a number with a unit chosen by the owner (pages, minutes, ml...).
checklist (ﻗﺎﺋﻤﺔ :)several named items per day, for example the five prayers. Every
habit has: name, type, unit (amount and count), optional daily target, icon, color, days
of the week (default every day), and optional reminders through the shared reminder
system.
4.2 Data.
habits: name_ar, name_en (nullable), type, unit (nullable), daily_target (nullable), icon,
color, schedule_days (bitmask, default all days), builtin_key (nullable), sort_order,
archived, and the common columns.
habit_items (checklist items): habit_id, name, sort_order.
habit_logs: habit_id, log_date (local YYYY-MM-DD), value (1 per count tap, the entered
number for amount), at (epoch ms), note (nullable).
habit_item_logs: habit_id, item_id, log_date, done_at.
Index (habit_id, log_date). Deleting a habit moves it and its logs to the trash together.
4.3 Suggested habits (one tap to add, fully editable).
. ﻛﻮب  Coffee — count, unit / ﻗﻬﻮة
.اﻟﻌﺸﺎء  اﻟﻤﻐﺮب،  اﻟﻌﺼﺮ،  اﻟﻈﻬﺮ،  اﻟﻔﺠﺮ،:  Five daily prayers — checklist / اﻟﺨﻤﺲ  اﻟﺼﻠﻮات
the owner may switch it to check or) ﺻﻔﺤﺔ  Quran reading — amount, unit / اﻟﻘﺮآن  ﻗﺮاءة
(.minutes
. اﻟﻤﺴﺎء  أذﻛﺎر  اﻟﺼﺒﺎح،  أذﻛﺎر:  Daily adhkar — checklist / اﻟﺄذﻛﺎر
.ﻛﻮب  Water — count, unit / اﻟﻤﺎء  ﺷﺮب
Exercise — check. The app stores only these labels. It includes no religious / رﻳﺎﺿﺔ
.texts and does not calculate prayer times (not requested)
4.4 UI.
Today: a horizontal habits strip under the date header. One card per habit with the
quick action: +1 (count), tick (check), amount sheet (amount), expand to the
checklist. It shows today's progress against the target when there is one.
More > اﻟﻌﺎدات: list of habits with today's progress; add from the suggestions or
create a custom one; reorder; archive.
Habit details: month heatmap calendar, current and best streak, completion rate for
the week and the month, daily average (count and amount), totals, the log list with
edit and delete, and back-dating through a date picker (editing past days is allowed).
Reminders per habit through the shared reminder system (notification or alarm).
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 9 of 18

---

# Page 10

4.5 Rules (pure Dart service with unit tests). A scheduled day is a day in schedule_days.
A scheduled day is complete when: check → logged; count and amount → value is at least
the target if a target exists, otherwise greater than zero; checklist → all items done. Streak
= consecutive complete scheduled days ending today (or yesterday while today is not
complete yet). Missed = a past scheduled day that is not complete.
4.6 Stats tab 'ﻋﺎدات.' Completion rate per habit for the selected range, streaks, heatmap,
most consistent and most missed habits, and for count habits a line chart of the daily total
(for example cups of coffee per day).
4.7 Timeline. Every habit log exposes its time (at) for Round 7.
Done when: the Round 4 acceptance tests in section 14 pass.
9. Round 5 — Finance (اﻟﻤﺎل)
5.1 Scope and privacy. Manual entry only: no bank connection and no reading of SMS or
notifications. One currency (default EGP, set in Settings). Amounts are stored as integers
in minor units (piasters) to avoid rounding errors. Finance is a sensitive module (section
13): covered by the app lock, notification details hidden on the lock screen, and an eye
icon that masks every amount on screen.
5.2 Data.
finance_categories: name_ar, name_en, kind (expense | income), nature (essential |
side | none) as the category default, icon, color, is_default, archived, sort_order.
Seed expense categories: وﻗﻬﻮة  ﺷﺎي( side), ﺑﺮه  ﻣﻦ  أﻛﻞ( side), اﻟﺒﻴﺖ  وأﻛﻞ  ﺑﻘﺎﻟﺔ
(essential), وﺑﻨﺰﻳﻦ  ﻣﻮاﺻﻼت( essential), ﻓﻮاﺗﻴﺮ( essential), وإﻳﺠﺎر  ﺳﻜﻦ( essential),
وإﻧﺘﺮﻧﺖ  اﺗﺼﺎﻻت( essential), وﺻﺤﺔ  ﻋﻼج( essential), ﺗﻌﻠﻴﻢ( essential), وﻣﻌﺪات  ﺷﻐﻞ
(essential), ﺗﺮﻓﻴﻪ( side), ﻣﻼﺑﺲ( side), وﻣﺠﺎﻣﻼت  ﻫﺪاﻳﺎ( side), واﻟﺘﺰاﻣﺎت  أﻗﺴﺎط
(essential), أﺧﺮى( side).
Seed income categories: أﺧﺮى  راﺗﺐ،  وﻋﻤﻼء،  ﺷﻐﻞ.
The owner can add, edit and archive categories.
transactions: kind (expense | income), amount_minor, category_id, nature (essential |
side; copied from the category and editable per entry), occurred_at, local_date, note
(nullable), payment_method (cash | card | wallet, nullable), obligation_instance_id
(nullable), wishlist_item_id (nullable).
quick_expenses (favorites for one-tap entry): label, category_id,
default_amount_minor, nature, sort_order.
wishlist_items: name, estimated_price_minor, priority (low | normal | high), status
(wanted | planned | bought | dropped), target_date (nullable), note, bought_at,
bought_price_minor, transaction_id.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 10 of 18

---

# Page 11

obligations: name, kind (bill | installment | debt | subscription | other), amount_minor,
frequency (once | weekly | monthly | yearly), due_day or due_date, start_date,
end_date or installments_total, counterpart (nullable text), note.
obligation_instances: obligation_id, due_date, amount_minor, status (pending | paid |
skipped), paid_at, paid_amount_minor, transaction_id. Generated for the next 3
months like recurring tasks. An instance is LATE when its due_date is before today
and its status is pending.
budgets: category_id (null = overall), month (YYYY-MM, or recurring monthly),
limit_minor.
5.3 UI (More > اﻟﻤﺎل.)
Summary card for the selected month: income, expenses, saved (income minus
expenses), savings rate.
Four segments: اﻟﻤﻌﺎﻣﻼت / Transactions (grouped by day, filters by category, nature
and date), اﻟﻤﺸﺘﺮﻳﺎت / Wishlist, اﻻﻟﺘﺰاﻣﺎت / Obligations, اﻟﺘﺤﻠﻴﻞ / Analysis.
The FAB adds an expense. A toggle in the sheet switches to income. Add sheet: big
amount keypad, category chips, essential / side switch, date and time (default now),
note. At the top, a quick favorites row: one tap saves the expense with its default
amount (long-press to edit the amount or the favorites). Undo snackbar after every
save. Speed matters: the common case (tea, coffee) must take one tap.
Wishlist: item cards with price, priority and status. 'اﺷﺘﺮﻳﺘﻬﺎ / I bought it' creates the
expense and marks the item bought. The segment shows the total of wanted and
planned items and an estimate '≈ N ادﺧﺎرك  ﻣﺘﻮﺳﻂ  ﻣﻦ  ﺷﻬﻮر( 'total divided by the
average monthly savings of the last 3 months), clearly labeled as an estimate and
hidden when savings are zero or negative.
Obligations: grouped into ﻣﺘﺄﺧﺮة / Late, ﻗﺮﻳﺒﺔ / Due soon, ﻗﺎدﻣﺔ / Upcoming, ﻣﺪﻓﻮﻋﺔ/ 
Paid. 'اﻟﺪﻓﻊ  ﺗﻢ / Paid' optionally creates the expense. Reminders N days before the due
date through the shared reminder system (notification or alarm).
5.4 Analysis (pure Dart service with unit tests; same range control as Stats).
Totals: income, expenses, savings, savings rate (show 'ﻣﺘﺎح  ﻏﻴﺮ 'when income is zero).
Essential vs side share, in amount and percent.
Top 5 categories with amount and percent, daily average spending, comparison with
the previous period (amount and percent), spending by weekday, the 5 biggest single
expenses.
'ﻣﺘﻜﺮرة  ﺻﻐﻴﺮة  ﻣﺼﺮوﻓﺎت / Small recurring spending': categories with at least 10 entries
in the month and a small average amount, with their monthly total. This answers 'what
do I waste money on'.
Budget progress for categories that have a budget.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 11 of 18

---

# Page 12

Obligations: late count and amount, and the on-time payment rate (paid on or before
the due date, out of all due in the range).
Wishlist: total of wanted and planned items.
Wording stays neutral and factual. No financial advice.
5.5 Excel and CSV. Extend the report with the sheets Transactions, Obligations, Wishlist
and Finance summary (category totals), and add transactions.csv to the CSV export.
Numbers in Western digits.
5.6 Stats tab 'ﻣﺎل.' Charts: spending by category, essential vs side, daily spending over
time, income vs expenses per month, savings rate trend.
5.7 Timeline. Transactions, obligation payments and due dates expose their time for
Round 7.
Done when: the Round 5 acceptance tests in section 14 pass.
10. Round 6 — Health (اﻟﺼﺤﺔ)
6.1 Scope. The module tracks checkups, tests, appointments and treatment follow-
through, and reminds the owner. It gives no diagnosis and no medical advice. Show once
on the screen: 'اﻟﻄﺒﻴﺐ  ﻋﻦ  ﻳﻐﻨﻲ  وﻻ  ﻓﻘﻂ  واﻟﺘﺬﻛﻴﺮ  ﻟﻠﻤﺘﺎﺑﻌﺔ  اﻟﺘﻄﺒﻴﻖ / For tracking and reminders
only; it does not replace a doctor'. Health is a sensitive module (section 13): app lock,
notification details hidden by default, and content hidden in the recent-apps screen.
6.2 Data.
health_items: title (typed by the owner, for example the name of a test or visit), kind
(checkup | test | specialist | dental | vaccination | other → | أﺳﻨﺎن  | ﻛﺸﻒ  | ﺗﺤﻠﻴﻞ  | ﻓﺤﺺ
أﺧﺮى  | ﺗﻄﻌﻴﻢ ,)status (needed | scheduled | postponed | done | skipped), needed_since
(date, default today), due_by (nullable), scheduled_at (nullable), place_or_doctor
(nullable text), done_at, result_note (nullable), follow_up_needed (bool),
postpone_count, postponed_reason (nullable), repeat_every_months (nullable, for
yearly checkups and similar), cost_minor (nullable, optionally creates a finance
expense).
health_events (append-only history like task events): health_item_id, at, from_status,
to_status, note.
treatments: health_item_id (nullable), name (as the owner enters it),
instructions_note (free text), start_date, end_date (nullable), purchased (bool),
purchased_at, purchase_cost_minor (nullable, optionally an expense), adherence
(not_started | following | stopped | completed), stopped_reason, note.
treatment_checks: treatment_id, check_date, taken (bool) — an optional daily tick
'اﻟﻨﻬﺎرده  ﻋﻠﻴﻪ  ﻣﺸﻴﺖ / I followed it today'.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 12 of 18

---

# Page 13

Voice notes may attach to health items (parent_type 'health_item').
6.3 UI (More > اﻟﺼﺤﺔ.)
Segments: اﻟﻤﻄﻠﻮب / To do (needed, scheduled and postponed, sorted by how long
they have been waiting), اﻟﺴﺠﻞ / History (done), اﻟﻌﻼﺟﺎت / Treatments.
Every health item card shows its status chip and 'ﻣﻦ  ﻣﺤﺘﺎج N ﺷﻬﺮ / needed for N
months', so forgotten or postponed items stand out.
Status changes work like tasks: postponed requires a reason; done asks for the date, a
short result note (typed or voice) and whether follow-up is needed. If
repeat_every_months is set, a new 'needed' item is created for the next due date.
Treatment cards: purchased yes or no, adherence status, optional dose-time
reminders (shared reminder system) and the daily tick with an adherence
percentage.
Appointment reminders (the day before and at the time) through the shared reminder
system (notification or alarm).
6.4 Stats tab 'ﺻﺤﺔ.' Counts by status, the longest-waiting items, upcoming appointments,
treatment adherence percentage, and checkups done this year.
6.5 Timeline. Health events and appointments expose their time for Round 7.
Done when: the Round 6 acceptance tests in section 14 pass.
11. Round 7 — Calendar and life timeline (اﻟﺰﻣﻨﻲ  واﻟﺴﺠﻞ  اﻟﺘﻘﻮﻳﻢ)
7.1 Entry points. A calendar icon in the Stats top bar and More > اﻟﺰﻣﻨﻲ  واﻟﺴﺠﻞ  اﻟﺘﻘﻮﻳﻢ.
Range: 1 Jan 2026 to 31 Dec 2046 (one constant, easy to extend). A 'اﻟﻴﻮم / Today' button
jumps to today.
7.2 Views. Year, Month, Week, Day.
Year: 12 month tiles shaded by activity density.
Month: a grid with small colored dots per day, one color per module; swipe between
months; year and month pickers.
Week: 7 days with counts per module; tap a day to open it.
Day: the full timeline (7.3).
7.3 Day view. The header shows the day's totals (tasks done, expenses and income, habits
completed, notes written, ideas created). Below it, a chronological timeline with hour
markers. Items without a time sit at the top as 'اﻟﻴﻮم  ﻃﻮال / All day'. Entries (each opens its
source item): task events (created, started, done, postponed with the reason), tasks and
errands scheduled that day and their final state, notes written that day, ideas created,
goal progress and completed milestones, habit logs, expenses and income, obligations
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 13 of 18

---

# Page 14

paid or due, health events and appointments, and voice notes (playable inline). Filter chips
per module. Future days show planned items only (tasks due, obligations due,
appointments, reminders).
Week, month and year summaries use the same definitions as the dashboards: tasks
done, top spending category, habit completion, notes count, goal progress, health
items done. A 'اﻟﻔﺘﺮة  ﻫﺬه  ﺗﺼﺪﻳﺮ / Export this period' button runs the Excel export for
that range.
7.4 Architecture.
Each module implements TimelineSource: entriesForRange(range) returns
TimelineEntry objects (id, module, occurredAt, allDay, title, subtitle, icon, color,
hasVoice, deepLink), and countsForRange(range) returns counts per local day. A
TimelineAggregator merges the sources. No data is copied into a separate log table.
Every table that can appear in the timeline has an indexed occurred_at (UTC epoch
ms) and local_date (local YYYY-MM-DD). local_date is computed when the record is
written and recomputed only if occurred_at is edited.
A day is the device's local calendar day. Document how a timezone change is handled.
Editing the time of a past event moves it on the timeline: it shows when something
happened, not when it was saved.
Performance target: the month view opens in under 500 ms and a day in under 300 ms
with 5 years of data (around 20,000 entries). Use SQL group-by for month counts and
pagination for long days.
7.5 Overview dashboard. Stats gets an 'ﻋﺎﻣﺔ  ﻧﻈﺮة / Overview' tab combining the headline
numbers of all modules for the selected range.
7.6 Excel expansion. Add the sheets Habits (daily logs and completion), Notes (date, kind,
title, body, tags) and Health (items, events, treatments), and extend the Dashboard sheet
with chart images for habits, finance and health.
7.7 Long-term safety. The timeline is a memory archive, so: every migration is tested, a
monthly backup reminder is ON by default from this round, a storage monitor shows how
much space voice files use (they can reach hundreds of MB over years), and nothing is
purged automatically except the trash.
Done when: the Round 7 acceptance tests in section 14 pass.
12. Round 8 — Release preparation (only when the owner asks)
Do not start this round without his instruction. Scope: prepare for Google Play (iOS only if
he asks later).
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 14 of 18

---

# Page 15

Decide the final applicationId. It can never change after publishing. Changing it from
com.enjaz.app makes the current phone install a different app, so move the data with
backup and restore.
Final app name, icon, and store listing texts and screenshots in Arabic and English.
Build a signed Android App Bundle (.aab) with the release key and enroll in Play App
Signing.
Raise targetSdk to the level Google Play requires at that time and review the
permissions (exact alarms, notifications, microphone, biometric) with a short
justification for each.
Privacy policy page (it can be hosted on GitHub Pages) and the Data safety form
answers: data stays on the device, no INTERNET permission, no ads, no analytics.
Check the declarations needed for the health and finance features.
A personal Play developer account needs a closed test with at least 12 testers for 14
days before production access. Verify the current rule at that time.
If ads or a paid tier are considered later, write down the privacy and design impact
first (ads need the INTERNET permission and consent handling; subscriptions use
Google Play Billing). Ask the owner before any such change.
13. Cross-cutting rules (apply from Round 1)
1. Time model. Every record that can appear in history has occurred_at (UTC epoch ms)
and local_date (local YYYY-MM-DD).
2. Soft delete. Every module uses soft delete and the shared trash (30 days). Permanent
deletion cascades: voice files are removed and reminders are cancelled.
3. Shared reminders. All reminders go through the reminders table and the
ReminderScheduler of Round 1.
4. Voice notes. parent_type values: task, idea, goal, note, health_item.
5. Sensitive modules: notes, finance, health and voice notes. They are covered by the
app lock, hidden in the recent-apps screen, use private notification visibility with
details hidden by default, and finance has the eye icon to mask amounts. Backups
containing them are encrypted by default from Round 3.
6. Money. Integer minor units, one currency setting, one money formatter that respects
the numerals setting.
7. Consistency. Shared widgets for status chips, cards, empty states and sheets. No
module invents its own look.
8. Scale. The data horizon is 20 years. Index the columns used for date and status
queries, paginate long lists, and run exports and heavy aggregates in background
isolates.
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 15 of 18

---

# Page 16

9. Migrations. Every round that touches the schema adds a migration test from the
previous version with sample data.
10. No networking, no ads. The release manifest keeps no INTERNET permission.
11. Honesty about devices. Anything that depends on the phone (alarms, notifications
on Xiaomi, biometrics) is listed as 'needs real-device test' in the round summary.
14. Acceptance tests by round
Round 0
1. A new release APK is signed with the fixed key, and a second build with a higher
version installs over it with the data intact.
2. The Goal tab in quick add shows the goal form, Management is inside Settings, and
digits are consistent.
3. The backup screen no longer claims encryption.
Round 1
1. Create a task with a reminder, close and reopen the app, change its time and its
repeat, and verify that exactly one notification fires at the new time.
2. Title, kind, date, time, location, reminders and voice notes can all be edited after
saving.
3. An alarm-type reminder rings continuously with the screen locked until Done, Snooze
or Stop is pressed (test on the owner's phone), and stops by itself after the timeout.
4. A notification-type reminder shows on screen with a sound.
5. The Reminder check screen reports the permission and channel status, and its 'test
alarm in 10 seconds' button works.
6. Each time in Settings (morning summary, evening review, weekly report, default time,
snooze, timeout) can be changed and takes effect without restarting the app.
7. Delete asks for confirmation and moves the item to the trash. Restore works.
Permanent delete and empty trash ask for confirmation and remove the voice files.
8. Long-press selects several tasks. Bulk delete, bulk done and bulk move work, and
undo restores the whole batch.
Round 2
1. The exported report is not empty for week, month, year and all time.
2. The Dashboard sheet comes first, has KPI cells and four chart images, and its numbers
equal the Stats screen.
3. The file opens in Excel and Google Sheets with correct Arabic and right-to-left layout.
Round 3
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 16 of 18

---

# Page 17

1. The bottom bar has 4 tabs and everything else is reachable from More.
2. A text note and a voice-only note can be saved, searched, filtered, converted to a task
and deleted.
3. A goal and an idea each get a reminder with a custom message, as a notification and
as an alarm.
4. A backup made with a password restores correctly, a wrong password shows a clear
message, and the unencrypted option shows a warning.
5. The app unlocks with the phone PIN or pattern as well as the fingerprint, and the
recent-apps screen hides the content.
Round 4
1. A custom habit of each type can be created and the suggested ones can be added.
2. One tap on the Today strip counts a coffee and the log keeps its time.
3. The five-prayers and adhkar checklists complete correctly, and streaks and missed
days match a manual count.
4. Editing a past day through the date picker updates the heatmap.
5. A habit reminder fires and the Stats tab shows the habit charts.
Round 5
1. A tea expense is saved with one tap from the favorites row, income can be recorded,
and the monthly summary and savings rate match a manual count.
2. Essential vs side shares and top categories are correct on a test dataset of 100
transactions.
3. Marking a wishlist item as bought creates an expense and lowers the wishlist total.
4. An obligation becomes late the day after its due date and shows in the dashboard.
Paying it creates the expense. The on-time rate is correct.
5. The masking eye hides every amount, and lock-screen notifications for finance show
no details.
6. The Excel report contains the finance sheets.
Round 6
1. A checkup can be added as needed, postponed with a reason, scheduled, and marked
done with a result note, and the history shows every step.
2. A repeating checkup creates the next needed item after it is done.
3. A treatment can be marked purchased, followed, stopped with a reason or completed,
and the daily tick feeds the adherence percentage.
4. Appointment reminders fire, and the lock-screen text hides the details by default.
Round 7
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 17 of 18

---

# Page 18

1. The calendar opens on any date from 2026 to 2046 in year, month, week and day
views.
2. A day shows tasks, notes, ideas, habits, expenses, obligations, health events and
playable voice notes in time order, and each entry opens its source.
3. Week, month and year summaries match the dashboards for the same range.
4. With a 5-year test dataset the month view opens in under 500 ms.
5. The extended Excel report opens correctly and includes the new sheets and charts.
15. Risks and open items
Alarm-style reminders depend on Xiaomi settings and cannot be verified without the
owner's phone. If they prove unreliable, the fallback is a foreground service (ask
before building it).
Rounds 4 to 7 are large. The owner may stop after any round, and each round leaves a
working app.
The xlsx library may not support images (Round 2). Check first, and ask before adding
a library with a restrictive license.
Health and finance features may need extra declarations on Google Play (Round 8).
Antigravity request limits: keep each prompt to one round or one sub-item, and avoid
broad requests.
Assumptions to confirm: currency EGP, week starts on Saturday, Western digits by
default, the prayers as a five-item checklist, and obligations meaning bills,
installments and debts.
16. Kickoff messages (the owner pastes one per round)
Section to read per round: Round 0 → section 4, Round 1 → 5, Round 2 → 6, Round 3 → 7,
Round 4 → 8, Round 5 → 9, Round 6 → 10, Round 7 → 11, Round 8 → 12 (only on request).
ﻗﺼﻴﺮة  ﺧﻄﺔ  اﻋﻤﻞ.  13و  0 اﻟﻘﺴﻤﻴﻦ  ﻣﻊ  X رﻗﻢ  اﻟﻘﺴﻢ  اﻗﺮأ.  CHANGES.md ﻣﻦ  ﻓﻘﻂ  N ﺟﻮﻟﺔ  اﺑﺪأ
.ﻓﻴﻬﺎ  اﺳﺄﻟﻨﻲ  واﺿﺤﺔ  ﻣﺶ  ﺣﺎﺟﺔ  وأي  ﺗﺎﻧﻴﺔ،  ﺟﻮﻟﺔ  ﺗﺒﺪأش  ﻣﺎ.  ﻧﻔّﺬ  وﺑﻌﺪﻫﺎ  ﻣﻮاﻓﻘﺘﻲ،  واﻧﺘﻈﺮ  أوﻻً  ﺑﺎﻟﻌﺮﺑﻲ
commit اﻋﻤﻞ  ،DECISIONSو  CHANGELOGو  README ﺣﺪّث  اﻻﺧﺘﺒﺎرات،  ﺷﻐّﻞ:  اﻟﺂﺧﺮ  ﻓﻲ
.ﻣﻮﺑﺎﻳﻠﻲ  ﻋﻠﻰ  اﻟﺘﺠﺮﺑﺔ  ﺧﻄﻮات  وادّﻳﻨﻲ  ،tagو
إﻧﺠﺎز | Enjaz — Change Requests and Roadmap v2.0
Page 18 of 18