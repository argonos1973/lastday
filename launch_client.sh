#!/bin/bash
# Launch script: imports assets first, then starts the game client
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-godot}"

echo "Importing assets..."
"$GODOT" --path "$DIR" --headless --import 2>/dev/null

echo "Starting client..."
exec "$GODOT" --path "$DIR"
