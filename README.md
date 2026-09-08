# ffw-centered-ui

UE4SS Lua mods for **Far Far West** that move HUD elements (spells, ammo, ...)
next to the crosshair, so you do not have to look at the screen corners.

Contents:

| Mod | Purpose |
|---|---|
| `CenteredHUD` | Moves/scales HUD widgets, driven by `config.ini` |
| `HUDDump` | Dev tool: dumps the live widget tree to a file (F7) |

## Requirements

- Far Far West
- UE4SS installed in `FarFarWest/Binaries/Win64/ue4ss` (Lua mod loading
  enabled)

**Important:** upstream [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) does not
currently work with Far Far West. Use the game-specific build instead:
<https://github.com/CamperNoob/ue4ss-far-far-west>

## Install

Windows users: see [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md) (or run
`install-windows.bat`) - note that the Windows path is untested, developed on
Linux. Linux:

```sh
./install.sh              # install normal mods (CenteredHUD)
./install.sh HUDDump      # install a specific mod by name
./install.sh --all        # everything, dev tools included
./install.sh --list       # show available mods
```

The script copies each mod into the game's `ue4ss/Mods/` folder and adds it to
`mods.txt` (kept before the built-in keybinds entry).

Env vars:

- `GAME_MODS=/path/to/ue4ss/Mods` - override the game path
  (default: `~/.local/share/Steam/steamapps/common/FarFarWest/FarFarWest/Binaries/Win64/ue4ss/Mods`)
- `KEEP_CONFIG=0` - overwrite an already installed `config.ini`
  (default keeps your edited config)

## Usage

- Start the game. The HUD is repositioned automatically.
- **F8** - reload `config.ini` and re-apply (CenteredHUD)
- **F7** - dump widget tree to `ue4ss/Mods/HUDDump/dump.txt` (HUDDump)

## Configuration

Edit `Mods/CenteredHUD/config.ini` (or the installed copy in the game folder,
then press F8). Each `[Section]` other than `[General]` describes one HUD
element; the section name is just a label, so sections can be added, removed or
duplicated freely.

| Key | Meaning |
|---|---|
| `Widget` | Widget name in the HUD tree (required, e.g. `HB_Spells`) |
| `Enabled` | `1`/`0`, skip the section when `0` |
| `X`, `Y` | Offset from screen center, in pixels |
| `AlignX`, `AlignY` | Which point of the element sits at center+offset (`0` left/top, `0.5` middle, `1` right/bottom) |
| `Scale` | Render scale (`1` = original size) |
| `ZOrder` | Draw order, higher = on top |
| `Reparent` | `none` keep parent, `canvas` move into `MovingCanvas`, `outer` move next to the crosshair outside `RetainerBox_0` (raw pixel offsets, fixes ghost rows), `auto` reparent only if not already in a canvas slot |
| `RowAlign` | Child row alignment: `-1` leave, `0` fill, `1` left, `2` center, `3` right |
| `ResetChildOffsets` | `1` clears per-child render translation (spell stagger) |

`[General]` has `Enabled` and `Verbose` (log each applied element to the UE4SS
console).

Example:

```ini
[Spells]
Widget=HB_Spells
X=-70
Y=0
AlignX=1
AlignY=0.5
Scale=0.9
Reparent=outer
RowAlign=3
ResetChildOffsets=1
```

## Finding widget names

1. Install and enable HUDDump: `./install.sh HUDDump`
2. Press **F7** in game.
3. Copy the results back into this repo: `./fetch-dump.sh`
   (writes `dumps/dump.txt` and `dumps/UE4SS.log`; `UE4SS=` overrides the path)
4. Look for the widget name (e.g. `HB_Ammo`) and use it as `Widget=` in
   `config.ini`.

## Layout

```
Mods/CenteredHUD/Scripts/main.lua   config parsing + widget repositioning
Mods/CenteredHUD/config.ini         user settings
Mods/HUDDump/Scripts/main.lua       widget tree dumper
install.sh                          install/enable mods
fetch-dump.sh                       pull dump.txt + UE4SS.log from the game
dumps/                              collected dumps
```

## Troubleshooting

- Nothing moves: check `ue4ss/UE4SS.log` for `[CenteredHUD]` lines and that the
  mod is listed with `: 1` in `ue4ss/Mods/mods.txt`.
- Duplicated/ghost rows: use `Reparent=outer` for that element.
- Wrong widget name: re-run the HUDDump step above.
