#!/bin/bash
# Lanzar cliente de Last Day - doble click en Finder para ejecutar
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the Godot binary: prefer bundled build, fall back to PATH.
if [ -x "$SCRIPT_DIR/work/godot4.7/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT="$SCRIPT_DIR/work/godot4.7/Godot.app/Contents/MacOS/Godot"
elif command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
elif [ -x "/home/sami/bin/godot" ]; then
    GODOT="/home/sami/bin/godot"
else
    echo "ERROR: no se encuentra el binario de Godot" >&2
    read -n 1 -s -r -p "Pulsa cualquier tecla para cerrar..."
    exit 1
fi

exec "$GODOT" --path "$SCRIPT_DIR"
