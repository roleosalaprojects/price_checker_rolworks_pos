#!/usr/bin/env bash
# The kiosk's Linux bundle from the Mac, in the POS repo's build image
# (apex-linux-build:3.35.5: Flutter, GTK, libfprint-2-dev, libjson-glib-dev).
# Builds a clean copy of HEAD → dist/price_checker-linux-x64/, with
# apex_fingerprint next to the app.
#   price_checker/linux/packaging/build-in-docker.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
(cd "$ROOT" && git archive HEAD) | tar -x -C "$WORK"
docker run --rm --platform linux/amd64 -v "$WORK":/work -w /work apex-linux-build:3.35.5 \
  bash -c 'cp -a /work /tmp/w && cd /tmp/w && flutter pub get >/dev/null && flutter build linux --release && cp -a build/linux/x64/release/bundle /work/bundle'
rm -rf "$ROOT/dist/price_checker-linux-x64"; mkdir -p "$ROOT/dist"
cp -a "$WORK/bundle" "$ROOT/dist/price_checker-linux-x64"
ls -l "$ROOT/dist/price_checker-linux-x64"
