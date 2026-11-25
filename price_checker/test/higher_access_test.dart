// Higher access on the kiosk (2026-11-25): a manager's finger or password →
// a ten-minute grant (adding fingerprints, or Settings); enrolling with it.
// The reader program is a fake that talks its protocol; the server a MockClient.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:price_checker/controllers/main_controller.dart';
import 'package:price_checker/pages/fingerprint/enrol_page.dart';
import 'package:price_checker/pages/fingerprint/higher_access_dialog.dart';
import 'package:price_checker/services/fingerprint/kiosk_terminal.dart';
import 'package:price_checker/services/fingerprint/reader.dart';
import 'package:price_checker/services/http_service.dart' as http_service;

class FakeReader implements ReaderProcess {
  final StreamController<String> _out = StreamController<String>();
  final List<Map<String, dynamic>> sent = [];
  List<Map<String, dynamic>> duplicates = [];

  void emit(Map<String, dynamic> e) => scheduleMicrotask(() => _out.add(jsonEncode(e)));

  @override
  Stream<String> get lines => _out.stream;

  @override
  void write(String line) {
    final Map<String, dynamic> c = Map<String, dynamic>.from(jsonDecode(line));
    sent.add(c);
    final dynamic req = c['req'];
    switch (c['cmd']) {
      case 'gallery':
        emit({'event': 'gallery', 'loaded': (c['prints'] as List).length, 'skipped': []});
      case 'scan':
        emit({'event': 'waiting', 'req': req});
        emit({'event': 'match', 'req': req, 'user_id': '15', 'print_id': '5', 'score': 70, 'second': 9});
        emit({'event': 'idle', 'req': req});
      case 'enroll':
        emit({'event': 'waiting', 'req': req});
        for (var i = 1; i <= 5; i++) {
          emit({'event': 'stage', 'req': req, 'done': i, 'of': 5});
        }
        emit({'event': 'enrolled', 'req': req, 'print': 'RlAzeHh4', 'weakest': 50, 'duplicates': duplicates});
        emit({'event': 'idle', 'req': req});
      case 'verify':
        emit({'event': 'verified', 'req': req, 'ok': true, 'score': 61, 'duplicates': []});
        emit({'event': 'idle', 'req': req});
    }
  }

  @override
  Future<int> get exitCode => Completer<int>().future;

  @override
  void kill() {}
}

