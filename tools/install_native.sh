#!/bin/bash
# Copies LastDayNav binaries next to an exported executable.
#
# Godot loads GDExtension libraries via globalize_path("res://..."), which on
# exports resolves to the directory holding the .pck — the dynamic library must
# exist as a REAL file there; it cannot be dlopen'd from inside the pck.
#
# Usage: tools/install_native.sh <export path>
#   macOS app  : tools/install_native.sh "build/macos/LastDay.app"
#   Linux/Win  : tools/install_native.sh "build/linux" | "build/windows" | remote dir
set -e
cd "$(dirname "$0")/.."

DEST="$1"
[ -z "$DEST" ] && { echo "usage: $0 <export dir or .app>"; exit 1; }

if [ -d "$DEST/Contents/Resources" ]; then
	# macOS .app bundle: res:// == Contents/Resources
	TARGET="$DEST/Contents/Resources/native/bin"
	mkdir -p "$TARGET"
	cp native/bin/liblastday_nav.dylib "$TARGET/"
	echo "installed liblastday_nav.dylib -> $TARGET"
else
	TARGET="$DEST/native/bin"
	mkdir -p "$TARGET"
	[ -f native/bin/liblastday_nav.so ] && cp native/bin/liblastday_nav.so "$TARGET/"
	[ -f native/bin/lastday_nav.dll ] && cp native/bin/lastday_nav.dll "$TARGET/"
	echo "installed native libs -> $TARGET"
fi
