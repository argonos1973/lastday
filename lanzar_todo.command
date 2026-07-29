#!/bin/bash
# Lanza el servidor dedicado y el cliente en secuencia
# Uso: ./lanzar_todo.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/sami/bin/godot}"

LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"
SERVER_LOG="$LOG_DIR/server.log"
CLIENT_LOG="$LOG_DIR/client.log"

# Matar instancias previas
pkill -f "godot.*--server" 2>/dev/null
pkill -f "godot.*--path.*$PROJECT_PATH" 2>/dev/null
sleep 1

echo "Iniciando servidor dedicado..."
"$GODOT_BIN" --path "$PROJECT_PATH" --headless --server > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!
echo "Servidor PID: $SERVER_PID  Log: $SERVER_LOG"

sleep 3

echo "Iniciando cliente..."
"$GODOT_BIN" --path "$PROJECT_PATH" > "$CLIENT_LOG" 2>&1 &
CLIENT_PID=$!
echo "Cliente PID: $CLIENT_PID  Log: $CLIENT_LOG"

echo ""
echo "Servidor y cliente iniciados."
echo "  - Servidor PID: $SERVER_PID  Log: $SERVER_LOG"
echo "  - Cliente PID:  $CLIENT_PID  Log: $CLIENT_LOG"
echo ""
echo "Ver logs en tiempo real:"
echo "  tail -f $SERVER_LOG"
echo "  tail -f $CLIENT_LOG"
echo ""
echo "Para detener ambos:"
echo "  kill $SERVER_PID $CLIENT_PID"
echo "  o: pkill -f godot"
