#!/bin/bash
# Detiene el servidor dedicado de forma limpia: borra el mundo de la sesión y cierra el proceso.
# Uso: ./stop_server.sh
# El flag lleva el PID del server a parar (un PID por línea) para que una
# instancia nueva nunca se coma la petición de parada de otra.
#   macOS: ~/Library/Application Support/Godot/app_userdata/Un dia mas
#   Linux: ~/.local/share/godot/app_userdata/Un dia mas
if [ "$(uname)" = "Darwin" ]; then
	FLAG="$HOME/Library/Application Support/Godot/app_userdata/Un dia mas/stop_server.flag"
else
	FLAG="$HOME/.local/share/godot/app_userdata/Un dia mas/stop_server.flag"
fi
PIDS="$(pgrep -fi 'LastDayServerCore|LastDayServer\.x86_64|LastDayServer\.exe|godot.*--server|Un dia mas.*--headless' 2>/dev/null | tr '\n' ' ')"
if [ -z "${PIDS// /}" ]; then
	echo "No hay servidor en ejecución."
	rm -f "$FLAG"
	exit 0
fi
mkdir -p "$(dirname "$FLAG")"
printf '%s\n' $PIDS > "$FLAG"
echo "Parada solicitada (PID $PIDS): el servidor borrará el mundo de la sesión y terminará en unos segundos."
