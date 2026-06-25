// DigitalPersona U.are.U backend (Windows). Built only when -DHAVE_DIGITALPERSONA
// is set and the U.are.U SDK (dpfpdd + dpfj) headers/libs are available.
//
// Produces ISO 19794-2 FMD templates, which are what the backend matcher and the
// Linux side should also standardize on for cross-platform matching (see the
// spec, "Open problems"). The flow below mirrors the standard DPFPDD capture +
// DPFJ feature-extraction sequence; verify exact signatures against your SDK
// version (they differ slightly across releases) before shipping.
#ifdef HAVE_DIGITALPERSONA

#include <dpfj.h>
#include <dpfpdd.h>

#include <vector>

#include "../include/fingerprint_device.h"
#include "base64.h"

namespace fpb {

std::unique_ptr<IFingerprintDevice> createMockDevice();  // fallback

class DigitalPersonaDevice : public IFingerprintDevice {
 public:
  ~DigitalPersonaDevice() override {
    if (reader_) dpfpdd_close(reader_);
    dpfpdd_exit();
  }

  bool open(std::string& nameOut, std::string& formatOut) override {
    if (dpfpdd_init() != DPFPDD_SUCCESS) return false;

    unsigned int count = 0;
    if (dpfpdd_query_devices(&count, nullptr) != DPFPDD_E_MORE_DATA || count == 0) {
      return false;
    }
    std::vector<dpfpdd_dev_info> devices(count);
    if (dpfpdd_query_devices(&count, devices.data()) != DPFPDD_SUCCESS) return false;

    if (dpfpdd_open(devices[0].name, &reader_) != DPFPDD_SUCCESS) return false;

    nameOut = "U.are.U 4500";
    formatOut = kFormat;
    return true;
  }

  CaptureResult capture(const std::string& /*mode*/, int timeoutMs,
                        const std::function<void()>& onPlaced) override {
    CaptureResult r;
    r.format = kFormat;

    dpfpdd_capture_param cap{};
    cap.size = sizeof(cap);
    cap.image_fmt = DPFPDD_IMG_FMT_ISOIEC19794;
    cap.image_proc = DPFPDD_IMG_PROC_DEFAULT;
    cap.image_res = 500;

    std::vector<unsigned char> image(512 * 1024);
    unsigned int imageSize = static_cast<unsigned int>(image.size());
    dpfpdd_capture_result capRes{};
    capRes.size = sizeof(capRes);

    int rc = dpfpdd_capture(reader_, &cap, static_cast<unsigned int>(timeoutMs),
                            &capRes, &imageSize, image.data());
    if (rc != DPFPDD_SUCCESS) {
      r.errorCode = (rc == DPFPDD_E_TIMEOUT) ? "TIMEOUT" : "SDK_ERROR";
      r.errorMessage = "dpfpdd_capture failed";
      return r;
    }
    if (onPlaced) onPlaced();

    if (capRes.quality != DPFPDD_QUALITY_GOOD) {
      r.errorCode = "LOW_QUALITY";
      r.errorMessage = "Poor capture quality, try again";
      return r;
    }

    std::vector<unsigned char> fmd(DPFJ_MAX_FMD_SIZE);
    unsigned int fmdSize = static_cast<unsigned int>(fmd.size());
    int fr = dpfj_create_fmd_from_fid(DPFJ_FMD_ISO_19794_2_2005, image.data(),
                                      imageSize, DPFJ_FMD_ISO_19794_2_2005,
                                      fmd.data(), &fmdSize);
    if (fr != DPFJ_SUCCESS) {
      r.errorCode = "SDK_ERROR";
      r.errorMessage = "dpfj_create_fmd_from_fid failed";
      return r;
    }
    fmd.resize(fmdSize);

    r.ok = true;
    r.quality = 90;
    r.templateB64 = base64Encode(fmd);
    return r;
  }

  std::string backendName() const override { return "digitalpersona"; }

 private:
  static constexpr const char* kFormat = "ISO-19794-2";
  DPFPDD_DEV reader_ = nullptr;
};

std::unique_ptr<IFingerprintDevice> createDevice() {
  auto dev = std::make_unique<DigitalPersonaDevice>();
  std::string name, format;
  if (dev->open(name, format)) return dev;
  // No reader present — fall back to mock so the app still runs.
  return createMockDevice();
}

}  // namespace fpb

#endif  // HAVE_DIGITALPERSONA
