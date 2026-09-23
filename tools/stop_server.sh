#!/bin/bash
# Detiene el servidor dedicado de forma limpia: guarda el mundo y cierra el proceso.
# Uso: ./stop_server.sh
# El flag vive en user://, que depende del OS:
#   macOS: ~/Library/Application Support/Godot/app_userdata/Un dia mas
#   Linux: ~/.local/share/godot/app_userdata/Un dia mas
if [ "$(uname)" = "Darwin" ]; then
	FLAG="$HOME/Library/Application Support/Godot/app_userdata/Un dia mas/stop_server.flag"
else
	FLAG="$HOME/.local/share/godot/app_userdata/Un dia mas/stop_server.flag"
fi
mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
echo "Parada solicitada: el servidor guardará el mundo y terminará en unos segundos."
