#!/bin/bash
# exportar.sh - Genera builds para Linux, macOS y Android
# Uso: ./exportar.sh [linux|macos|android|todos]
# Por defecto genera todos los disponibles.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-godot}"
BUILD_DIR="$PROJECT_DIR/build"
TARGET="${1:-todos}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

build_linux() {
    info "Exportando Linux..."
    mkdir -p "$BUILD_DIR/linux"
    if "$GODOT" --headless --path "$PROJECT_DIR" --export-release "Linux" "$BUILD_DIR/linux/LastDay.x86_64" 2>&1; then
        ok "Linux: $BUILD_DIR/linux/LastDay.x86_64"
    else
        fail "Linux: exportacion fallida"
        return 1
    fi
}

build_macos() {
    info "Exportando macOS..."
    mkdir -p "$BUILD_DIR/macos"
    if "$GODOT" --headless --path "$PROJECT_DIR" --export-release "macOS" "$BUILD_DIR/macos/LastDay.zip" 2>&1; then
        ok "macOS: $BUILD_DIR/macos/LastDay.zip"
    else
        fail "macOS: exportacion fallida"
        return 1
    fi
}

build_android() {
    info "Exportando Android..."
    mkdir -p "$BUILD_DIR/android"
    if "$GODOT" --headless --path "$PROJECT_DIR" --export-release "Android" "$BUILD_DIR/android/LastDay.apk" 2>&1; then
        ok "Android: $BUILD_DIR/android/LastDay.apk"
    else
        fail "Android: exportacion fallida"
        return 1
    fi
}

# Verificar que Godot existe
if ! command -v "$GODOT" &>/dev/null; then
    # Intentar ruta comun
    if [ -x "/home/sami/bin/godot" ]; then
        GODOT="/home/sami/bin/godot"
    else
        fail "No se encontro el ejecutable de Godot. Instala Godot 4.x o setea GODOT=/ruta/a/godot"
        exit 1
    fi
fi

info "Usando Godot: $GODOT"
info "Proyecto: $PROJECT_DIR"
echo ""

ERRORS=0

case "$TARGET" in
    linux)
        build_linux || ERRORS=$((ERRORS+1))
        ;;
    macos)
        build_macos || ERRORS=$((ERRORS+1))
        ;;
    android)
        build_android || ERRORS=$((ERRORS+1))
        ;;
    todos|all|"")
        build_linux   || ERRORS=$((ERRORS+1))
        build_macos   || ERRORS=$((ERRORS+1))
        build_android || ERRORS=$((ERRORS+1))
        ;;
    *)
        echo "Uso: ./exportar.sh [linux|macos|android|todos]"
        exit 1
        ;;
esac

echo ""
if [ "$ERRORS" -eq 0 ]; then
    ok "Exportacion completada sin errores."
else
    fail "Exportacion completada con $ERRORS error(es)."
    exit 1
fi
