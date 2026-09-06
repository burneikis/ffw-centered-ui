#!/usr/bin/env bash
# Copies the latest dump.txt and UE4SS.log from the game into ./dumps/
set -euo pipefail
UE4SS="${UE4SS:-$HOME/.local/share/Steam/steamapps/common/FarFarWest/FarFarWest/Binaries/Win64/ue4ss}"
mkdir -p "$(dirname "$0")/dumps"
cp "$UE4SS/Mods/HUDDump/dump.txt" "$(dirname "$0")/dumps/dump.txt" 2>/dev/null || \
cp "$UE4SS/../dump.txt" "$(dirname "$0")/dumps/dump.txt" 2>/dev/null || \
cp "$UE4SS/dump.txt" "$(dirname "$0")/dumps/dump.txt" 2>/dev/null || { echo "no dump.txt found"; exit 1; }
cp "$UE4SS/UE4SS.log" "$(dirname "$0")/dumps/UE4SS.log"
echo "saved to dumps/"
