# fingerprint_bridge

Native capture sidecar for the **U.are.U 4500** fingerprint reader. The Price
Checker Flutter app spawns this executable and talks to it over a
newline-delimited JSON protocol on **stdin/stdout**. Matching/enrollment happen
in `apex_backend`; this process only captures and emits a base64 template.

See `../../development/fingerprint_attendance_spec.md` for the end-to-end design.

## Backends

| Backend          | Platform | Build flag               | Template format |
|------------------|----------|--------------------------|-----------------|
| `mock`           | any      | *(default)*              | `MOCK`          |
| `digitalpersona` | Windows  | `-DHAVE_DIGITALPERSONA=ON` | `ISO-19794-2` |
| `libfprint`      | Linux    | `-DHAVE_LIBFPRINT=ON`    | `libfprint`     |

The SDK backends fall back to `mock` automatically if no reader is connected, so
the app keeps running. `mock` compiles everywhere (incl. macOS) and emits a
deterministic template — pair it with the backend's `exact` matcher to demo the
whole chain without hardware.

> ⚠️ DigitalPersona FMD and libfprint templates are **not** interchangeable. For
> a deployment that mixes Windows and Linux stations, standardize on one SDK.

## Build

```bash
# Mock (any OS, no SDK):
cmake -S . -B build && cmake --build build
# or without cmake:
clang++ -std=c++17 -Iinclude -Isrc src/main.cpp src/mock_device.cpp -o build/fingerprint_bridge

# Windows (DigitalPersona U.are.U SDK installed):
cmake -S . -B build -DHAVE_DIGITALPERSONA=ON -DDP_SDK_DIR="C:/Program Files/DigitalPersona/SDK"
cmake --build build --config Release

# Linux (libfprint-2 + glib-2.0 dev packages):
sudo apt install libfprint-2-dev libglib2.0-dev cmake g++
cmake -S . -B build -DHAVE_LIBFPRINT=ON && cmake --build build
```

The Flutter app looks for the binary next to the executable (see
`FingerprintService`); copy `build/fingerprint_bridge` (or `.exe`) into the app
bundle's runtime dir, or set the `fingerprint_sidecar_path` setting.

## Protocol (quick reference)

Commands (app → sidecar), one JSON object per line:

```jsonc
{"cmd":"status"}
{"cmd":"capture","mode":"identify","timeoutMs":15000}
{"cmd":"cancel"}
{"cmd":"quit"}
```

Events (sidecar → app):

```jsonc
{"event":"ready","version":"1.0.0","backend":"mock"}
{"event":"device","connected":true,"name":"U.are.U 4500","format":"ISO-19794-2"}
{"event":"placed"}
{"event":"captured","format":"ISO-19794-2","quality":85,"template":"<base64>"}
{"event":"error","code":"NO_DEVICE|TIMEOUT|LOW_QUALITY|SDK_ERROR","message":"..."}
```

## Testing the mock

```bash
printf '{"cmd":"capture"}\n{"cmd":"quit"}\n' | ./build/fingerprint_bridge
# FP_MOCK_ID overrides the simulated employee identity (default 0001):
printf '{"cmd":"capture"}\n{"cmd":"quit"}\n' | FP_MOCK_ID=0042 ./build/fingerprint_bridge
```
