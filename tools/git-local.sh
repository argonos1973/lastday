#!/usr/bin/env sh
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec git --git-dir="/Users/sami/Documents/Codex/un-dia-mas.git" --work-tree="$ROOT_DIR" "$@"
