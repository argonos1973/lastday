#!/bin/bash
# Launch script: imports assets first, then starts the headless server
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-godot}"

echo "Importing assets..."
"$GODOT" --path "$DIR" --headless --import 2>/dev/null

echo "Starting server..."
exec "$GODOT" --path "$DIR" --headless --server
