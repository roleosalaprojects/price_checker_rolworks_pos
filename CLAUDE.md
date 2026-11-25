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
  POS". Enrolment is on a POS (menu → Fingerprints), at an enrol station, or
  here since 1.1.0 (below). Backend spec:
  `../apex_backend/development/specs/apex_fingerprint_spec.md`.
- **Higher access (1.1.0+2, 2026-11-25, spec §3c):** a manager approves with a
  finger (matched at sign-in level) or e-mail + password
  (`lib/pages/fingerprint/higher_access_dialog.dart` → `POST
  /api/v1/device/higher-access`); the server answers with a 10-minute grant
  (`KioskGrant`, sent as `X-Apex-Grant`) for one purpose:
  - `enrol` (Fingerprints switch): the fingerprint icon in the attendance
    page's header → *Add fingerprints* (`lib/pages/fingerprint/enrol_page.dart`:
    the staff list, consent, 5 presses, no finger that is someone else's, a
    check press — the POS's enrolment) → `POST /api/v1/device/enrol`;
  - `settings` (Settings switch): the gear (`openSettingsGuarded` in
    `price_checker_page_controller.dart`) asks once the kiosk is registered
    and the server answers (signed `device/me`, 3 s); a kiosk that can't reach
    the server opens Settings without asking (the owner's "way back in" — a
    wrong address must stay fixable). The gallery is refreshed first, so a
    finger works right after a restart.
  Tests `test/higher_access_test.dart`.
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
  POS's `fingerprint_live_test.dart` run first: the DEMO Employee's "whorl",
  the demo admin's "tented_arch", the Demo Cashier's "loop-right"; delete the
  DEMO Employee's punch that run made, or TIME IN is not offered; at the
  production thresholds 40/55/10 — at 30/40 the sample "arch" is taken for
  someone). It punches
  the DEMO Employee in, opens Settings on the admin's finger, refuses the Demo
  Cashier's for Add fingerprints and enrols "arch" for the DEMO Employee;
  clean up after both (the run's devices, prints and the DEMO Employee's
  punches — never the owner's own prints or punches).
- macOS (testing with the real 4500 on the office Mac): deployment target
  12.0 (pods too), sandbox off in `DebugProfile.entitlements`; build in
  profile, arm64 only (`FLUTTER_XCODE_ARCHS=arm64
  FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES flutter build macos --profile`), run the
  app binary with `APEX_FP_BIN` pointing at the POS's Mac reader build. One
  program holds the reader at a time.
