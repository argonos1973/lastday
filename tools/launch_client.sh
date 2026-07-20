#!/bin/bash
# Launch script: imports assets first, then starts the game client
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_BIN:-/home/sami/bin/godot}"

echo "Importing assets..."
"$GODOT" --path "$PROJECT_PATH" --headless --import 2>/dev/null

echo "Starting client..."
exec "$GODOT" --path "$PROJECT_PATH"
