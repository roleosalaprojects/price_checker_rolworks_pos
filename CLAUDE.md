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
  `POST /v1/attendance/time-in|time-out`, `GET /v1/attendance/history|summary`,
  `POST /v1/attendance/identify` (fingerprint).
- **KNOWN GAP (work started 2026-07-15):** `POST /api/desktop/v1/attendance/identify`
  does not exist on the backend's `dev` yet. Backend branch
  `feature/desktop-attendance-identify` has the started work (fingerprint
  storage migration + model); the contract and remaining steps are in
  `../apex_backend/development/specs/desktop_fingerprint_identify_wip.md`.
  Finish that branch before shipping `feature/fingerprint-attendance`.
- Config in Hive box `price_checker_settings`: `server_address`
  (default `localhost:8080`), `store_id` (default 1), fingerprint settings —
  editable via the in-app settings dialog.
- Fingerprint hardware is reached through a local native **sidecar child
  process** (newline-delimited JSON over stdio,
  `lib/services/fingerprint_service.dart`) — not over the network.

## Commands
- `cd price_checker && flutter run -d macos` (desktop kiosk)
- `flutter analyze` — the automated gate.

## Commit style (repo preference)
**No AI branding and no Co-Authored-By lines in commit messages** for this
repository (per `price_checker/CLAUDE.md`).

## Branch state
Currently on `feature/fingerprint-attendance` (attendance module in
progress). Base branch: `main`.
