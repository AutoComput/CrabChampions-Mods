# Changelog

## 1.0.0

- Cancels Locked Slots' effect while it stays selected, so runs keep Prismatic rank and rewards with normal slot counts.
- Restores slots for every player when hosting.
- Optional `config.lua` for settings, kept across updates.
- Startup checks resolve modifier names and slot defaults from the game, and stop the mod with a clear log message if anything is missing.
- Rate-limited error logging, and the mod disables itself after 20 consecutive errors.
- Own log file (`CancelLockedSlots.log`), flushed every line; the previous session is kept as `CancelLockedSlots.previous.log`.
- `tools\CollectDiagnostics.bat` bundles logs for bug reports, redacts the Windows username, and asks before including crash dumps.
- Licensed under GPL-3.0-or-later.
