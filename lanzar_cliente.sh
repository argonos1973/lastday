#!/bin/bash
pkill -f "godot" 2>/dev/null
sleep 1
flatpak run org.godotengine.Godot --path /home/sami/Documentos/quiero-crear-un-prototipo-de-juego
