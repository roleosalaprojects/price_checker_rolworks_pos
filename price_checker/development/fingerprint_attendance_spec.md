> **Superseded 2026-11-25.** Built differently: matching on the kiosk (the
> reader program scores with NIST bozorth3), prints enrolled on a POS and
> served sealed to registered terminals, punches signed by the terminal. See
> `../apex_backend/development/specs/apex_fingerprint_spec.md` and the root
> `CLAUDE.md`. Kept for the record.

# Fingerprint Attendance — Design & Contract Spec

Status: **DRAFT / exploratory** (branch `feature/fingerprint-attendance` in both
`price_checker` and `apex_backend`).

Adds **U.are.U 4500** fingerprint identification to the Price Checker attendance
(time-in / time-out) flow, alongside the existing employee **barcode** scan
(barcode stays as a fallback).

> Enrollment + matching live in **apex_backend**. The Price Checker only
> *captures* a fingerprint and asks the backend "who is this?".

---

## 1. Components

```
┌──────────────────┐   USB    ┌─────────────────────┐  stdin/stdout   ┌──────────────────┐   HTTP    ┌──────────────┐
│  U.are.U 4500    │ ───────► │  Sidecar helper     │ ◄────JSON lines►│  Price Checker   │ ────────► │  apex_backend │
│  (fingerprint)   │          │  (native, per-OS)   │                 │  (Flutter app)   │           │  (Laravel)    │
└──────────────────┘          └─────────────────────┘                 └──────────────────┘           └──────────────┘
```

- **Sidecar helper** — a small native executable per OS that owns the device and
  the vendor SDK. Windows: DigitalPersona U.are.U SDK. Linux: libfprint (or the
  DigitalPersona Linux SDK — see §5). Emits a base64 **template** to stdout.
- **Price Checker (Flutter)** — spawns the sidecar as a child process, speaks the
  JSON-line protocol over stdin/stdout, and POSTs the captured template to the
  backend.
- **apex_backend (Laravel)** — stores enrolled templates, matches a captured
  template to an employee (1:N identify), and reuses the existing attendance
  endpoints for the actual time-in / time-out.

Why a sidecar (not in-runner native): decouples the vendor SDK from the Flutter
build, lets the device code be developed/tested independently, and keeps the
Flutter app buildable on machines without the SDK (incl. this macOS dev box,
which has no usable U.are.U SDK).

---

## 2. Sidecar protocol (stdin/stdout, newline-delimited JSON)

The app launches the sidecar binary and keeps it running. One JSON object per
line. App → sidecar = **commands**; sidecar → app = **events**.

### Commands (app → sidecar)
```jsonc
{"cmd":"status"}                                  // ask for device state
{"cmd":"capture","mode":"identify","timeoutMs":15000}
{"cmd":"capture","mode":"enroll","timeoutMs":20000} // enroll may need N placements
{"cmd":"cancel"}                                  // cancel in-flight capture
```

### Events (sidecar → app)
```jsonc
{"event":"ready","version":"1.0.0","backend":"mock|digitalpersona|libfprint"}
{"event":"device","connected":true,"name":"U.are.U 4500","format":"ISO-19794-2"}
{"event":"placed"}                                // finger detected on sensor
{"event":"progress","captured":2,"needed":4}      // enroll multi-capture progress
{"event":"captured","format":"ISO-19794-2","quality":85,"template":"<base64>"}
{"event":"error","code":"NO_DEVICE|TIMEOUT|LOW_QUALITY|SDK_ERROR","message":"..."}
```

Notes:
- `template` is base64. Its `format` string MUST be stored with it so the backend
  matcher knows how to compare (DigitalPersona FMD vs libfprint blobs are **not**
  interchangeable — see §5).
- The sidecar process exiting (or never starting) is a normal condition: the app
  falls back to barcode-only and shows the reader as unavailable.

---

## 3. Backend contract (apex_backend)

Base path mirrors the existing desktop API: `/api/desktop/...`
(Flutter `apiRoute = "/api/desktop"`).

