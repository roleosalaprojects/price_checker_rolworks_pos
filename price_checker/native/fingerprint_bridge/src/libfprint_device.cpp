// libfprint backend (Linux). Built only when -DHAVE_LIBFPRINT is set and
// libfprint-2 (+ glib-2.0) dev packages are available.
//
// NOTE: libfprint's serialized prints are NOT format-compatible with
// DigitalPersona FMDs. If a deployment enrolls on Windows and clocks in on
// Linux (or vice versa), standardize on ONE SDK across both — see the spec's
// "Open problems". This backend reports its format as "libfprint" so the
// backend matcher never compares across incompatible formats by accident.
#ifdef HAVE_LIBFPRINT

#include <fprint.h>
#include <glib.h>

#include <vector>

#include "../include/fingerprint_device.h"
#include "base64.h"

namespace fpb {

std::unique_ptr<IFingerprintDevice> createMockDevice();  // fallback

class LibfprintDevice : public IFingerprintDevice {
 public:
  ~LibfprintDevice() override {
    if (dev_) {
      fp_device_close_sync(dev_, nullptr, nullptr);
      g_object_unref(dev_);
    }
    if (ctx_) fp_context_unref(ctx_);
  }

  bool open(std::string& nameOut, std::string& formatOut) override {
    ctx_ = fp_context_new();
    GPtrArray* devices = fp_context_get_devices(ctx_);
    if (!devices || devices->len == 0) return false;

    dev_ = FP_DEVICE(g_ptr_array_index(devices, 0));
    g_object_ref(dev_);
    if (!fp_device_open_sync(dev_, nullptr, nullptr)) return false;

    nameOut = fp_device_get_name(dev_) ? fp_device_get_name(dev_) : "U.are.U 4500";
    formatOut = kFormat;
    return true;
  }

  CaptureResult capture(const std::string& /*mode*/, int /*timeoutMs*/,
                        const std::function<void()>& onPlaced) override {
    CaptureResult r;
    r.format = kFormat;

    if (onPlaced) onPlaced();

    FpPrint* print = nullptr;
    GError* err = nullptr;
    gboolean ok = fp_device_capture_sync(dev_, /*wait_for_finger=*/TRUE, nullptr,
                                         nullptr, &print);
    if (!ok || !print) {
      r.errorCode = "SDK_ERROR";
      r.errorMessage = err ? err->message : "fp_device_capture_sync failed";
      if (err) g_error_free(err);
      return r;
    }

    guchar* data = nullptr;
    gsize len = 0;
    if (!fp_print_serialize(print, &data, &len, &err)) {
      r.errorCode = "SDK_ERROR";
      r.errorMessage = err ? err->message : "fp_print_serialize failed";
      if (err) g_error_free(err);
      g_object_unref(print);
      return r;
    }

    std::vector<unsigned char> bytes(data, data + len);
    g_free(data);
    g_object_unref(print);

    r.ok = true;
    r.quality = 85;
    r.templateB64 = base64Encode(bytes);
    return r;
  }

  std::string backendName() const override { return "libfprint"; }

 private:
  static constexpr const char* kFormat = "libfprint";
  FpContext* ctx_ = nullptr;
  FpDevice* dev_ = nullptr;
};

std::unique_ptr<IFingerprintDevice> createDevice() {
  auto dev = std::make_unique<LibfprintDevice>();
  std::string name, format;
  if (dev->open(name, format)) return dev;
  return createMockDevice();
}

}  // namespace fpb

#endif  // HAVE_LIBFPRINT
