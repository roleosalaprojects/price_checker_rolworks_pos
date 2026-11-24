#!/usr/bin/env bash
# The kiosk's live fingerprint check: the Linux app under Xvfb in the POS
# repo's apex-fingerprint-test image (libfprint's virtual reader), against
# the LOCAL Apex backend at host.docker.internal — never production.
#   price_checker/integration_test/docker/run_live.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POS="${APEX_POS_REPO:-$ROOT/../../apex_pos}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
rsync -a --exclude build --exclude .dart_tool --exclude .git "$ROOT/" "$WORK/src/"
cp "$POS/integration_test/docker/fp_prints.py" "$WORK/"
docker run --rm --platform linux/amd64 -v "$WORK":/work apex-fingerprint-test bash -c '
  set -u; OUT=/work/out; mkdir -p "$OUT" "$HOME/Documents" "$HOME/bin"
  printf "#!/bin/sh\necho \"\$HOME/Documents\"\n" > "$HOME/bin/xdg-user-dir"; chmod +x "$HOME/bin/xdg-user-dir"; export PATH="$HOME/bin:$PATH"
  dbus-uuidgen --ensure; export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 NO_AT_BRIDGE=1
  Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 & sleep 2
  eval "$(dbus-launch --sh-syntax)"
  mkdir -p /tmp/fp && python3 /work/fp_prints.py /opt/libfprint-test/prints /tmp/fp/prints
  export FP_VIRTUAL_IMAGE=/tmp/fp/virtual-image.socket APEX_FP_DRIVER=virtual_image FP_VIRTUAL_IMAGE_HOT_SECONDS=-1 \
    APEX_FP_PRINTS=/tmp/fp/prints LD_LIBRARY_PATH=/opt/libfprint-test/lib
  cp -a /work/src /tmp/src && cd /tmp/src && flutter pub get >/dev/null
  flutter test integration_test/kiosk_fingerprint_live_test.dart -d linux --dart-define=APEX_HOST=host.docker.internal > "$OUT/kiosk_live.log" 2>&1
  echo "kiosk_fingerprint_live_test exit $?" | tee "$OUT/summary.log"'
mkdir -p "$ROOT/build/live"; rm -rf "$ROOT/build/live/kiosk"; cp -R "$WORK/out" "$ROOT/build/live/kiosk"
cat "$ROOT/build/live/kiosk/summary.log"
