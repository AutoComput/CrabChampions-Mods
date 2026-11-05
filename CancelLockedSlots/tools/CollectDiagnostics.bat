@echo off
rem Collects logs for a CancelLockedSlots bug report into a zip on your Desktop.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CollectDiagnostics.ps1"
pause
