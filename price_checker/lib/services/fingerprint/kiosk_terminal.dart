import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../http_service.dart' show host;
import 'reader.dart';
import 'terminal_signing.dart';

/// One enrolled print of the gallery (what a match names).
@immutable
class KioskPrint {
  const KioskPrint({
    required this.id,
    required this.userId,
    required this.name,
    required this.print,
    this.finger = '',
    this.approves = const [],
  });

  factory KioskPrint.fromJson(Map<dynamic, dynamic> p) => KioskPrint(
        id: '${p['id']}',
        userId: '${p['user_id']}',
        name: '${p['name']}',
        print: '${p['print']}',
        finger: '${p['finger'] ?? ''}',
        approves: [for (final t in (p['approves'] is List ? p['approves'] as List : const [])) '$t'],
      );

  final String id;
  final String userId;
  final String name;
  final String print;
  final String finger;

  /// The POS's Higher Access types this person may approve (the server's).
  final List<String> approves;
}

/// A manager's approval at this kiosk (higher access, 2026-11-25): good for
/// one purpose — `enrol` (adding fingerprints) or `settings` — for ten
/// minutes. The server checks it again on every use.
@immutable
class KioskGrant {
  const KioskGrant({required this.token, required this.purpose, required this.approverName, required this.expiresAt});

  final String token;
  final String purpose;
  final String approverName;
  final DateTime expiresAt;

  bool get live => DateTime.now().isBefore(expiresAt);
}

/// Fingerprints (2026-11-25): this kiosk as the Apex server knows it.
///
/// A manager registers the kiosk once (Settings → Fingerprint reader): the
/// server answers with an id and a secret, kept in a file only this account
/// reads (`fingerprint_terminal.json`, chmod 600, in the app's support
/// folder). Every fingerprint call is signed with the secret (HMAC — the
/// secret itself never travels again). The gallery of enrolled prints comes
/// sealed for this kiosk and is kept in memory only: the kiosk punches
/// online, as it always has.
class KioskTerminal {
  KioskTerminal._();

  static int? id;
  static String? secret;
  static String? name;
  static int clockOffset = 0;
  static http.Client client = http.Client();

  static List<KioskPrint> prints = const [];
  static Map<String, dynamic> params = const {};
  static String? version;

  static bool get registered => id != null && secret != null;

  static Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/fingerprint_terminal.json');

  /// The kiosk's own id for registration (made once, kept in Hive).
  static String deviceUuid(Box<dynamic>? box) {
    String? uuid = box?.get('device_uuid') as String?;
    if (uuid == null || uuid.isEmpty) {
      final Random r = Random.secure();
      uuid = 'kiosk-${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      box?.put('device_uuid', uuid);
    }
    return uuid;
  }

  static Future<void> load() async {
    try {
      final File f = await _file();
      if (!f.existsSync()) return;
      final Map<String, dynamic> saved = jsonDecode(await f.readAsString());
      id = (saved['id'] as num?)?.toInt();
      secret = saved['secret'] as String?;
      name = saved['name'] as String?;
    } catch (e) {
      debugPrint('Kiosk fingerprint registration not read: $e');
    }
  }

