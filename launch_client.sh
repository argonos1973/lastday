#!/bin/bash
# Launch script (Linux): imports assets first, then starts the game client
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-godot}"

echo "Importing assets..."
"$GODOT" --path "$SCRIPT_DIR" --headless --import 2>/dev/null

echo "Starting client..."
exec "$GODOT" --path "$SCRIPT_DIR"
