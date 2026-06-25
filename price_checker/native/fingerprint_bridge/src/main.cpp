// Fingerprint capture sidecar entry point.
//
// Speaks newline-delimited JSON on stdin/stdout. The Flutter app spawns this
// process, writes commands to stdin, and reads events from stdout. See
// development/fingerprint_attendance_spec.md for the full protocol.
#include <iostream>
#include <memory>
#include <string>

#include "../include/fingerprint_device.h"
#include "json_util.h"

using namespace fpb;

static void emit(const std::string& json) {
  std::cout << json << "\n";
  std::cout.flush();
}

static std::string deviceEvent(bool connected, const std::string& name,
                               const std::string& format) {
  std::string ev = "{\"event\":\"device\",\"connected\":";
  ev += connected ? "true" : "false";
  ev += ",\"name\":\"" + jsonEscape(name) + "\",\"format\":\"" +
        jsonEscape(format) + "\"}";
  return ev;
}

int main() {
  auto device = createDevice();
  std::string name, format;
  bool connected = device->open(name, format);

  emit("{\"event\":\"ready\",\"version\":\"1.0.0\",\"backend\":\"" +
       jsonEscape(device->backendName()) + "\"}");
  emit(deviceEvent(connected, name, format));

  std::string line;
  while (std::getline(std::cin, line)) {
    if (line.empty()) continue;
    const std::string cmd = jsonGetString(line, "cmd");

    if (cmd == "quit" || cmd == "exit") break;

    if (cmd == "status") {
      emit(deviceEvent(connected, name, format));
      continue;
    }

    if (cmd == "capture") {
      if (!connected) {
        emit("{\"event\":\"error\",\"code\":\"NO_DEVICE\",\"message\":\"No "
             "fingerprint reader connected\"}");
        continue;
      }
      std::string mode = jsonGetString(line, "mode");
      if (mode.empty()) mode = "identify";
      const long timeoutMs = jsonGetInt(line, "timeoutMs", 15000);

      CaptureResult r = device->capture(
          mode, static_cast<int>(timeoutMs),
          []() { emit("{\"event\":\"placed\"}"); });

      if (r.ok) {
        emit("{\"event\":\"captured\",\"format\":\"" + jsonEscape(r.format) +
             "\",\"quality\":" + std::to_string(r.quality) +
             ",\"template\":\"" + jsonEscape(r.templateB64) + "\"}");
      } else {
        const std::string code = r.errorCode.empty() ? "SDK_ERROR" : r.errorCode;
        emit("{\"event\":\"error\",\"code\":\"" + jsonEscape(code) +
             "\",\"message\":\"" + jsonEscape(r.errorMessage) + "\"}");
      }
      continue;
    }

    if (cmd == "cancel") {
      // Synchronous capture model: nothing is in flight between commands.
      emit("{\"event\":\"cancelled\"}");
      continue;
    }

    emit("{\"event\":\"error\",\"code\":\"BAD_CMD\",\"message\":\"Unknown "
         "command\"}");
  }

  return 0;
}
