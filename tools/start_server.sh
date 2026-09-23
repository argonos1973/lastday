#!/bin/bash
# Script para lanzar el servidor dedicado de Godot
# Uso: ./start_server.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_APP="$PROJECT_PATH/build/macos/LastDayServer.app"
if [ "$(uname)" = "Darwin" ]; then
	USER_DIR="$HOME/Library/Application Support/Godot/app_userdata/Un dia mas"
else
	USER_DIR="$HOME/.local/share/godot/app_userdata/Un dia mas"
fi

# Parada limpia de cualquier instancia previa: el flag hace que el servidor
# guarde el mundo antes de terminar el proceso.
if pgrep -f "LastDayServer|godot.*--server" >/dev/null 2>&1; then
	mkdir -p "$USER_DIR"
	touch "$USER_DIR/stop_server.flag"
	sleep 4
fi
pkill -f "godot.*--server" 2>/dev/null
pkill -f "LastDayServer" 2>/dev/null
sleep 1

echo "Iniciando servidor dedicado..."
if [ "$(uname)" != "Darwin" ]; then
	# Linux: binario exportado con el preset "Linux Server" (arranca solo), o el editor.
	LINUX_SERVER="$PROJECT_PATH/build/linux/LastDayServer.x86_64"
	if [ -x "$LINUX_SERVER" ]; then
		exec "$LINUX_SERVER" 2>&1
	fi
	GODOT_BIN="${GODOT_BIN:-/home/sami/bin/godot}"
	exec "$GODOT_BIN" --path "$PROJECT_PATH" --headless --server 2>&1
fi
if [ -f "$SERVER_APP/Contents/MacOS/applet" ]; then
	# Launcher applet (tools/make_server_launcher.sh): añade icono en el Dock
	# y soporta Salir — guarda el mundo y termina el proceso.
	open "$SERVER_APP"
elif [ -x "$SERVER_APP/Contents/MacOS/Un dia mas" ]; then
	# Export "macOS Server" sin envolver: arranca el servidor sola
	exec "$SERVER_APP/Contents/MacOS/Un dia mas" 2>&1
else
	GODOT_BIN="${GODOT_BIN:-$PROJECT_PATH/work/godot4.7/Godot.app/Contents/MacOS/Godot}"
	[ -x "$GODOT_BIN" ] || GODOT_BIN="/home/sami/bin/godot"
	exec "$GODOT_BIN" --path "$PROJECT_PATH" --headless --server 2>&1
fi
