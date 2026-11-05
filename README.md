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

Flex modifiers such as Manual Collection are untouched and work as normal.

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

Open `ue4ss\UE4SS.log` and look for:

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