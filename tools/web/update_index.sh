#!/bin/bash
# Rebuilds the .23 downloads page (ES + EN):
#   - replaces the block between <!-- CAMBIOS:BEGIN --> and <!-- CAMBIOS:END -->
#     in each template with a version list generated from git log
#     (v<hash> + date + description). Descriptions come from
#     tools/web/changelog_es.txt / changelog_en.txt (hash|texto); a missing
#     entry falls back to the other language and then to the raw subject.
#   - substitutes @VERSION@ with the current short HEAD hash
#   - substitutes @SIZE_MACOS@, @SIZE_WINDOWS@, @SIZE_LINUX@ with the sizes of
#     build/dist/LastDay-macOS.zip, build/dist/LastDay-Windows.zip and
#     build/dist/LastDay-Linux.x86_64 when they exist (falls back to "? GB")
#
# Usage: tools/web/update_index.sh
#   tools/web/index.html / index_en.html are the tracked TEMPLATES
#   (they keep @PLACEHOLDERS@); rendered pages go to build/dist/.
#   VERSION_OVERRIDE=<hash> overrides the badge (published binaries' hash).
set -euo pipefail
cd "$(dirname "$0")/../.."

# VERSION_OVERRIDE lets the page badge name the version of the published
# binaries even when HEAD already has newer non-exported commits.
VERSION="${VERSION_OVERRIDE:-$(git rev-parse --short HEAD)}"
mkdir -p build/tmp build/dist

CHANGELOG_ES="tools/web/changelog_es.txt"
CHANGELOG_EN="tools/web/changelog_en.txt"

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

lookup_lang() {
	# $1 = commit hash, $2 = changelog file; prints the text or empty
	[ -f "$2" ] || return 0
	awk -F'|' -v h="$1" '!/^#/ && $1 == h { sub(/^[^|]*\|/, ""); print; exit }' "$2"
}

html_escape() {
	printf '%s' "$1" | sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

render() {
	# $1 = template, $2 = primary changelog, $3 = section title, $4 = output
	local INDEX="$1" CL_PRIMARY="$2" H3="$3" OUT="$4"
	local TMP
	TMP="$(mktemp build/tmp/cambios.XXXXXX.html)"

	{
		echo '  <section class="bloque" id="cambios">'
		echo "    <h3>$H3</h3>"
		echo '    <ul class="verlist">'
		git log --pretty=tformat:'%h|%ad|%s' --date=format:'%d/%m/%y' -60 \
			| grep -vEi '\|(changelog|cambios web|web es|idioma|lang(s|uage)? selector|Historial de cambios|AGENTS\.md:|Documenta que |Añade PrimitiveCarryPreview)' \
			| awk 'NR <= 15' \
			| while IFS='|' read -r h d s; do
			txt="$(lookup_lang "$h" "$CL_PRIMARY")"
			[ -n "$txt" ] || txt="$(lookup_lang "$h" "$CHANGELOG_ES")"
			[ -n "$txt" ] || txt="$s"
			printf '      <li><b>v%s</b><span class="vdate">%s</span><span class="vsub">%s</span></li>\n' \
				"$h" "$d" "$(html_escape "$txt")"
		done
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
	rm -f "$TMP"
	echo "$(basename "$OUT") regenerated (v$VERSION)"
}

render "tools/web/index.html"    "$CHANGELOG_ES" "Cambios por versión" "build/dist/index.html"
render "tools/web/index_en.html" "$CHANGELOG_EN" "Changes by version" "build/dist/index_en.html"
