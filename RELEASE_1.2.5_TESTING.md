# Enjaz 1.2.5+2025

Local automated validation: 498 tests passed on Flutter 3.47.9. Static analysis has no errors; existing warnings/style notices remain outside this fix.

Regression coverage: Android notification identity differs from task ID; multiple reminders for one task; legacy notification launch; non-task owners; cold alarm launch while app locked; private content stays hidden; stop releases wake flags; snooze success/failure/retry/inexact warning; startup preserves future snoozes and ringing alarms; explicit edits still replace snoozes.

Device acceptance still required (no Android phone connected):
1. Install over 1.2.4+2024 without uninstalling; confirm version 1.2.5+2025.
2. Create two alarms for one task. Stop one: the other must remain scheduled.
3. Snooze five minutes, close/reopen the app, lock phone, verify it rings again.
4. Enable app lock. Trigger alarm while phone is locked: generic Stop/Snooze controls must work, private content must remain hidden, closing must return to lock.
5. Deny notifications and try snooze: an error must stay visible; restore permission and retry.
6. After stopping, confirm normal screen timeout and device lock behavior return. Verify ringtone/full-screen behavior on the actual Xiaomi/HyperOS device.

APK delivery uses the existing private GitHub Actions signing configuration; no signing key or password is included in source or artifacts.
