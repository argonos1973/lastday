#!/bin/bash
# launch_client.sh — Lanza el cliente de Godot en macOS
# Uso: ./launch_client.sh

GODOT="/Volumes/copia/lastday2/work/godot4.7/Godot.app/Contents/MacOS/Godot"
PROJECT="/Volumes/copia/lastday2"

if [ ! -x "$GODOT" ]; then
    echo "ERROR: No se encuentra el binario de Godot en: $GODOT"
    exit 1
fi

"$GODOT" --path "$PROJECT" 2>&1 | while IFS= read -r line; do
    case "$line" in
        *"[RIFLE_VERIFY]"*) printf '%s\n' "$line" ;;
    esac
done
