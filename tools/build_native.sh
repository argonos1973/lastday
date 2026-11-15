#!/usr/bin/env bash
# Build LastDayNav without replacing a working platform binary on failure.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p native/bin
CFLAGS=(-O2 -fPIC -Wall -Wno-unused-function -Inative/include)
TMP="$(mktemp -d native/bin/.lastday-nav-build.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
OS_NAME="$(uname -s)"
ARCH="$(uname -m)"
CC_BIN="${CC:-$(command -v cc || command -v clang || command -v gcc)}"
ZIG="$(command -v zig 2>/dev/null || true)"
case "$OS_NAME" in
  Darwin)
    CLANG="$(command -v clang)"
    "$CLANG" "${CFLAGS[@]}" -arch arm64 -arch x86_64 -dynamiclib \
      -o "$TMP/liblastday_nav.dylib" native/lastday_nav.c
    mv "$TMP/liblastday_nav.dylib" native/bin/liblastday_nav.dylib
    echo "built universal macOS dylib (arm64 + x86_64)"
    ;;
  Linux)
    "$CC_BIN" "${CFLAGS[@]}" -shared -o "$TMP/liblastday_nav.so" native/lastday_nav.c
    mv "$TMP/liblastday_nav.so" native/bin/liblastday_nav.so
    echo "built Linux $ARCH shared library"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    if [[ -z "$ZIG" ]]; then
      echo "Windows build requires zig cc; existing DLL preserved" >&2
      exit 1
    fi
    "$ZIG" cc "${CFLAGS[@]}" -shared -target x86_64-windows-gnu \
      -o "$TMP/lastday_nav.dll" native/lastday_nav.c
    mv "$TMP/lastday_nav.dll" native/bin/lastday_nav.dll
    echo "built Windows x86_64 DLL"
    ;;
  *)
    echo "Unsupported build host $OS_NAME/$ARCH; existing binaries preserved" >&2
    exit 1
    ;;
esac
# Cross-build optional targets only when zig is available. Temporary outputs
# ensure a failed cross-build cannot damage a previously valid target binary.
if [[ -n "$ZIG" ]]; then
  if [[ "$OS_NAME" != Darwin ]]; then
    if "$ZIG" cc "${CFLAGS[@]}" -shared -target aarch64-macos \
      -o "$TMP/liblastday_nav_arm64.dylib" native/lastday_nav.c && \
      "$ZIG" cc "${CFLAGS[@]}" -shared -target x86_64-macos \
      -o "$TMP/liblastday_nav_x86_64.dylib" native/lastday_nav.c; then
      # Do not replace the universal macOS binary using separately-linked pieces.
      rm -f "$TMP/liblastday_nav_arm64.dylib" "$TMP/liblastday_nav_x86_64.dylib"
    fi
  fi
  if [[ "$OS_NAME" != Linux ]]; then
    if "$ZIG" cc "${CFLAGS[@]}" -shared -target x86_64-linux-gnu \
      -o "$TMP/liblastday_nav.so" native/lastday_nav.c; then
      mv "$TMP/liblastday_nav.so" native/bin/liblastday_nav.so
      echo "built Linux x86_64 shared library (zig)"
    fi
  fi
  if [[ "$OS_NAME" != MINGW* && "$OS_NAME" != MSYS* && "$OS_NAME" != CYGWIN* ]]; then
    if "$ZIG" cc "${CFLAGS[@]}" -shared -target x86_64-windows-gnu \
      -o "$TMP/lastday_nav.dll" native/lastday_nav.c; then
      mv "$TMP/lastday_nav.dll" native/bin/lastday_nav.dll
      rm -f native/bin/lastday_nav.lib native/bin/lastday_nav.pdb
      echo "built Windows x86_64 DLL (zig)"
    fi
  fi
fi
# Keep manifest aligned with libraries actually present.
{
  echo '[configuration]'; echo; echo 'entry_symbol = "lastday_nav_library_init"';
  echo 'compatibility_minimum = "4.7"'; echo; echo '[libraries]'; echo
  [[ ! -f native/bin/liblastday_nav.dylib ]] || { echo 'macos.debug = "res://native/bin/liblastday_nav.dylib"'; echo 'macos.release = "res://native/bin/liblastday_nav.dylib"'; }
  [[ ! -f native/bin/lastday_nav.dll ]] || { echo 'windows.debug.x86_64 = "res://native/bin/lastday_nav.dll"'; echo 'windows.release.x86_64 = "res://native/bin/lastday_nav.dll"'; }
  [[ ! -f native/bin/liblastday_nav.so ]] || { echo 'linux.debug.x86_64 = "res://native/bin/liblastday_nav.so"'; echo 'linux.release.x86_64 = "res://native/bin/liblastday_nav.so"'; }
} > "$TMP/LastDayNav.gdextension"
mv "$TMP/LastDayNav.gdextension" native/LastDayNav.gdextension
