#!/bin/bash
# Launch script (Linux): imports assets first, then starts the headless server
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-godot}"

echo "Importing assets..."
"$GODOT" --path "$SCRIPT_DIR" --headless --import 2>/dev/null

echo "Starting server..."
exec "$GODOT" --path "$SCRIPT_DIR" --headless --server
