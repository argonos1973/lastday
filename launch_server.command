#!/bin/bash
# launch_server.sh — Lanza el servidor headless de Godot en macOS
# Uso: ./launch_server.sh

GODOT="/Volumes/copia/lastday2/work/godot4.7/Godot.app/Contents/MacOS/Godot"
PROJECT="/Volumes/copia/lastday2"

if [ ! -x "$GODOT" ]; then
    echo "ERROR: No se encuentra el binario de Godot en: $GODOT"
    exit 1
fi

SERVER_PATTERN="Godot --path $PROJECT --headless -- --server"
SERVER_PIDS=$(pgrep -f "$SERVER_PATTERN" 2>/dev/null || true)
if [ -n "$SERVER_PIDS" ]; then
    echo "[SERVER] Deteniendo servidores anteriores: $SERVER_PIDS"
    kill $SERVER_PIDS 2>/dev/null || true
    sleep 1
fi

echo "[SERVER] Iniciando servidor headless..."
"$GODOT" --path "$PROJECT" --headless -- --server
