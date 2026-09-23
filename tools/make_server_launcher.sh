#!/bin/bash
# Wraps the exported headless dedicated-server app in a small AppleScript
# launcher applet so macOS quit events (Dock > Salir, Cmd+Q, osascript quit)
# actually stop the server. Run AFTER exporting the "macOS Server" preset.
#
# Result: build/macos/LastDayServer.app is the launcher applet containing
# the real server at Contents/Resources/LastDayServerCore.app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build/macos"
TARGET="$BUILD_DIR/LastDayServer.app"
CORE_TMP="$BUILD_DIR/.LastDayServerCore.app"
ICON="$ROOT/tools/icons/LastDayServer.icns"

# Locate the exported server:
# - fresh export: LastDayServer.app is the raw Godot app
# - already wrapped: the core lives at Contents/Resources/LastDayServerCore.app
rm -rf "$CORE_TMP"
if [ -d "$TARGET/Contents/Resources/LastDayServerCore.app" ]; then
	mv "$TARGET/Contents/Resources/LastDayServerCore.app" "$CORE_TMP"
elif [ -f "$TARGET/Contents/MacOS/Un dia mas" ]; then
	mv "$TARGET" "$CORE_TMP"
else
	echo "No se encontró el servidor exportado — exporta primero el preset \"macOS Server\"." >&2
	exit 1
fi

rm -rf "$TARGET"
osacompile -s -o "$TARGET" "$ROOT/tools/server_launcher.applescript"
mv "$CORE_TMP" "$TARGET/Contents/Resources/LastDayServerCore.app"

# The core app must not show its own Dock icon; the launcher owns the Dock.
CORE_PLIST="$TARGET/Contents/Resources/LastDayServerCore.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$CORE_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$CORE_PLIST"

# Launcher identity and icon.
WRAP_PLIST="$TARGET/Contents/Info.plist"
if [ -f "$ICON" ]; then
	cp "$ICON" "$TARGET/Contents/Resources/applet.icns"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.lastday.server.launcher" "$WRAP_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.lastday.server.launcher" "$WRAP_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName LastDayServer" "$WRAP_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string LastDayServer" "$WRAP_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName LastDayServer" "$WRAP_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string LastDayServer" "$WRAP_PLIST"

echo "Launcher creado: $TARGET"