### 3.1 Identify (used by attendance) — NEW
`POST /api/desktop/v1/attendance/identify`
```jsonc
// request
{"template":"<base64>","format":"ISO-19794-2"}
// 200 — same shape as /v1/attendance/lookup so the app reuses one code path
{
  "success": true,
  "data": {
    "employee": {"id": 12, "name": "Jane Cruz", "barcode": "EMP00012"},
    "today_status": {
      "has_timed_in": true, "has_timed_out": false,
      "time_in": "08:01 AM", "time_out": null, "hours_rendered": 0
    }
  }
}
// 404 — no match above threshold
{"success": false, "message": "Fingerprint not recognized."}
```
The app then calls the **existing** `POST /v1/attendance/time-in` /
`time-out` with the returned `barcode` — no change to those endpoints.

### 3.2 Enrollment / management — NEW
```
POST   /api/desktop/v1/fingerprint/enroll   {"barcode":"EMP00012","template":"<b64>","format":"...","quality":85,"finger":"right-index"}
GET    /api/desktop/v1/fingerprint/list?barcode=EMP00012
DELETE /api/desktop/v1/fingerprint/{id}
```

### 3.3 Storage
New table `fingerprint_templates`:
| column   | type                | notes                                  |
|----------|---------------------|----------------------------------------|
| id       | bigint pk           |                                        |
| user_id  | fk users.id         | cascade on delete                      |
| finger   | string nullable     | e.g. `right-index`                     |
| format   | string              | template format id (matcher key)       |
| template | longText            | base64 template                        |
| quality  | unsignedTinyInteger nullable |                               |
| timestamps |                   |                                        |

Employee identity stays keyed on `users.code` (the existing barcode), so identify
just resolves a template → `user` → returns `user.code` as `barcode`.

### 3.4 Matching
PHP has no native fingerprint matcher, so matching is behind an interface
`App\Services\Fingerprint\FingerprintMatcher`:
- `identify(string $probe, string $format): ?int` → user_id, or null.
- Implementations:
  - `ExecMatcher` — shells out to a configured matcher binary
    (`FINGERPRINT_MATCHER_BIN`) that does DPFJ/libfprint comparison and prints the
    matched user id. **Production path.**
  - `ExactMatcher` — dev/test only: matches on exact template equality (works when
    the same captured bytes are replayed; **not** real biometric matching). Lets
    the full flow be exercised end-to-end without the SDK.
- Selected via config `fingerprint.matcher` (`exec` | `exact`).

This is the **main open problem** to resolve on this branch — see §5.

---

## 4. App behaviour (Price Checker)

On `AttendancePage`:
- `FingerprintService` starts the sidecar and listens. A status chip shows
  reader state (scanning / unavailable).
- On `captured` → `POST /v1/attendance/identify` → on match, drive the **existing**
  lookup → time-in/out UI (employee card + action button).
- The **barcode TextField stays** as a fallback and keeps working unchanged.
- macOS / missing binary / no device → fingerprint silently disabled, barcode only.

Settings (Hive, alongside host/store): `fingerprint_enabled` (bool),
`fingerprint_sidecar_path` (string, optional override of the bundled binary).

---

## 5. Open problems / decisions to finalize on this branch

1. **Template format across OS.** DigitalPersona (Windows) and libfprint (Linux)
   templates are **not** cross-compatible. Options:
   a. Use the **DigitalPersona SDK on both** Windows and Linux → one format
      (ISO 19794-2 FMD), backend matcher is uniform. *Preferred.*
   b. Allow both formats, store `format`, and require enroll+identify to happen on
      the same OS family per store. Simpler device side, fragile data side.
2. **Matcher engine on the backend.** `ExecMatcher` needs a real comparison binary
   (DPFJ_compare / libfprint). Build it from the same SDK as the sidecar, or run a
   matching microservice. Until then `ExactMatcher` unblocks development.
3. **1:N performance.** Linear scan of all templates is fine for a single store /
   small staff; revisit (indexing / vendor identify API) if employee count grows.
4. **Liveness / spoofing** — out of scope for v1.

---

## 6. Testability without hardware

The sidecar ships a **`mock` backend** (compiles on Windows/Linux/macOS) that
emits deterministic fake templates on `capture`. Combined with the backend
`ExactMatcher`, the entire chain (app → sidecar → backend → attendance) can be
demoed on this macOS dev box before the real SDK is wired in.
