#!/usr/bin/env bash
# Copies mods from ./Mods into the game's ue4ss Mods folder and enables them.
set -euo pipefail
GAME_MODS="${GAME_MODS:-$HOME/.local/share/Steam/steamapps/common/FarFarWest/FarFarWest/Binaries/Win64/ue4ss/Mods}"
SRC="$(cd "$(dirname "$0")" && pwd)/Mods"

for mod in "$SRC"/*/; do
    name="$(basename "$mod")"
    rm -rf "$GAME_MODS/$name"
    cp -r "$mod" "$GAME_MODS/$name"
    if ! grep -q "^$name :" "$GAME_MODS/mods.txt"; then
        # insert before the Keybinds line (must stay last)
        sed -i "/^; Built-in keybinds/i $name : 1" "$GAME_MODS/mods.txt"
    fi
    echo "installed $name"
done
