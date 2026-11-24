#!/usr/bin/env bash
# Copies the reader program from the POS repo (the source of truth).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
POS="${APEX_POS_REPO:-$HERE/../../../../apex_pos}/native/apex_fingerprint"
[ -f "$POS/src/main.c" ] || { echo "apex_pos not found at $POS (set APEX_POS_REPO)"; exit 1; }
rm -rf "$HERE/src" "$HERE/third_party"
cp -R "$POS/src" "$POS/third_party" "$POS/CMakeLists.txt" "$HERE/"
echo "Copied from $POS"
