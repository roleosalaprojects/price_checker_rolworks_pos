import 'dart:convert';

import 'package:price_checker/services/fingerprint/terminal_signing.dart';
import 'package:flutter_test/flutter_test.dart';

/// The vectors were made by the backend's own code (2026-11-25):
/// AuthenticateTerminalDevice::canonical, TerminalDevice::sign and
/// TerminalDevice::encryptForTerminal, with the secret 32 × "k". If one of
/// these fails, the POS and the server no longer agree and every fingerprint
/// call is refused.
void main() {
  final String secret = base64Encode(utf8.encode('k' * 32));

  test('a GET is signed as the server checks it (no body, the raw query)', () {
    final String canonical = canonicalRequest(
        method: 'GET',
        path: '/api/v1/device/fingerprints',
        query: 'version=abc',
        time: 1764000000,
        nonce: 'nonce-1',
        body: '');
    expect(
        canonical,
        'GET\n/api/v1/device/fingerprints\nversion=abc\n1764000000\nnonce-1\n'
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(signCanonical(canonical, secret), 'f47cc3b9bd0f9af4a8fa5e2b23ff7763db5f391697edf3c72d659a3d33600b8c');
  });

  test('a POST signs its body', () {
    final String canonical = canonicalRequest(
        method: 'post',
        path: '/api/v1/device/attendance/punch',
        query: '',
        time: 1764000000,
        nonce: 'nonce-2',
        body: '{"user_id":17}');
    expect(signCanonical(canonical, secret), '10575f14f175ea65c0d207009d6f5bacea8952d287780da6fcc59dab79932d73');
  });

  test("the gallery key is PHP's hash_hkdf", () {
    final String hex = hkdf32(utf8.encode('k' * 32), 'apex-gallery')
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(hex, '373ec111a7199dc09efea14bf9213ba77f132b3a1062d7ccf658569ed0616cf9');
  });

  test('a gallery the server sealed opens, and only with this secret', () {
    const String sealed =
        'Fxg/EVT4HmeexxSQr/RAawWEXwlLXBLtrDflBILxfx52cdTtCeduX/Ub/tafwqgCsa16wwgYlQ9bwA4YIuFHERWnpA==';
    expect(openSealed(sealed, secret), '{"params":{"match_min":40},"prints":[]}');
    expect(() => openSealed(sealed, base64Encode(utf8.encode('x' * 32))), throwsA(anything));
    final List<int> altered = base64Decode(sealed)..[20] ^= 1;
    expect(() => openSealed(base64Encode(altered), secret), throwsA(anything));
  });
}
