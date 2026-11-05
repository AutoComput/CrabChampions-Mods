# CancelLockedSlots diagnostics collector
# Copyright (C) 2026 AutoComput
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Zips the mod, UE4SS and game logs for a bug report and puts the zip on your Desktop.
# Your Windows username is replaced with <user> in every text file. Crash dumps
# contain a snapshot of game memory and cannot be redacted, so they are only
# included if you agree. Steam player names in the mod log are not removed.
#
# Usage: double-click CollectDiagnostics.bat (in Mods\CancelLockedSlots\tools).
# Options: -IncludeDumps / -ExcludeDumps skip the question.

param(
    [switch]$IncludeDumps,
    [switch]$ExcludeDumps
)

$ErrorActionPreference = "Stop"
$modName = "CancelLockedSlots"
$textExtensions = @(".log", ".txt", ".ini", ".lua", ".xml", ".json", ".acf")

function Write-Log($level, $message) { Write-Host "[$level] $message" }

# --- Locate folders relative to this script: Mods\CancelLockedSlots\tools ---
$modFolder = Split-Path $PSScriptRoot -Parent
$modsFolder = Split-Path $modFolder -Parent
$ue4ssFolder = Split-Path $modsFolder -Parent
if (-not (Test-Path (Join-Path $ue4ssFolder "UE4SS-settings.ini"))) {
    Write-Log "ERROR" "UE4SS folder not found. Run this from Mods\$modName\tools inside your UE4SS install."
    exit 1
}
$win64Folder = Split-Path $ue4ssFolder -Parent
$gameDataFolder = Join-Path $env:LOCALAPPDATA "CrabChampions\Saved"
$steamAppsFolder = (Get-Item $win64Folder).Parent.Parent.Parent.Parent.Parent.FullName

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stagingFolder = Join-Path $env:TEMP "$modName-diagnostics-$timestamp"
New-Item -ItemType Directory -Path $stagingFolder -Force | Out-Null
foreach ($bundleFolder in @("mod", "ue4ss", "game")) {
    New-Item -ItemType Directory -Path (Join-Path $stagingFolder $bundleFolder) -Force | Out-Null
}
$report = New-Object System.Collections.Generic.List[string]
# Zip entry names, recorded as files are added (no path arithmetic, which breaks on short 8.3 paths).
$bundleEntries = New-Object System.Collections.Generic.List[string]

function Add-FileToBundle($sourcePath, $bundlePath) {
    if (-not (Test-Path $sourcePath)) { $report.Add("missing   $bundlePath"); return }
    $destination = Join-Path $stagingFolder $bundlePath
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    try {
        # Opened with ReadWrite sharing so logs can be copied while the game is running.
        $stream = [System.IO.File]::Open($sourcePath, "Open", "Read", "ReadWrite")
        try {
            $output = [System.IO.File]::Create($destination)
            try { $stream.CopyTo($output) } finally { $output.Dispose() }
        } finally { $stream.Dispose() }
        $report.Add("included  $bundlePath")
        $bundleEntries.Add($bundlePath)
    } catch {
        $report.Add("failed    $bundlePath ($($_.Exception.Message))")
    }
}

