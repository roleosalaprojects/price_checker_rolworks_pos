// Mock fingerprint backend — compiles on every platform (incl. macOS) and
// needs no hardware. It emits a deterministic template so the full chain
// (app -> sidecar -> backend ExactMatcher -> attendance) can be demoed end to
// end before the vendor SDK is wired in.
//
// The template identity can be overridden with the env var FP_MOCK_ID, so two
// machines (enroll station + clock station) can simulate the same or different
// employees. Default identity is "0001".
#include <chrono>
#include <cstdlib>
#include <thread>

#include "../include/fingerprint_device.h"
#include "base64.h"

namespace fpb {

class MockDevice : public IFingerprintDevice {
 public:
  bool open(std::string& nameOut, std::string& formatOut) override {
    nameOut = "Mock U.are.U 4500";
    formatOut = "MOCK";
    return true;
  }

  CaptureResult capture(const std::string& /*mode*/, int /*timeoutMs*/,
                        const std::function<void()>& onPlaced) override {
    // Simulate the brief delay before a finger lands on the sensor.
    std::this_thread::sleep_for(std::chrono::milliseconds(400));
    if (onPlaced) onPlaced();
    std::this_thread::sleep_for(std::chrono::milliseconds(300));

    const char* id = std::getenv("FP_MOCK_ID");
    std::string identity = id && *id ? id : "0001";

    CaptureResult r;
    r.ok = true;
    r.format = "MOCK";
    // Stable bytes per identity so enroll and identify produce equal templates.
    r.templateB64 = base64Encode("MOCK-FINGERPRINT-" + identity);
    r.quality = 92;
    return r;
  }

  std::string backendName() const override { return "mock"; }
};

#if !defined(HAVE_DIGITALPERSONA) && !defined(HAVE_LIBFPRINT)
std::unique_ptr<IFingerprintDevice> createDevice() {
  return std::make_unique<MockDevice>();
}
#endif

// Exposed so SDK backends can fall back to mock when no reader is present.
std::unique_ptr<IFingerprintDevice> createMockDevice() {
  return std::make_unique<MockDevice>();
}

}  // namespace fpb
