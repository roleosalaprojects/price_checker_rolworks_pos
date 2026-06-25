// Device abstraction for the fingerprint capture sidecar.
//
// One concrete backend is selected at build time:
//   - MockDevice          (always available; deterministic, no hardware)
//   - DigitalPersonaDevice (Windows, -DHAVE_DIGITALPERSONA, U.are.U SDK)
//   - LibfprintDevice     (Linux, -DHAVE_LIBFPRINT, libfprint)
//
// The sidecar speaks a newline-delimited JSON protocol on stdin/stdout; see
// README.md and development/fingerprint_attendance_spec.md for the wire format.
#ifndef FINGERPRINT_DEVICE_H
#define FINGERPRINT_DEVICE_H

#include <functional>
#include <memory>
#include <string>

namespace fpb {

struct CaptureResult {
  bool ok = false;
  std::string format;        // template format id, e.g. "ISO-19794-2" / "MOCK"
  std::string templateB64;   // base64-encoded template (when ok)
  int quality = 0;           // 0..100
  std::string errorCode;     // NO_DEVICE | TIMEOUT | LOW_QUALITY | SDK_ERROR
  std::string errorMessage;
};

// Abstract fingerprint reader. Implementations are synchronous: capture()
// blocks until a finger is read, the timeout elapses, or an error occurs.
class IFingerprintDevice {
 public:
  virtual ~IFingerprintDevice() = default;

  // Open the device. Returns true if a reader is connected. Fills the human
  // name and the template format this backend produces.
  virtual bool open(std::string& nameOut, std::string& formatOut) = 0;

  // Capture a fingerprint. `mode` is "identify" or "enroll". `onPlaced` is
  // invoked once a finger is detected (so the caller can emit a "placed" event).
  virtual CaptureResult capture(const std::string& mode, int timeoutMs,
                                const std::function<void()>& onPlaced) = 0;

  // Short backend id for the "ready" event: mock | digitalpersona | libfprint.
  virtual std::string backendName() const = 0;
};

// Build the backend chosen at compile time (falls back to MockDevice).
std::unique_ptr<IFingerprintDevice> createDevice();

}  // namespace fpb

#endif  // FINGERPRINT_DEVICE_H
