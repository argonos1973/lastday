#!/bin/bash
# Build the LastDayNav GDExtension (plain C, no godot-cpp needed).
# macOS: universal dylib via clang. Windows/Linux: cross-compile with zig cc
# (install zig or run on the target platform with cc).
set -e
cd "$(dirname "$0")/.."
mkdir -p native/bin

CFLAGS="-O2 -fPIC -Wall -Wno-unused-function -Inative/include"

# macOS (universal binary — works on arm64 and x86_64 hosts)
clang $CFLAGS -arch arm64 -arch x86_64 -shared \
	-o native/bin/liblastday_nav.dylib native/lastday_nav.c
echo "built native/bin/liblastday_nav.dylib"

ZIG="$(command -v zig 2>/dev/null || echo "$(pwd)/work/zig/zig")"
if [ -x "$ZIG" ]; then
	"$ZIG" cc $CFLAGS -shared -target x86_64-windows-gnu \
		-o native/bin/lastday_nav.dll native/lastday_nav.c
	"$ZIG" cc $CFLAGS -shared -fPIC -target x86_64-linux-gnu \
		-o native/bin/liblastday_nav.so native/lastday_nav.c
	rm -f native/bin/lastday_nav.lib native/bin/lastday_nav.pdb
	echo "built lastday_nav.dll + liblastday_nav.so (zig)"
else
	echo "NOTE: zig not found — skipping windows/linux builds"
fi

# Only register platform libraries that actually exist on disk so exports for
# other platforms fall back cleanly to GDScript instead of failing on missing
# binaries.
{
	echo "[configuration]"
	echo ""
	echo 'entry_symbol = "lastday_nav_library_init"'
	echo 'compatibility_minimum = "4.7"'
	echo ""
	echo "[libraries]"
	echo ""
	if [ -f native/bin/liblastday_nav.dylib ]; then
		echo 'macos.debug = "res://native/bin/liblastday_nav.dylib"'
		echo 'macos.release = "res://native/bin/liblastday_nav.dylib"'
	fi
	if [ -f native/bin/lastday_nav.dll ]; then
		echo 'windows.debug.x86_64 = "res://native/bin/lastday_nav.dll"'
		echo 'windows.release.x86_64 = "res://native/bin/lastday_nav.dll"'
	fi
	if [ -f native/bin/liblastday_nav.so ]; then
		echo 'linux.debug.x86_64 = "res://native/bin/liblastday_nav.so"'
		echo 'linux.release.x86_64 = "res://native/bin/liblastday_nav.so"'
	fi
} > native/LastDayNav.gdextension
