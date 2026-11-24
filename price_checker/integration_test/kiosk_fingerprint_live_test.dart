// Live check of fingerprint punching on the kiosk (2026-11-25), against the
// LOCAL Apex backend (never production), with libfprint's virtual reader in
// the POS repo's apex-fingerprint-test image. Needs the DEMO Employee (17)
// enrolled with libfprint's "whorl" sample — the POS's
// fingerprint_live_test.dart does that (run it first, clean up after both).
//
// Registers this kiosk as the demo admin (the Settings dialog's call), then
// on the attendance page: Fingerprint → whorl → DEMO Employee → TIME IN.
//
//   integration_test/docker/run_live.sh
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:price_checker/controllers/main_controller.dart';
import 'package:price_checker/controllers/theme_controller.dart';
import 'package:price_checker/pages/attendance/attendance_page.dart';
import 'package:price_checker/services/fingerprint/kiosk_terminal.dart';
import 'package:price_checker/services/fingerprint/reader.dart';

const String _host = String.fromEnvironment('APEX_HOST', defaultValue: 'localhost');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kiosk fingerprint punch, live', (tester) async {
    final String? socketPath = Platform.environment['FP_VIRTUAL_IMAGE'];
    if (socketPath == null) {
      markTestSkipped('Live check in the apex-fingerprint-test image (virtual reader).');
      return;
    }
    final String prints = Platform.environment['APEX_FP_PRINTS']!;
    await Hive.initFlutter();
    await initDevice();
    saveServerIP(_host);
    saveStoreId(1);

    Future<void> settle([int ms = 600]) async {
      for (int i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> waitFor(Finder f, {int seconds = 60, String? what}) async {
      for (int i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (f.evaluate().isNotEmpty) return;
      }
      fail('Timed out waiting for ${what ?? f}');
    }

    Socket? reader;
    Future<void> press(String name) async {
      await tester.runAsync(() async {
        for (int i = 0; reader == null && i < 100; i++) {
          if (File(socketPath).existsSync()) {
            try {
              reader = await Socket.connect(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
            } catch (_) {}
          }
          if (reader == null) await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        reader!.add(File('$prints/$name.a8').readAsBytesSync());
        await reader!.flush();
      });
      await settle(400);
    }

    // The Settings dialog's "Register this kiosk", as the demo admin.
    late Map<String, dynamic> registered;
    await tester.runAsync(() async {
      registered = await KioskTerminal.register(
          email: 'demo.admin@apex.test', password: 'DemoApex2026!', deviceUuid: kioskDeviceUuid(), storeId: 1);
      await FingerprintReader.instance.ensureStarted();
      await KioskTerminal.refreshGallery();
    });
    expect(registered['status'], 200, reason: '${registered['message']}');
    expect(KioskTerminal.prints.map((p) => p.name), contains('DEMO Employee (touch test)'),
        reason: 'enrolled on the POS first');

    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const AttendancePage()));
    await waitFor(find.text('Fingerprint'), what: 'the Fingerprint button');
    await tester.tap(find.text('Fingerprint'));
    await waitFor(find.text('Place your finger on the reader'), what: 'reader armed');
    await press('whorl');
    await waitFor(find.text('DEMO Employee (touch test)'), seconds: 180, what: 'matched');
    expect(find.text('Fingerprint'), findsWidgets, reason: 'the card says how the person was found');
    await waitFor(find.text('TIME IN'), what: 'time in button');
    await tester.tap(find.text('TIME IN'));
    await waitFor(find.text('Time-In Recorded'), seconds: 30, what: 'recorded');
    await settle(1000);
    await tester.runAsync(() async => reader?.destroy());
  }, timeout: const Timeout(Duration(minutes: 20)));
}
