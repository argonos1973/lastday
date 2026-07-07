#!/bin/bash
# Don't kill server - only launch client
# Auto-detect project directory (this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the Godot binary: Linux first, then PATH, then macOS (fallback)
if [ -x "/home/sami/bin/godot" ]; then
    GODOT="/home/sami/bin/godot"
elif command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
elif [ -x "$SCRIPT_DIR/work/godot4.7/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT="$SCRIPT_DIR/work/godot4.7/Godot.app/Contents/MacOS/Godot"
else
    echo "ERROR: no se encuentra el binario de Godot" >&2
    exit 1
fi

exec "$GODOT" --path "$SCRIPT_DIR"
