#!/bin/bash
# Rebuilds tools/web/index.html for the .23 downloads page:
#   - replaces the block between <!-- CAMBIOS:BEGIN --> and <!-- CAMBIOS:END -->
#     with a version list generated from git log (v<hash> + date + subject)
#   - substitutes @VERSION@ with the current short HEAD hash
#   - substitutes @SIZE_MACOS@, @SIZE_WINDOWS@, @SIZE_LINUX@ with the sizes of
#     build/dist/LastDay-macOS.zip, build/dist/LastDay-Windows.zip and
#     build/dist/LastDay-Linux.x86_64 when they exist (falls back to "? GB")
#
# Usage: tools/web/update_index.sh [output]
#   tools/web/index.html is the tracked TEMPLATE (keeps @PLACEHOLDERS@);
#   the rendered page goes to build/dist/index.html unless a path is passed.
set -euo pipefail
cd "$(dirname "$0")/../.."

INDEX="tools/web/index.html"
OUT="${1:-build/dist/index.html}"
VERSION="$(git rev-parse --short HEAD)"
TMP="$(mktemp build/tmp/cambios.XXXXXX.html)"
trap 'rm -f "$TMP"' EXIT

size_gb() {
	# $1 = file; prints like "2.3 GB" or "? GB"
	if [ -f "$1" ]; then
		local bytes
		bytes=$(stat -f%z "$1" 2>/dev/null || stat -c%s "$1")
		awk -v b="$bytes" 'BEGIN { printf "%.1f GB", b/1000000000 }'
	else
		printf "? GB"
	fi
}

{
	echo '  <section class="bloque" id="cambios">'
	echo '    <h3>Cambios por versión</h3>'
	echo '    <ul class="verlist">'
	git log --pretty=format:'      <li><b>v%h</b><span class="vdate">%ad</span><span class="vsub">%s</span></li>' --date=format:'%d/%m/%y' -15
	echo
	echo '    </ul>'
	echo '  </section>'
} > "$TMP"

awk -v block_file="$TMP" '
	/<!-- CAMBIOS:BEGIN -->/ {
		print
		while ((getline line < block_file) > 0) print line
		close(block_file)
		skip = 1
		next
	}
	/<!-- CAMBIOS:END -->/ { skip = 0; print; next }
	!skip { print }
' "$INDEX" | sed \
	-e "s/@VERSION@/$VERSION/g" \
	-e "s/@SIZE_MACOS@/$(size_gb build/dist/LastDay-macOS.zip)/g" \
	-e "s/@SIZE_WINDOWS@/$(size_gb build/dist/LastDay-Windows.zip)/g" \
	-e "s/@SIZE_LINUX@/$(size_gb build/dist/LastDay-Linux.x86_64)/g" \
	> "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
echo "index.html regenerated (v$VERSION) -> $OUT"
