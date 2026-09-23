@echo off
REM Detiene el servidor dedicado de forma limpia: guarda el mundo y cierra el proceso.
REM Uso: doble clic o stop_server.bat
REM El flag vive en user:// = %APPDATA%\Godot\app_userdata\Un dia mas
set "FLAG=%APPDATA%\Godot\app_userdata\Un dia mas\stop_server.flag"
if not exist "%APPDATA%\Godot\app_userdata\Un dia mas" mkdir "%APPDATA%\Godot\app_userdata\Un dia mas"
type nul > "%FLAG%"
echo Parada solicitada: el servidor guardara el mundo y terminara en unos segundos.
pause
