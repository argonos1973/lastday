#!/bin/bash
# Script para lanzar el servidor dedicado de Godot
# Uso: ./start_server.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/sami/bin/godot}"

# Matar cualquier instancia previa de Godot
pkill -f "godot.*--server" 2>/dev/null
sleep 1

echo "Iniciando servidor dedicado..."
exec "$GODOT_BIN" --path "$PROJECT_PATH" --headless --server 2>&1
