#!/bin/bash
# Detiene el servidor dedicado de forma limpia: guarda el mundo y cierra el proceso.
# Uso: ./stop_server.sh
FLAG="$HOME/Library/Application Support/Godot/app_userdata/Un dia mas/stop_server.flag"
touch "$FLAG"
echo "Parada solicitada: el servidor guardará el mundo y terminará en unos segundos."
