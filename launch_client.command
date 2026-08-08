#!/bin/bash
# launch_client.command — Lanza el cliente de Godot (Linux / macOS)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v godot4 &> /dev/null; then
    GODOT_CMD="godot4"
elif command -v godot &> /dev/null; then
    GODOT_CMD="godot"
elif flatpak info org.godotengine.Godot &> /dev/null; then
    GODOT_CMD="flatpak run org.godotengine.Godot"
elif [ -x "/Volumes/copia/lastday2/work/godot4.7/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_CMD="/Volumes/copia/lastday2/work/godot4.7/Godot.app/Contents/MacOS/Godot"
else
    echo "ERROR: No se encontró Godot 4 instalado en el sistema."
    exit 1
fi

echo "Ejecutando cliente con: $GODOT_CMD"
$GODOT_CMD --path "$SCRIPT_DIR" "$@"
