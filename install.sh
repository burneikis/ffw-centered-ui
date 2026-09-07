#!/usr/bin/env bash
# Installs mods into the game's ue4ss Mods folder and enables them in mods.txt.
#
# Usage:
#   ./install.sh                 install the normal mods (CenteredHUD)
#   ./install.sh HUDDump         install specific mod(s) by name
#   ./install.sh --all           install everything in ./Mods, dev tools included
#   ./install.sh --list          show available mods
#
# Env:
#   GAME_MODS=/path/to/ue4ss/Mods   override game path
#   KEEP_CONFIG=0                   overwrite an installed config.ini
set -euo pipefail

GAME_MODS="${GAME_MODS:-$HOME/.local/share/Steam/steamapps/common/FarFarWest/FarFarWest/Binaries/Win64/ue4ss/Mods}"
SRC="$(cd "$(dirname "$0")" && pwd)/Mods"
KEEP_CONFIG="${KEEP_CONFIG:-1}"

# Dev-only mods, not installed unless asked for explicitly or with --all.
DEV_MODS=("HUDDump")

is_dev() {
    local m
    for m in "${DEV_MODS[@]}"; do [ "$m" = "$1" ] && return 0; done
    return 1
}

all_mods() {
    local d
    for d in "$SRC"/*/; do basename "$d"; done
}

case "${1:-}" in
--list)
    for m in $(all_mods); do
        if is_dev "$m"; then echo "$m (dev, needs explicit name or --all)"; else echo "$m"; fi
    done
    exit 0
    ;;
--all)
    mapfile -t mods < <(all_mods)
    ;;
"")
    mods=()
    for m in $(all_mods); do is_dev "$m" || mods+=("$m"); done
    ;;
*)
    mods=("$@")
    ;;
esac

[ -d "$GAME_MODS" ] || { echo "game Mods folder not found: $GAME_MODS" >&2; exit 1; }

for name in "${mods[@]}"; do
    [ -d "$SRC/$name" ] || { echo "no such mod: $name" >&2; exit 1; }

    saved=""
    if [ "$KEEP_CONFIG" = 1 ] && [ -f "$GAME_MODS/$name/config.ini" ]; then
        saved="$(mktemp)"
        cp "$GAME_MODS/$name/config.ini" "$saved"
    fi

    rm -rf "${GAME_MODS:?}/$name"
    cp -r "$SRC/$name" "$GAME_MODS/$name"

    if [ -n "$saved" ]; then
        mv "$saved" "$GAME_MODS/$name/config.ini"
        echo "kept existing $name/config.ini"
    fi

    if ! grep -q "^$name :" "$GAME_MODS/mods.txt"; then
        # insert before the Keybinds line (must stay last)
        sed -i "/^; Built-in keybinds/i $name : 1" "$GAME_MODS/mods.txt"
    fi
    echo "installed $name"
done
