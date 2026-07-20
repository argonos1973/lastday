#!/bin/bash
# Launch script: imports assets first, then starts the headless server
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_BIN:-/home/sami/bin/godot}"

echo "Importing assets..."
"$GODOT" --path "$PROJECT_PATH" --headless --import 2>/dev/null

echo "Starting server..."
exec "$GODOT" --path "$PROJECT_PATH" --headless --server
