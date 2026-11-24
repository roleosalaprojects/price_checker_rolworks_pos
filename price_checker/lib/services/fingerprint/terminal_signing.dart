// A copy of apex_pos/lib/services/fingerprint/terminal_signing.dart — change it there and copy it here.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Fingerprints (1.1.18, 2026-11-25): how a registered terminal signs its
/// fingerprint calls and opens the gallery of prints the server seals for it.
/// Pure functions, pinned by `test/fingerprint/terminal_signing_test.dart`
/// against the backend's `AuthenticateTerminalDevice` and
/// `TerminalDevice::encryptForTerminal`.

/// The string a call is signed over:
/// METHOD \n /api/v1/path \n raw query \n unix time \n nonce \n sha256(body).
String canonicalRequest({
  required String method,
  required String path,
  required String query,
  required int time,
  required String nonce,
  required String body,
}) =>
    [
      method.toUpperCase(),
      path,
      query,
      '$time',
      nonce,
      sha256.convert(utf8.encode(body)).toString(),
    ].join('\n');

/// hex HMAC-SHA256 of [canonical] with the terminal's secret (base64).
String signCanonical(String canonical, String secretBase64) =>
    Hmac(sha256, base64Decode(secretBase64))
        .convert(utf8.encode(canonical))
        .toString();

/// HKDF-SHA256 (RFC 5869) with an empty salt, one 32-byte block — PHP's
/// `hash_hkdf('sha256', $ikm, 32, $info)`.
Uint8List hkdf32(List<int> ikm, String info) {
  final prk = Hmac(sha256, Uint8List(32)).convert(ikm).bytes;
  final okm =
      Hmac(sha256, prk).convert([...utf8.encode(info), 0x01]).bytes;
  return Uint8List.fromList(okm);
}

/// Opens a sealed gallery: base64(iv[12] . ciphertext . tag[16]),
/// AES-256-GCM with HKDF(secret, "apex-gallery"). Throws when the seal does
/// not hold (another terminal's, or altered on the way).
String openSealed(String sealedBase64, String secretBase64) {
  final Uint8List raw = base64Decode(sealedBase64);
  if (raw.length < 12 + 16) throw const FormatException('sealed data too short');
  final GCMBlockCipher cipher = GCMBlockCipher(AESEngine())
    ..init(
        false,
        AEADParameters(KeyParameter(hkdf32(base64Decode(secretBase64), 'apex-gallery')), 128,
            Uint8List.sublistView(raw, 0, 12), Uint8List(0)));
  // Checks the tag: throws InvalidCipherTextException when it does not hold.
  return utf8.decode(cipher.process(Uint8List.sublistView(raw, 12)));
}
