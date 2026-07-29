#!/bin/bash
# Lanzar cliente de Last Day - doble click en Finder para ejecutar
# Compatible Mac y Linux
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OS="$(uname -s)"
GODOT=""

if [ -n "$GODOT_BIN" ] && [ -x "$GODOT_BIN" ]; then
    GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
elif [ "$OS" = "Darwin" ]; then
    for candidate in \
        "/Applications/Godot.app/Contents/MacOS/Godot" \
        "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
        "$SCRIPT_DIR/work/godot4.7/Godot.app/Contents/MacOS/Godot" \
        "$SCRIPT_DIR/Godot.app/Contents/MacOS/Godot"; do
        if [ -x "$candidate" ]; then
            GODOT="$candidate"
            break
        fi
    done
elif [ "$OS" = "Linux" ]; then
    for candidate in \
        "/home/sami/bin/godot" \
        "$HOME/bin/godot" \
        "$HOME/.local/bin/godot" \
        "/usr/local/bin/godot" \
        "/usr/bin/godot" \
        "$SCRIPT_DIR/work/godot4.7/godot" \
        "$SCRIPT_DIR/godot"; do
        if [ -x "$candidate" ]; then
            GODOT="$candidate"
            break
        fi
    done
fi

if [ -z "$GODOT" ]; then
    echo "ERROR: no se encuentra el binario de Godot" >&2
    read -n 1 -s -r -p "Pulsa cualquier tecla para cerrar..."
    exit 1
fi

echo "Usando Godot: $GODOT"
exec "$GODOT" --path "$SCRIPT_DIR"
