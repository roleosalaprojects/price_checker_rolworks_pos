import 'package:flutter/material.dart';

import '../../components/custom_text_field.dart';
import '../../controllers/main_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../services/fingerprint/kiosk_terminal.dart';
import '../../services/fingerprint/reader.dart';

/// Higher access on the kiosk (2026-11-25): a manager approves with a finger
/// or with e-mail + password, for [purpose] — `enrol` (adding fingerprints,
/// the Fingerprints switch) or `settings` (the Settings switch). The server
/// decides who may; the answer is a ten-minute grant, or null.
Future<KioskGrant?> askHigherAccess(BuildContext context, {required String purpose}) =>
    showDialog<KioskGrant>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HigherAccessDialog(purpose: purpose),
    );

/// Fingers can approve here: the switch, a reader, a registration, prints.
bool get fingerApprovalReady =>
    fingerprintEnabled &&
    FingerprintReader.instance.supported &&
    KioskTerminal.registered &&
    KioskTerminal.prints.isNotEmpty;

class HigherAccessDialog extends StatefulWidget {
  const HigherAccessDialog({super.key, required this.purpose});

  final String purpose;

  @override
  State<HigherAccessDialog> createState() => _HigherAccessDialogState();
}

class _HigherAccessDialogState extends State<HigherAccessDialog> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _typing = !fingerApprovalReady;
  bool _scanning = false;
  bool _busy = false;
  String? _line;
  String? _error;

  String get _what => widget.purpose == 'enrol' ? 'add fingerprints' : 'open the Settings';

  @override
  void dispose() {
    if (_scanning) FingerprintReader.instance.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _finger() async {
    setState(() {
      _scanning = true;
      _error = null;
      _line = 'Getting the reader ready…';
    });
    await KioskTerminal.refreshGallery();
    final ReaderResult result = await FingerprintReader.instance.scan(
      purpose: 'sign_in',
      onProgress: (e) {
        if (!mounted) return;
        setState(() => _line = switch (e['event']) {
              'waiting' => 'Manager: place your finger on the reader',
              'retry' => 'Press again — hold the finger flat and still',
              'paused' => 'Too many fingers not recognised: wait ${e['seconds']} seconds',
              _ => _line,
            });
      },
    );
    if (!mounted) return;
    final KioskPrint? who = result.isMatch ? KioskTerminal.byPrint(result.printId) : null;
    if (who == null) {
      setState(() {
        _scanning = false;
        _line = null;
        _error = result.event == 'cancelled' ? null : (result.problem ?? 'Not recognised.');
      });
      return;
    }
    setState(() => _line = '${who.name}: checking…');
    await _answer(await KioskTerminal.higherAccess(purpose: widget.purpose, who: who, score: result.score));
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _typed() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _answer(await KioskTerminal.higherAccess(
        purpose: widget.purpose, email: _email.text, password: _password.text));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _answer(Object answer) async {
    if (!mounted) return;
    if (answer is KioskGrant) {
      Navigator.of(context).pop(answer);
      return;
    }
    setState(() {
      _line = null;
      _error = '$answer';
    });
  }

  Future<void> _close() async {
    if (_scanning) await FingerprintReader.instance.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Color text = ThemeController.getPrimaryTextColor(context);
    final Color soft = ThemeController.getSecondaryTextColor(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Manager approval', style: TextStyle(fontWeight: FontWeight.bold, color: text)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('A manager allows this kiosk to $_what for ten minutes.', style: TextStyle(color: soft)),
            const SizedBox(height: 18),
            if (_scanning) ...[
              Icon(Icons.fingerprint_rounded, size: 96, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(_line ?? '', key: const ValueKey('ha-line'), textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text)),
            ] else if (!_typing) ...[
              FilledButton.icon(
                key: const ValueKey('ha-finger'),
                onPressed: _finger,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Use fingerprint')),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() {
                  _typing = true;
                  _error = null;
                }),
                child: const Text('E-mail and password instead'),
              ),
            ] else ...[
              CustomTextField(controller: _email, hintText: 'Manager e-mail', keyboardType: TextInputType.emailAddress, autofocus: true),
              const SizedBox(height: 10),
              CustomTextField(controller: _password, hintText: 'Password', obscureText: true, onSubmitted: (_) => _typed()),
              if (fingerApprovalReady)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () => setState(() => _typing = false), child: const Text('Use a finger instead')),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const ValueKey('ha-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _close, child: const Text('Cancel')),
        if (_typing && !_scanning)
          FilledButton(
            onPressed: _busy ? null : _typed,
            child: Text(_busy ? 'Checking…' : 'Allow'),
          ),
      ],
    );
  }
}
