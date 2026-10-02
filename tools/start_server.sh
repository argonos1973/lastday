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

# Parada limpia de cualquier instancia previa: el flag lleva los PID y el
# servidor borra el mundo de la sesión antes de terminar. Esperamos a que el proceso
# muera de verdad antes de lanzar — si arrancamos con el viejo vivo, el nuevo
# no puede bindear el puerto y el cliente sigue hablando con el mundo viejo.
# NUNCA se fuerza el cierre: un pkill interrumpiría el borrado del mundo de la
# sesión a mitad de camino. Si los PID marcados no responden al flag, abortamos.
PATTERN='LastDayServer|godot.*--server|Un dia mas.*--headless|Last Day.*--headless'
PIDS="$(pgrep -fi "$PATTERN" 2>/dev/null | tr '\n' ' ')"
if [ -n "${PIDS// /}" ]; then
	mkdir -p "$USER_DIR"
	printf '%s\n' $PIDS > "$USER_DIR/stop_server.flag"
	echo "Parada limpia solicitada a: $PIDS"
	# Solo esperamos a los PID marcados por el flag — otro proceso que case el
	# patrón (p.ej. un servidor lanzado entre tanto) no nos bloquea ni lo tocamos.
	alive=""
	for i in $(seq 1 45); do
		alive=""
		for p in $PIDS; do
			kill -0 "$p" 2>/dev/null && alive="$alive $p"
		done
		[ -z "$alive" ] && break
		sleep 1
	done
	if [ -n "$alive" ]; then
		echo "ERROR: el servidor no respondió a la parada limpia (PID$alive)." >&2
		echo "No se fuerza el cierre — revisa el proceso o detenlo manualmente." >&2
		exit 1
	fi
fi

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
elif [ -x "$SERVER_APP/Contents/MacOS/Last Day" ]; then
	# Export "macOS Server" sin envolver: arranca el servidor sola
	exec "$SERVER_APP/Contents/MacOS/Last Day" 2>&1
elif [ -x "$SERVER_APP/Contents/MacOS/Un dia mas" ]; then
	exec "$SERVER_APP/Contents/MacOS/Un dia mas" 2>&1
else
	GODOT_BIN="${GODOT_BIN:-$PROJECT_PATH/work/godot4.7/Godot.app/Contents/MacOS/Godot}"
	[ -x "$GODOT_BIN" ] || GODOT_BIN="/home/sami/bin/godot"
	exec "$GODOT_BIN" --path "$PROJECT_PATH" --headless --server 2>&1
fi
