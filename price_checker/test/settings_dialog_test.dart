// The Settings dialog fits the kiosk's screen (the owner, 2026-11-25:
// "settings page is overlapping"): with Fingerprint Attendance on it holds
// the register fields too, and must not run over at any of these sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:price_checker/controllers/main_controller.dart';
import 'package:price_checker/controllers/price_checker_page_controller.dart';
import 'package:price_checker/controllers/theme_controller.dart';
import 'package:price_checker/services/fingerprint/kiosk_terminal.dart';

void main() {
  for (final bool registered in const [false, true]) {
    for (final Size size in const [
      Size(1366, 768),
      Size(1280, 720),
      Size(1024, 600),
      Size(800, 600),
      Size(768, 1024)
    ]) {
      testWidgets(
          'Settings fit at ${size.width.toInt()}x${size.height.toInt()}, ${registered ? 'registered' : 'not registered'}',
          (tester) async {
        KioskTerminal.id = registered ? 4 : null;
        KioskTerminal.secret = registered ? 'c2VjcmV0' : null;
        addTearDown(() {
          KioskTerminal.id = null;
          KioskTerminal.secret = null;
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        themeController = ThemeController(null);
        fingerprintEnabled = true;
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox());
        })));
        final errors = <FlutterErrorDetails>[];
        final old = FlutterError.onError;
        FlutterError.onError = errors.add;
        promptHostDialog(ctx);
        await tester.pumpAndSettle();
        FlutterError.onError = old;
        expect(errors.map((e) => e.exceptionAsString()).toList(), isEmpty);
        // The manager's e-mail and password once; a registered kiosk folds them away.
        expect(find.text('Register this kiosk'), registered ? findsNothing : findsOneWidget);
        expect(find.text('Register again'), registered ? findsOneWidget : findsNothing);
        if (registered) {
          await tester.tap(find.text('Register again'));
          await tester.pumpAndSettle();
          expect(find.text('Register this kiosk'), findsOneWidget);
        }
        // Save is on screen.
        final Rect save = tester.getRect(find.text('Save'));
        expect(save.bottom, lessThanOrEqualTo(size.height));
      });
    }
  }
}
