# Install on Windows

## 1. Find the game folder

In Steam: right click **Far Far West** -> Manage -> Browse local files.
Then go into `FarFarWest\Binaries\Win64\`.

Typical path:

```
C:\Program Files (x86)\Steam\steamapps\common\FarFarWest\FarFarWest\Binaries\Win64\
```

That folder is called `<Win64>` below. It contains `FarFarWest-Win64-Shipping.exe`.

## 2. Install UE4SS

The official UE4SS release does **not** work with Far Far West. Use the
game-specific build: <https://github.com/CamperNoob/ue4ss-far-far-west/releases>

1. Download the latest release zip.
2. Extract it into `<Win64>`, so you end up with:

```
<Win64>\dwmapi.dll
<Win64>\ue4ss\UE4SS.dll
<Win64>\ue4ss\UE4SS-settings.ini
<Win64>\ue4ss\Mods\
```

If the zip has a top-level folder, copy the *contents*, not the folder itself.
The proxy DLL (`dwmapi.dll`, sometimes `xinput1_3.dll`) must sit next to
`FarFarWest-Win64-Shipping.exe`.

3. Start the game once. A UE4SS console window should appear and
   `<Win64>\ue4ss\UE4SS.log` should be created. If neither happens, UE4SS is not
   loading (see Troubleshooting).

## 3. Install this mod

1. Download this repo (GitHub -> Code -> Download ZIP) and extract it.
2. Copy the folder `Mods\CenteredHUD` into `<Win64>\ue4ss\Mods\`, giving:

```
<Win64>\ue4ss\Mods\CenteredHUD\enabled.txt
<Win64>\ue4ss\Mods\CenteredHUD\config.ini
<Win64>\ue4ss\Mods\CenteredHUD\Scripts\main.lua
```

`enabled.txt` is what turns the mod on, so no other file has to be edited.
(If your UE4SS build ignores `enabled.txt`, add a line `CenteredHUD : 1` to
`<Win64>\ue4ss\Mods\mods.txt`, above the built-in keybinds line.)

Or just double click `install-windows.bat` from the extracted repo: it finds the
game via Steam, copies the mod and keeps an existing `config.ini`.

3. Start the game. The HUD moves next to the crosshair.

## 4. Tweaking

Edit `<Win64>\ue4ss\Mods\CenteredHUD\config.ini` with Notepad, then press **F8**
in game to reload it. Keys are documented in `README.md`.

## Troubleshooting

- No UE4SS console: make sure you extracted to `<Win64>` and not a subfolder,
  and that antivirus did not delete the DLL. Launch the game from Steam.
- HUD does not move: open `<Win64>\ue4ss\UE4SS.log` and search for
  `CenteredHUD`. No lines = mod folder is in the wrong place.
- Duplicated / ghost rows: set `Reparent=outer` for that element in
  `config.ini`, press F8.
- Multiplayer / anti-cheat: this only edits your own HUD, but any DLL injection
  can trip anti-cheat. Use at your own risk.
