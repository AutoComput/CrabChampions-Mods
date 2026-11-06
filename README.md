# Crab Champions Mods

[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases) Lua mods for **Crab Champions**, by AutoComput.

## Mods

| Mod | What it does | Version |
|---|---|---|
| [CancelLockedSlots](CancelLockedSlots/README.md) | Keep **Locked Slots** selected for real Prismatic rank, loot luck and victory rewards, while cancelling its effect so your inventory keeps normal slot counts. | 1.0.0 |

Each mod folder has its own `README.md` (install, settings, troubleshooting) and `CHANGELOG.md`.

## Requirements

- Crab Champions (Steam)
- UE4SS, tested with **UE4SS 3.0.1** on Crab Champions' Unreal Engine 4.27 build

## Installing a mod

Download the mod's release zip and extract it into:

```
Crab Champions\CrabChampions\Binaries\Win64\ue4ss\Mods\
```

Each zip contains a single `<ModName>\` folder with an `enabled.txt`, so the mod turns itself on without editing `mods.txt`. See the mod's own README for details.

## Building a release

From the repo root, with the mod folder name:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-release.ps1 -Mod CancelLockedSlots
```

The version is read from the mod's `scripts\main.lua`, and the build fails unless that mod's `CHANGELOG.md` has a matching `## <version>` entry. Output lands in `dist\<ModName>-v<version>.zip`. Personal `config.lua` files and `.log` files are never shipped.

## Releases and tags

Tags are namespaced per mod, since each ships on its own schedule:

```
cancel-locked-slots/v1.0.0
```

## Reporting a problem

Open an issue and say which mod it's about. Most mod folders include `tools\CollectDiagnostics.bat`, which bundles the relevant logs — attach the zip it produces.

## License

Copyright (C) 2026 AutoComput. Licensed under the GNU General Public License v3.0 or later (`GPL-3.0-or-later`). See [`LICENSE`](LICENSE).
