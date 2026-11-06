# Builds dist\<ModName>-v<version>.zip from this repo.
# Usage: powershell -ExecutionPolicy Bypass -File .\build-release.ps1 -Mod CancelLockedSlots

param(
    [string]$Mod
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

function Write-Log($level, $message) { Write-Host "[$level] $message" }

# A mod is any top-level folder holding scripts\main.lua.
$availableMods = Get-ChildItem $repoRoot -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "scripts\main.lua") } |
    Select-Object -ExpandProperty Name

if (-not $Mod) {
    Write-Log "ERROR" "No mod given. Use -Mod <name>."
    Write-Log "INFO" "Available mods: $($availableMods -join ', ')"
    exit 1
}

if ($availableMods -notcontains $Mod) {
    Write-Log "ERROR" "'$Mod' is not a mod folder in this repo."
    Write-Log "INFO" "Available mods: $($availableMods -join ', ')"
    exit 1
}

$modName = $Mod
$modFolder = Join-Path $repoRoot $modName
$mainLua = Join-Path $modFolder "scripts\main.lua"

$versionMatch = Select-String -Path $mainLua -Pattern '^local modVersion = "([0-9]+\.[0-9]+\.[0-9]+)"'
if (-not $versionMatch) { Write-Log "ERROR" "modVersion not found in $mainLua"; exit 1 }
$version = $versionMatch.Matches[0].Groups[1].Value
Write-Log "INFO" "Building $modName v$version"

$changelogPath = Join-Path $modFolder "CHANGELOG.md"
if (-not (Test-Path $changelogPath)) { Write-Log "ERROR" "$modName has no CHANGELOG.md"; exit 1 }
$changelog = Get-Content $changelogPath -Raw
if ($changelog -notmatch "(?m)^## $([regex]::Escape($version))\s*$") {
    Write-Log "ERROR" "$modName\CHANGELOG.md has no '## $version' entry. Add one before releasing."
    exit 1
}

$stagingRoot = Join-Path $repoRoot "dist\staging"
$stagedMod = Join-Path $stagingRoot $modName
if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stagedMod -Force | Out-Null

# The mod folder carries its own README.md and CHANGELOG.md; LICENSE is shared at the repo root.
Copy-Item (Join-Path $modFolder "*") $stagedMod -Recurse
Copy-Item (Join-Path $repoRoot "LICENSE") $stagedMod

# Never ship dev log files.
Get-ChildItem $stagedMod -Recurse -File -Filter "*.log" | ForEach-Object { Remove-Item $_.FullName; Write-Log "WARN" "Excluded $($_.Name) from the release" }

# Never ship a personal config: releases must not overwrite players' settings.
$stagedConfig = Join-Path $stagedMod "scripts\config.lua"
if (Test-Path $stagedConfig) {
    Remove-Item $stagedConfig
    Write-Log "WARN" "Excluded scripts\config.lua from the release"
}

$zipPath = Join-Path $repoRoot "dist\$modName-v$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }
# Compress-Archive in Windows PowerShell 5.1 writes backslash entry names, which some
# extractors and mod managers turn into literal file names. Write "/" entries instead.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipStream = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem $stagedMod -Recurse -File | ForEach-Object {
        $entryName = $modName + "/" + $_.FullName.Substring($stagedMod.Length + 1).Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipStream, $_.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $zipStream.Dispose()
}
Remove-Item $stagingRoot -Recurse -Force

Write-Log "OK" "Built $zipPath"
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try { $zip.Entries | ForEach-Object { Write-Host "  $($_.FullName)" } } finally { $zip.Dispose() }
