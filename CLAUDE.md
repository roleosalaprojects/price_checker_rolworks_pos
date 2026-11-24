# Price Checker (Rolworks POS) — Claude Code Guide

Standalone customer kiosk: price lookup by search/barcode, plus an employee
fingerprint/barcode **attendance** module. Backend: `../apex_backend` —
**read `../apex_backend/MASTERFILE.md` for the ecosystem map first.**

## Repo layout (important)
The actual Flutter project is **nested** at `price_checker/` — run all
`flutter` commands from that directory. `native/` holds the fingerprint
sidecar sources.

## Connectivity
- All HTTP goes to `http://{host}/api/desktop/...`
  (`price_checker/lib/services/http_service.dart`, const `apiRoute`).
  **No auth** — these are public LAN kiosk routes on the backend
  (`routes/api.php`, `desktop` prefix).
- Endpoints used: `GET /items/search?term=` (price lookup; product images from
  `http://{host}/{image}`), `GET /v1/attendance/lookup?barcode=`,
  `POST /v1/attendance/time-in|time-out`, `GET /v1/attendance/history|summary`
  (barcode; refused 403 "Use your fingerprint" once the store switches barcode
  punching off in the web admin → Locations).
- **Fingerprints (2026-11-25, done — replaces the July draft):** the kiosk is a
  registered terminal of the Apex backend (`/api/v1/device/*`, signed with
  HMAC — `lib/services/fingerprint/kiosk_terminal.dart`; Settings → *Register
  this kiosk* with a manager who holds the Fingerprints role switch). The
  enrolled prints come sealed (AES-GCM) and stay in memory; matching is done
  on the kiosk by the reader program `native/apex_fingerprint` (a **copy** of
  `apex_pos/native/apex_fingerprint` — change it there, then
  `native/apex_fingerprint/sync_from_pos.sh`). Tap **Fingerprint** → the
  finger → TIME IN / TIME OUT (`POST /api/v1/device/attendance/punch`).
  The reader is armed on a tap only: libfprint stops a reader left waiting
  ~4 min ("too hot"). Online only (no queue): "No connection — punch at the
  POS". Enrolment is on a POS (menu → Fingerprints). Backend spec:
  `../apex_backend/development/specs/apex_fingerprint_spec.md`.
- Config in Hive box `price_checker_settings`: `server_address`
  (default `localhost:8080`), `store_id` (default 1), `fingerprint_enabled`,
  `device_uuid` (the kiosk's id for its registration); the registration's
  secret is in `fingerprint_terminal.json` (chmod 600) in the app-support
  folder.

## Commands
- `cd price_checker && flutter run -d macos` (desktop kiosk)
- `flutter analyze` — the automated gate.

## Commit style (repo preference)
**No AI branding and no Co-Authored-By lines in commit messages** for this
repository (per `price_checker/CLAUDE.md`).

## Branch state
`dev` (= `master` before 2026-11-25) holds the fingerprint attendance;
feature branches merge `--no-ff` into `dev`.

## Linux
- Bundle: `price_checker/linux/packaging/build-in-docker.sh` (the POS repo's
  `apex-linux-build:3.35.5` image) → `price_checker/dist/price_checker-linux-x64/`,
  `apex_fingerprint` next to the app.
- On the kiosk PC, once: `setup_terminal.sh --fingerprint` from the POS
  bundle folder (libfprint, the udev rule for the 4500, fprintd masked).
- Live check: `price_checker/integration_test/docker/run_live.sh` (needs the
  DEMO Employee enrolled with the sample "whorl" — the POS's
  `fingerprint_live_test.dart` does it; clean up after).
