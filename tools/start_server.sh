#!/bin/bash
# Script para lanzar el servidor dedicado de Godot
# Uso: ./start_server.sh

PROJECT_PATH="/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego"
GODOT_BIN="/home/sami/bin/godot"

# Matar cualquier instancia previa de Godot
pkill -f "godot.*--server" 2>/dev/null
sleep 1

echo "Iniciando servidor dedicado..."
exec "$GODOT_BIN" --path "$PROJECT_PATH" --headless -- --server 2>&1