function Get-NewestFile($folder, $filter) {
    if (-not (Test-Path $folder)) { return $null }
    return Get-ChildItem $folder -Filter $filter -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

Write-Log "INFO" "Collecting $modName diagnostics"

# --- Mod files ---
Add-FileToBundle (Join-Path $modFolder "$modName.log") "mod/$modName.log"
Add-FileToBundle (Join-Path $modFolder "$modName.previous.log") "mod/$modName.previous.log"
Add-FileToBundle (Join-Path $modFolder "scripts\config.lua") "mod/config.lua"

# --- UE4SS files ---
Add-FileToBundle (Join-Path $ue4ssFolder "UE4SS.log") "ue4ss/UE4SS.log"
Add-FileToBundle (Join-Path $ue4ssFolder "UE4SS-settings.ini") "ue4ss/UE4SS-settings.ini"
Add-FileToBundle (Join-Path $modsFolder "mods.txt") "ue4ss/mods.txt"

# --- Game files ---
# The shipping build usually writes no log; "missing" here is normal.
Add-FileToBundle (Join-Path $gameDataFolder "Logs\CrabChampions.log") "game/CrabChampions.log"
Add-FileToBundle (Join-Path $steamAppsFolder "appmanifest_774801.acf") "game/appmanifest_774801.acf"

# --- Installed mods overview ---
$modsList = Get-ChildItem $modsFolder -Directory | ForEach-Object {
    $enabledFile = if (Test-Path (Join-Path $_.FullName "enabled.txt")) { "enabled.txt" } else { "" }
    "{0,-32} {1}" -f $_.Name, $enabledFile
}
$modsList | Set-Content (Join-Path $stagingFolder "ue4ss/mods-folders.txt") -Encoding UTF8
$report.Add("included  ue4ss/mods-folders.txt")
$bundleEntries.Add("ue4ss/mods-folders.txt")

# --- System info ---
$modVersionMatch = Select-String -Path (Join-Path $modFolder "scripts\main.lua") -Pattern '^local modVersion = "([^"]+)"' -ErrorAction SilentlyContinue
$buildIdMatch = Select-String -Path (Join-Path $steamAppsFolder "appmanifest_774801.acf") -Pattern '"buildid"\s+"(\d+)"' -ErrorAction SilentlyContinue
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$gameRunning = [bool](Get-Process -Name "CrabChampions-Win64-Shipping" -ErrorAction SilentlyContinue)
@(
    "Collected:      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Mod version:    $(if ($modVersionMatch) { $modVersionMatch.Matches[0].Groups[1].Value } else { 'unknown' })",
    "Steam build id: $(if ($buildIdMatch) { $buildIdMatch.Matches[0].Groups[1].Value } else { 'unknown' })",
    "Windows:        $(if ($os) { "$($os.Caption) $($os.Version)" } else { 'unknown' })",
    "Game running:   $gameRunning"
) | Set-Content (Join-Path $stagingFolder "system-info.txt") -Encoding UTF8
$report.Add("included  system-info.txt")
$bundleEntries.Add("system-info.txt")

# --- Crash data (optional) ---
$ue4ssDump = Get-NewestFile $ue4ssFolder "crash_*.dmp"
$gameCrashFolder = if (Test-Path (Join-Path $gameDataFolder "Crashes")) {
    Get-ChildItem (Join-Path $gameDataFolder "Crashes") -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} else { $null }

if ($ue4ssDump -or $gameCrashFolder) {
    $includeCrashData = $IncludeDumps
    if (-not $IncludeDumps -and -not $ExcludeDumps) {
        Write-Host ""
        Write-Host "Crash data was found. It helps diagnose crashes, but crash dumps contain a"
        Write-Host "snapshot of game memory and cannot be redacted."
        $answer = Read-Host "Include crash data? (y/N)"
        $includeCrashData = $answer -match '^(y|yes)$'
    }
    if ($includeCrashData) {
        if ($ue4ssDump) { Add-FileToBundle $ue4ssDump.FullName "crash/ue4ss/$($ue4ssDump.Name)" }
        if ($gameCrashFolder) {
            Get-ChildItem $gameCrashFolder.FullName -File | ForEach-Object {
                Add-FileToBundle $_.FullName "crash/game/$($gameCrashFolder.Name)/$($_.Name)"
            }
        }
    } else {
        $report.Add("skipped   crash data (not included by choice)")
    }
} else {
    $report.Add("none      crash data found")
}

# --- Redact the Windows username from text files ---
$redactions = @($env:USERPROFILE, $env:USERNAME) | Where-Object { $_ } | Sort-Object Length -Descending
Get-ChildItem $stagingFolder -Recurse -File | Where-Object { $textExtensions -contains $_.Extension.ToLower() } | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    $redacted = $content
    foreach ($value in $redactions) {
        $replacement = if ($value -eq $env:USERPROFILE) { "%USERPROFILE%" } else { "<user>" }
        $redacted = [regex]::Replace($redacted, [regex]::Escape($value), $replacement, "IgnoreCase")
    }
    if ($redacted -ne $content) { [System.IO.File]::WriteAllText($_.FullName, $redacted, (New-Object System.Text.UTF8Encoding($false))) }
}

$report | Set-Content (Join-Path $stagingFolder "collection-report.txt") -Encoding UTF8
$bundleEntries.Add("collection-report.txt")

# --- Zip with "/" entry names so every extractor reads it correctly ---
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$desktop = [Environment]::GetFolderPath("Desktop")
$zipPath = Join-Path $desktop "$modName-diagnostics-$timestamp.zip"
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entryName in $bundleEntries) {
        $sourceFile = Join-Path $stagingFolder $entryName
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $sourceFile, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $zip.Dispose()
}
Remove-Item $stagingFolder -Recurse -Force

Write-Host ""
$report | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Log "OK" "Saved $zipPath"
Write-Log "INFO" "Attach this zip to your bug report."