  static Future<void> _save() async {
    final File f = await _file();
    await f.parent.create(recursive: true);
    final File tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode({'id': id, 'secret': secret, 'name': name}));
    if (Platform.isLinux || Platform.isMacOS) await Process.run('chmod', ['600', tmp.path]);
    await tmp.rename(f.path);
  }

  static Future<void> forget() async {
    id = null;
    secret = null;
    prints = const [];
    version = null;
    FingerprintReader.instance.loadedGalleryVersion = null;
    try {
      final File f = await _file();
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  /// A manager's e-mail and password register this kiosk for [storeId].
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String deviceUuid,
    required int storeId,
    bool replace = false,
  }) async {
    try {
      final http.Response response = await client
          .post(Uri.http(host, '/api/v1/device/register'),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({
                'email': email.trim(),
                'password': password,
                'kind': 'kiosk',
                'device_uuid': deviceUuid,
                'store_id': storeId,
                'name': 'Price Checker',
                if (replace) 'replace': true,
              }))
          .timeout(const Duration(seconds: 15));
      final Map<String, dynamic> body = decode(response);
      if (response.statusCode == 200 && body['data'] is Map) {
        final Map data = body['data'];
        id = (data['device_id'] as num).toInt();
        secret = data['secret'] as String;
        name = data['name'] as String?;
        if (data['server_time'] is num) clockOffset = (data['server_time'] as num).toInt() - _now();
        await _save();
      }
      return body..['status'] = response.statusCode;
    } catch (_) {
      return {'success': false, 'message': 'The server could not be reached.'};
    }
  }

  static Future<http.Response> send(String method, String path,
      {Map<String, String>? query,
      Map<String, dynamic>? body,
      Map<String, String>? headers,
      Duration timeout = const Duration(seconds: 15)}) async {
    late http.Response response;
    for (var attempt = 0; attempt < 2; attempt++) {
      final Uri uri = Uri.http(host, '/api/v1$path', query);
      final String text = body == null ? '' : jsonEncode(body);
      final int time = _now() + clockOffset;
      final Random r = Random.secure();
      final String nonce = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      final Map<String, String> signed = {
        ...?headers,
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        'X-Apex-Device': '$id',
        'X-Apex-Time': '$time',
        'X-Apex-Nonce': nonce,
        'X-Apex-Signature': signCanonical(
            canonicalRequest(method: method, path: uri.path, query: uri.query, time: time, nonce: nonce, body: text),
            secret!),
      };
      response = await (method == 'GET'
              ? client.get(uri, headers: signed)
              : client.post(uri, headers: signed, body: text))
          .timeout(timeout);
      if (response.statusCode != 401) return response;
      final Map<String, dynamic> refusal = decode(response);
      if (refusal['code'] == 'clock_skew' && attempt == 0 && refusal['server_time'] is num) {
        clockOffset = (refusal['server_time'] as num).toInt() - _now();
        continue;
      }
      if (refusal['code'] == 'device_revoked') await forget();
      return response;
    }
    return response;
  }

  /// Fetches the gallery (when it changed) and hands it to the reader.
  static Future<bool> refreshGallery() async {
    if (!registered) return false;
    try {
      final http.Response response = await send('GET', '/device/fingerprints', query: {if (version != null) 'version': version!});
      if (response.statusCode != 200) return false;
      final Map data = decode(response)['data'] as Map? ?? const {};
      if (data['unchanged'] != true) {
        final Map<String, dynamic> opened = jsonDecode(openSealed(data['gallery'] as String, secret!));
        params = Map<String, dynamic>.from(opened['params'] as Map? ?? const {});
        prints = [
          for (final p in (opened['prints'] as List? ?? const []))
            if (p is Map) KioskPrint.fromJson(p),
        ];
        version = data['version'] as String?;
      }
      final FingerprintReader reader = FingerprintReader.instance;
      if (reader.loadedGalleryVersion != version) {
        await reader.loadGallery(
          version: version ?? 'none',
          params: params,
          prints: [for (final p in prints) {'id': p.id, 'user_id': p.userId, 'print': p.print}],
        );
      }
      return true;
    } catch (e) {
      debugPrint('Kiosk gallery not refreshed: $e');
      return false;
    }
  }

  /// Whether the server answers this kiosk now (a signed `device/me`, 3 s).
  /// Settings asks a manager only when it does: a kiosk pointed at the wrong
  /// address can still be fixed.
  static Future<bool> serverAnswers() async {
    if (!registered) return false;
    try {
      final http.Response response = await send('GET', '/device/me', timeout: const Duration(seconds: 3));
      return response.statusCode < 500 && registered;
    } catch (_) {
      return false;
    }
  }

  /// Higher access: a manager's finger ([who], matched at sign-in level with
  /// [score]) or e-mail + password, for [purpose] (`enrol` | `settings`).
  /// The grant, or the server's reason as a String.
  static Future<Object> higherAccess({
    required String purpose,
    KioskPrint? who,
    int? score,
    String? email,
    String? password,
  }) async {
    try {
      final http.Response response = await send('POST', '/device/higher-access', body: {
        'purpose': purpose,
        if (who != null) ...{
          'method': 'fingerprint',
          'user_id': int.tryParse(who.userId) ?? who.userId,
          'print_id': int.tryParse(who.id) ?? who.id,
          'score': score,
        } else ...{
          'method': 'password',
          'email': (email ?? '').trim(),
          'password': password ?? '',
        },
      });
      final Map<String, dynamic> body = decode(response);
      final dynamic data = body['data'];
      if (response.statusCode == 200 && data is Map && data['grant'] is String) {
        return KioskGrant(
          token: data['grant'] as String,
          purpose: purpose,
          approverName: '${(data['approver'] as Map?)?['name'] ?? ''}',
          expiresAt: DateTime.now().add(Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 600)),
        );
      }
      return '${body['message'] ?? 'Not allowed.'}';
    } catch (_) {
      return 'The server could not be reached.';
    }
  }

  /// The staff and their enrolled fingers (an `enrol` grant). Null with a
  /// reason when the server says no (the approval expired).
  static Future<(List<Map<String, dynamic>>?, String?)> enrolStaff(KioskGrant grant) async {
    try {
      final http.Response response = await send('GET', '/device/enrol/employees', headers: {'X-Apex-Grant': grant.token});
      final Map<String, dynamic> body = decode(response);
      if (response.statusCode != 200) return (null, '${body['message'] ?? 'Not allowed.'}');
      return ([for (final e in ((body['data'] as Map?)?['employees'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)], null);
    } catch (_) {
      return (null, 'The server could not be reached.');
    }
  }

  /// Saves an enrolled finger (an `enrol` grant): the POS's rules.
  static Future<Map<String, dynamic>> enrol(KioskGrant grant,
      {required String userId, required String finger, required String driver, required String print}) async {
    try {
      final http.Response response = await send('POST', '/device/enrol', headers: {'X-Apex-Grant': grant.token}, body: {
        'user_id': int.tryParse(userId) ?? userId,
        'finger': finger,
        'driver': driver,
        'print': print,
        'consent': true,
        'duplicate_check': 'clear',
      });
      return decode(response)..['status'] = response.statusCode;
    } catch (_) {
      return {'success': false, 'message': 'The server could not be reached.'};
    }
  }

  static KioskPrint? byUser(String? userId) {
    for (final p in prints) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  static KioskPrint? byPrint(String? printId) {
    for (final p in prints) {
      if (p.id == printId) return p;
    }
    return null;
  }

  /// Today's status for the employee card (time in / out so far, `next`).
  static Future<Map<String, dynamic>?> today(String userId) async {
    try {
      final http.Response response = await send('GET', '/device/attendance/today', query: {'user_id': userId});
      if (response.statusCode != 200) return null;
      final dynamic status = (decode(response)['data'] as Map?)?['today_status'];
      return status is Map ? Map<String, dynamic>.from(status) : null;
    } catch (_) {
      return null;
    }
  }

  /// A punch by finger (online only: the kiosk keeps no queue).
  static Future<Map<String, dynamic>> punch({required KioskPrint who, required String action}) async {
    try {
      final Random r = Random.secure();
      String hex(int n) => List.generate(n, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      final String h = hex(16);
      final String uuid = '${h.substring(0, 8)}-${h.substring(8, 12)}-4${h.substring(13, 16)}-a${h.substring(17, 20)}-${h.substring(20, 32)}';
      final http.Response response = await send('POST', '/device/attendance/punch', body: {
        'user_id': int.tryParse(who.userId) ?? who.userId,
        'print_id': int.tryParse(who.id) ?? who.id,
        'action': action,
        'client_uuid': uuid,
        'punched_at': DateTime.now().toUtc().toIso8601String(),
        'queued': false,
      });
      return decode(response)..['status'] = response.statusCode;
    } catch (_) {
      return {'success': false, 'message': 'No connection — punch at the POS.'};
    }
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static Map<String, dynamic> decode(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map) return Map<String, dynamic>.from(body);
    } catch (_) {}
    return {'success': false, 'message': 'Request failed (${response.statusCode}).'};
  }
}
