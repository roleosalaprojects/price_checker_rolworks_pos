// Minimal JSON helpers for the sidecar's small, controlled wire protocol.
// Not a general JSON library — just enough to emit events and read flat
// command objects like {"cmd":"capture","mode":"identify","timeoutMs":15000}.
#ifndef FPB_JSON_UTIL_H
#define FPB_JSON_UTIL_H

#include <string>

namespace fpb {

// Escape a string for embedding in a JSON double-quoted value.
inline std::string jsonEscape(const std::string& s) {
  std::string out;
  out.reserve(s.size() + 8);
  for (char c : s) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (static_cast<unsigned char>(c) < 0x20) {
          static const char* hex = "0123456789abcdef";
          out += "\\u00";
          out += hex[(c >> 4) & 0xF];
          out += hex[c & 0xF];
        } else {
          out += c;
        }
    }
  }
  return out;
}

// Extract a string field value for `key` from a flat JSON object line.
// Returns empty string if absent. Handles basic backslash escapes.
inline std::string jsonGetString(const std::string& line, const std::string& key) {
  const std::string needle = "\"" + key + "\"";
  size_t k = line.find(needle);
  if (k == std::string::npos) return "";
  size_t colon = line.find(':', k + needle.size());
  if (colon == std::string::npos) return "";
  size_t i = colon + 1;
  while (i < line.size() && (line[i] == ' ' || line[i] == '\t')) i++;
  if (i >= line.size() || line[i] != '"') return "";
  i++;  // opening quote
  std::string out;
  while (i < line.size()) {
    char c = line[i];
    if (c == '\\' && i + 1 < line.size()) {
      char n = line[i + 1];
      switch (n) {
        case 'n': out += '\n'; break;
        case 'r': out += '\r'; break;
        case 't': out += '\t'; break;
        default: out += n; break;
      }
      i += 2;
      continue;
    }
    if (c == '"') break;
    out += c;
    i++;
  }
  return out;
}

// Extract an integer field for `key`; returns `def` if absent/unparseable.
inline long jsonGetInt(const std::string& line, const std::string& key, long def) {
  const std::string needle = "\"" + key + "\"";
  size_t k = line.find(needle);
  if (k == std::string::npos) return def;
  size_t colon = line.find(':', k + needle.size());
  if (colon == std::string::npos) return def;
  size_t i = colon + 1;
  while (i < line.size() && (line[i] == ' ' || line[i] == '\t')) i++;
  bool neg = false;
  if (i < line.size() && (line[i] == '-' || line[i] == '+')) {
    neg = line[i] == '-';
    i++;
  }
  if (i >= line.size() || line[i] < '0' || line[i] > '9') return def;
  long v = 0;
  while (i < line.size() && line[i] >= '0' && line[i] <= '9') {
    v = v * 10 + (line[i] - '0');
    i++;
  }
  return neg ? -v : v;
}

}  // namespace fpb

#endif  // FPB_JSON_UTIL_H
