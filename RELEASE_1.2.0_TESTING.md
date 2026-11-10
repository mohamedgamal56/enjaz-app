# Enjaz 1.2.0 device acceptance

Local validation: 470 automated tests passed on Flutter 3.47.9. Device checks below remain required; automated tests do not establish microphone accuracy or alarm delivery on a particular phone.

- Install over voice-5 / 1.1.6. For older differently signed builds, uninstall once if package conflict appears (this deletes local data). All future release builds must use the pinned certificate.
- Create a task and a note, install this APK again, and confirm both remain.
- Open assistant from Today, More and the launcher shortcut, including while app lock is enabled.
- Dictate an expense with an amount and a task with date/time. Confirm, cancel, edit, let the confirmation window expire, and try Undo. Verify one saved record per confirmation.
- Stop/start recognition repeatedly and close the sheet while listening. Ensure microphone stops and no command is executed after closing.
- Run the 30 sentence wizard online and in airplane mode with Wi-Fi off. Each group keeps separate results; export both reports. Network state is captured at recording start. Review numbers and dates manually too.
- Test local Arabic speech, stop playback, adjust speed and disable spoken answers. Financial/health speech is off by default. Enable it explicitly and verify masked amounts remain silent.
- Record a voice note and voice idea; play them back. View and clear locally stored unrecognized phrases.
- Schedule a reminder two minutes ahead, test with screen locked, snooze, Done and notification navigation. Repeat after reboot and with a recurring task.
- Enable app lock, close/reopen and launch via notification. Confirm authentication precedes access and notification details are hidden.
- Export a backup including recordings, restore it, and verify tasks, notes, audio and reminders. Test encrypted backup and wrong password. Corrupt or incomplete backups must be rejected without losing existing data.

Known validation limits: Android speech recognition may use the installed system service's network access; offline availability varies by device and installed Arabic language packs. Local Arabic TTS requires a downloaded voice. GitHub Pages preview remains manual because Pages is not enabled on this private repository.
