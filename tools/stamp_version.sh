#!/bin/bash
# Estampa res://version.txt con el commit actual antes de exportar.
# La pantalla de inicio (scripts/Inicio.gd) lo lee empaquetado en el pck;
# sin exportar (editor/headless) cae al fallback que lee .git/HEAD.
set -e
cd "$(dirname "$0")/.."
git rev-parse --short HEAD > version.txt
echo "version.txt -> $(cat version.txt)"
