# CancelLockedSlots

A Crab Champions mod that lets you keep **Locked Slots** selected in the difficulty menu, so the game counts all 8 red modifiers and gives you real **Prismatic** rank, loot luck and victory rewards, while cancelling Locked Slots' effect. Your inventory keeps its normal slot counts (24 weapon mods, 12 ability mods, 12 melee mods, 24 perks).

## Requirements

- Crab Champions (Steam)
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases), tested with **UE4SS 3.0.1** on Crab Champions' Unreal Engine 4.27 build

## Install

1. Install UE4SS into `Crab Champions\CrabChampions\Binaries\Win64` and launch the game once to confirm it loads.
2. Extract the release zip into `Crab Champions\CrabChampions\Binaries\Win64\ue4ss\Mods\`. You should end up with `Mods\CancelLockedSlots\scripts\main.lua`.
3. Launch the game. The included `enabled.txt` turns the mod on, so you don't need to edit `mods.txt`.

## Usage

1. At the difficulty totem, turn on all red modifiers, **including Locked Slots**. The menu shows Prismatic.
2. Start the run. On island 1 the mod restores everyone's slot counts.

## Multiplayer

Only the **host** needs the mod. The host's game owns every player's inventory, so all players get their slots restored. Co-op has not been fully tested yet; reports are welcome.

## Settings

Copy `scripts\config.example.lua` to `scripts\config.lua` and edit it:

| Setting | Default | What it does |
|---|---|---|
| `cancelLockedSlots` | `true` | `false` lets Locked Slots play normally |
| `minLogLevel` | `"INFO"` | `DEBUG`, `INFO`, `WARN` or `ERROR` |

`config.lua` is never included in releases, so updating won't reset your settings.

## Checking it works

Open `Mods\CancelLockedSlots\CancelLockedSlots.log` (or `ue4ss\UE4SS.log`) and look for:

```
[CancelLockedSlots] [INFO] v1.0.0 settings=defaults cancelLockedSlots=true LockedSlots=LockedSlots(4) slotDefaults=24/12/12/24
[CancelLockedSlots] [OK] Loaded v1.0.0
[CancelLockedSlots] [INFO] Island 1: LockedSlots ON, cancelling its effect, rank=8
[CancelLockedSlots] [INFO] [YourName] Locked Slots cancelled (island 1): ...
```

If a game update changes something the mod depends on, it stops itself and logs `Startup check failed, mod not started: <reason>` instead of misbehaving. Include that line when reporting a bug.

## Update

Extract the new release over the old folder. Your `config.lua` is kept.

## Uninstall

Delete the `Mods\CancelLockedSlots` folder.

## Updates

Track the mod on Nexus Mods, or watch this repo's releases on GitHub, to be notified of new versions. Your installed version is shown in `UE4SS.log` as `[OK] Loaded vX.Y.Z`.

## Reporting a problem

1. If the game crashed, relaunch it once and close it. The mod keeps the crashed session's log as `CancelLockedSlots.previous.log`.
2. Double-click `Mods\CancelLockedSlots\tools\CollectDiagnostics.bat`.
3. Attach the zip it saves to your Desktop (`CancelLockedSlots-diagnostics-<date>.zip`) to your bug report, with a short description of what happened.

The zip contains the mod's logs, `UE4SS.log`, UE4SS settings, your installed mod list, the game's Steam build id and your Windows version. Your Windows username is replaced with `<user>`. Steam player names in the mod log are kept, since they show which player an entry is about. Crash dumps are only included if you answer yes when asked, because they contain a snapshot of game memory.

## Logs

The mod writes `Mods\CancelLockedSlots\CancelLockedSlots.log` every session, and keeps the session before as `CancelLockedSlots.previous.log`. The same lines also appear in `ue4ss\UE4SS.log`.

## License

Copyright (C) 2026 AutoComput. Licensed under the GNU General Public License v3.0 or later (`GPL-3.0-or-later`). See `LICENSE`.

