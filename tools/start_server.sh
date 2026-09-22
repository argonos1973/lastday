#!/bin/bash
# Script para lanzar el servidor dedicado de Godot
# Uso: ./start_server.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_APP="$(echo "$PROJECT_PATH"/build/macos/LastDayServer.app/Contents/MacOS/*)"

# Matar cualquier instancia previa del servidor
pkill -f "godot.*--server" 2>/dev/null
pkill -f "LastDayServer.app" 2>/dev/null
sleep 1

if [ -z "$GODOT_BIN" ]; then
	if [ -x "$SERVER_APP" ]; then
		# App exportada con preset "macOS Server" (dedicated_server): arranca el servidor sola
		GODOT_BIN="$SERVER_APP"
	elif [ -x "$PROJECT_PATH/work/godot4.7/Godot.app/Contents/MacOS/Godot" ]; then
		GODOT_BIN="$PROJECT_PATH/work/godot4.7/Godot.app/Contents/MacOS/Godot"
	else
		GODOT_BIN="/home/sami/bin/godot"
	fi
fi

echo "Iniciando servidor dedicado..."
if [[ "$GODOT_BIN" == *LastDayServer.app* ]]; then
	exec "$GODOT_BIN" 2>&1
else
	exec "$GODOT_BIN" --path "$PROJECT_PATH" --headless --server 2>&1
fi
