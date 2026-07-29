#!/bin/bash
# Lanzar cliente - compatible con macOS y Linux
# Auto-detect project directory (this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
OS="$(uname -s)"

GODOT=""

# 1. Variable de entorno GODOT_BIN (maxima prioridad)
if [ -n "$GODOT_BIN" ] && [ -x "$GODOT_BIN" ]; then
    GODOT="$GODOT_BIN"

# 2. Godot en PATH
elif command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"

# 3. macOS: ubicaciones comunes
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

# 4. Linux: ubicaciones comunes
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
    echo "Instala Godot 4.x o define la variable GODOT_BIN con la ruta al ejecutable." >&2
    echo "  export GODOT_BIN=/ruta/a/godot" >&2
    exit 1
fi

echo "Usando Godot: $GODOT"
exec "$GODOT" --path "$(cd "$SCRIPT_DIR/.." && pwd)"
