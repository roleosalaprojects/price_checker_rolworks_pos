// Tiny base64 encoder for template payloads.
#ifndef FPB_BASE64_H
#define FPB_BASE64_H

#include <string>
#include <vector>

namespace fpb {

inline std::string base64Encode(const std::vector<unsigned char>& data) {
  static const char* tbl =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string out;
  out.reserve(((data.size() + 2) / 3) * 4);
  size_t i = 0;
  for (; i + 2 < data.size(); i += 3) {
    unsigned n = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2];
    out += tbl[(n >> 18) & 63];
    out += tbl[(n >> 12) & 63];
    out += tbl[(n >> 6) & 63];
    out += tbl[n & 63];
  }
  if (i < data.size()) {
    unsigned n = data[i] << 16;
    bool two = (i + 1 < data.size());
    if (two) n |= data[i + 1] << 8;
    out += tbl[(n >> 18) & 63];
    out += tbl[(n >> 12) & 63];
    out += two ? tbl[(n >> 6) & 63] : '=';
    out += '=';
  }
  return out;
}

inline std::string base64Encode(const std::string& s) {
  return base64Encode(std::vector<unsigned char>(s.begin(), s.end()));
}

}  // namespace fpb

#endif  // FPB_BASE64_H