void main() {
  final List<http.Request> calls = [];
  late FakeReader reader;
  late http.Response Function(http.Request) server;

  setUp(() async {
    calls.clear();
    http_service.host = 'localhost';
    fingerprintEnabled = true;
    KioskTerminal.id = 4;
    KioskTerminal.secret = base64Encode(utf8.encode('k' * 32));
    KioskTerminal.version = 'v';
    KioskTerminal.prints = const [
      KioskPrint(id: '5', userId: '15', name: 'Demo Admin', print: 'x', finger: 'right_index'),
      KioskPrint(id: '6', userId: '17', name: 'DEMO Employee', print: 'y', finger: 'left_index'),
    ];
    KioskTerminal.client = MockClient((request) async {
      // The gallery is current (the dialogs refresh it first).
      if (request.url.path == '/api/v1/device/fingerprints') {
        return http.Response(jsonEncode({'success': true, 'data': {'unchanged': true, 'version': 'v'}}), 200);
      }
      calls.add(request);
      return server(request);
    });
    await FingerprintReader.instance.stop();
    reader = FakeReader();
    FingerprintReader.starter = () async {
      reader.emit({'event': 'reader', 'connected': true, 'driver': 'uru4000', 'name': 'U.are.U 4500'});
      return reader;
    };
    FingerprintReader.instance.loadedGalleryVersion = 'v';
  });

  http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);

  test('the gallery keeps the finger and what each person may approve', () {
    final KioskPrint p = KioskPrint.fromJson(const {'id': 5, 'user_id': 15, 'name': 'A', 'print': 'x', 'finger': 'right_index', 'approves': ['refunds']});
    expect([p.finger, p.approves], ['right_index', ['refunds']]);
  });

  test('a finger or a password asks the server, signed; the answer is a grant or its reason', () async {
    server = (r) => json({'success': true, 'data': {'grant': 'g' * 48, 'purpose': 'enrol', 'expires_in': 600, 'approver': {'id': 15, 'name': 'Demo Admin'}}});
    final Object grant = await KioskTerminal.higherAccess(purpose: 'enrol', who: KioskTerminal.prints.first, score: 70);
    expect(grant, isA<KioskGrant>());
    expect((grant as KioskGrant).approverName, 'Demo Admin');
    expect(grant.live, isTrue);
    expect(calls.single.url.path, '/api/v1/device/higher-access');
    expect(calls.single.headers['X-Apex-Device'], '4');
    expect(jsonDecode(calls.single.body), {'purpose': 'enrol', 'method': 'fingerprint', 'user_id': 15, 'print_id': 5, 'score': 70});

    server = (r) => json({'success': false, 'message': 'Wrong e-mail or password.', 'code': 'wrong_credentials'}, 401);
    expect(await KioskTerminal.higherAccess(purpose: 'settings', email: ' a@b.c ', password: 'x'), 'Wrong e-mail or password.');
    expect(jsonDecode(calls.last.body), {'purpose': 'settings', 'method': 'password', 'email': 'a@b.c', 'password': 'x'});
  });

  test('enrolling carries the grant; Settings asks only when the server answers', () async {
    final KioskGrant grant = KioskGrant(token: 'tok', purpose: 'enrol', approverName: 'A', expiresAt: DateTime.now().add(const Duration(minutes: 9)));
    server = (r) => json({'success': true, 'message': 'Right thumb saved for DEMO Employee.'}, 201);
    final Map<String, dynamic> saved = await KioskTerminal.enrol(grant, userId: '17', finger: 'right_thumb', driver: 'uru4000', print: 'p');
    expect(saved['status'], 201);
    expect(calls.single.headers['X-Apex-Grant'], 'tok');
    expect(jsonDecode(calls.single.body)['duplicate_check'], 'clear');

    server = (r) => json({'success': true});
    expect(await KioskTerminal.serverAnswers(), isTrue);
    KioskTerminal.client = MockClient((_) async => throw const SocketException('down'));
    expect(await KioskTerminal.serverAnswers(), isFalse, reason: 'Settings opens: a wrong address can be fixed');
  });

  testWidgets('the manager approval dialog: a finger, then the grant', (tester) async {
    server = (r) => json({'success': true, 'data': {'grant': 'g' * 48, 'purpose': 'settings', 'expires_in': 600, 'approver': {'id': 15, 'name': 'Demo Admin'}}});
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox());
    })));
    KioskGrant? got;
    unawaited(askHigherAccess(ctx, purpose: 'settings').then((g) => got = g));
    await tester.pumpAndSettle();
    expect(find.text('A manager allows this kiosk to open the Settings for ten minutes.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ha-finger')));
    for (var i = 0; i < 30 && got == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(got?.approverName, 'Demo Admin');
    expect(reader.sent.firstWhere((c) => c['cmd'] == 'scan')['purpose'], 'sign_in');
  });

  testWidgets('enrolling: a finger that is someone else\'s is refused; a new one is saved', (tester) async {
    final KioskGrant grant = KioskGrant(token: 'tok', purpose: 'enrol', approverName: 'A', expiresAt: DateTime.now().add(const Duration(minutes: 9)));
    server = (r) => json({'success': true, 'message': 'saved'}, 201);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: KioskEnrolDialog(grant: grant, userId: '17', name: 'DEMO Employee', taken: const ['left_index']))));
    await tester.tap(find.byKey(const ValueKey('enrol-consent')));
    await tester.pump();

    Future<void> run() async {
      await tester.tap(find.text('Start'));
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    reader.duplicates = [{'user_id': '15', 'score': 80}];
    await run();
    expect(find.text('This finger is already enrolled as Demo Admin.'), findsOneWidget);
    expect(calls, isEmpty);

    reader.duplicates = [{'user_id': '17', 'score': 90}]; // their own: not someone else's
    await run();
    expect(find.text('Right index saved for DEMO Employee.'), findsOneWidget);
    expect(jsonDecode(calls.single.body)['finger'], 'right_index');
  });
}
