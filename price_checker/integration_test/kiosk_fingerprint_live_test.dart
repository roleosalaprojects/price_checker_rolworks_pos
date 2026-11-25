// Live check of fingerprint punching on the kiosk (2026-11-25), against the
// LOCAL Apex backend (never production), with libfprint's virtual reader in
// the POS repo's apex-fingerprint-test image. Needs the DEMO Employee (17)
// enrolled with libfprint's "whorl" sample — the POS's
// fingerprint_live_test.dart does that (run it first, clean up after both).
//
// Registers this kiosk as the demo admin (the Settings dialog's call), then
// on the attendance page: Fingerprint → whorl → DEMO Employee → TIME IN.
// 1.1.0 (higher access): the Settings open after the admin's finger
// (tented_arch); Add fingerprints refuses the Demo Cashier's (loop-right),
// opens on the admin's, and enrols arch for the DEMO Employee.
//
//   integration_test/docker/run_live.sh
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:price_checker/controllers/main_controller.dart';
import 'package:price_checker/controllers/price_checker_page_controller.dart';
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
    await settle(4000);

    // ---- 1.1.0: higher access by a manager's finger ----------------------
    // The Settings (the gear's guard): the admin's finger opens them.
    unawaited(openSettingsGuarded(tester.element(find.byType(AttendancePage))));
    await waitFor(find.text('Manager approval'), what: 'Settings approval');
    expect(find.text('A manager allows this kiosk to open the Settings for ten minutes.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ha-finger')));
    await waitFor(find.text('Manager: place your finger on the reader'), what: 'approval armed');
    await press('tented_arch');
    await waitFor(find.textContaining('Registered as'), seconds: 180, what: 'Settings open');
    await tester.tap(find.text('Cancel').last);
    await settle(1000);

    // Add fingerprints: the Demo Cashier's finger is refused (no Fingerprints
    // switch); the admin's opens the page; arch is enrolled for the DEMO
    // Employee (a finger nobody has).
    await tester.tap(find.byKey(const ValueKey('kiosk-enrol')));
    await waitFor(find.text('Manager approval'), what: 'enrol approval');
    await tester.tap(find.byKey(const ValueKey('ha-finger')));
    await waitFor(find.text('Manager: place your finger on the reader'), what: 'approval armed');
    await press('loop-right');
    await waitFor(find.textContaining('Demo Cashier may not'), seconds: 180, what: 'cashier refused');
    await tester.tap(find.byKey(const ValueKey('ha-finger')));
    await waitFor(find.text('Manager: place your finger on the reader'), what: 'approval armed again');
    await press('tented_arch');
    await waitFor(find.text('Approved by Demo Admin'), seconds: 180, what: 'Add fingerprints page');
    await waitFor(find.text('DEMO Employee (touch test)'), seconds: 30, what: 'staff list');
    await tester.tap(find.text('DEMO Employee (touch test)'));
    await waitFor(find.byKey(const ValueKey('enrol-consent')), what: 'enrol dialog');
    await tester.tap(find.byKey(const ValueKey('enrol-consent')));
    await settle(300);
    await tester.tap(find.text('Start'));
    await waitFor(find.textContaining('on the reader, then lift it'), seconds: 60, what: 'first press');
    for (int i = 1; i <= 5; i++) {
      await press('arch');
      if (i < 5) await waitFor(find.textContaining('($i of 5)'), seconds: 120, what: 'stage $i');
    }
    await waitFor(find.text('Press the same finger once more to check it'), seconds: 300, what: 'check press');
    await press('arch');
    await waitFor(find.textContaining('saved for DEMO Employee (touch test)'), seconds: 300, what: 'saved');
    await tester.tap(find.text('Done'));
    await settle(3000);
    expect(KioskTerminal.prints.where((p) => p.name == 'DEMO Employee (touch test)').length, greaterThanOrEqualTo(2));
    await tester.runAsync(() async => reader?.destroy());
  }, timeout: const Timeout(Duration(minutes: 20)));
}
