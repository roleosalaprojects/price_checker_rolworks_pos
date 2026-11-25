import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/theme_controller.dart';
import '../../services/fingerprint/kiosk_terminal.dart';
import '../../services/fingerprint/reader.dart';

const List<String> kioskFingers = [
  'right_index', 'right_thumb', 'right_middle', 'right_ring', 'right_little',
  'left_index', 'left_thumb', 'left_middle', 'left_ring', 'left_little',
];

String fingerLabel(String finger) {
  final String s = finger.replaceAll('_', ' ');
  return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Adding staff fingers on the kiosk (2026-11-25), after a manager's higher
/// access ([grant], ten minutes). As on the POS: the signed consent, five
/// presses of one finger, no finger that is someone else's, one more press
/// that must match; the server applies the POS's rules (the owner's fingers
/// by the owner alone, nobody with switches the approver lacks).
class KioskEnrolPage extends StatefulWidget {
  const KioskEnrolPage({super.key, required this.grant});

  final KioskGrant grant;

  @override
  State<KioskEnrolPage> createState() => _KioskEnrolPageState();
}

class _KioskEnrolPageState extends State<KioskEnrolPage> {
  List<Map<String, dynamic>>? _staff;
  String? _problem;
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    _load();
    _expiry = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!widget.grant.live && mounted) _leave('The manager approval has expired. Ask again.');
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  void _leave(String why) {
    _expiry?.cancel();
    Navigator.of(context).pop(why);
  }

  Future<void> _load() async {
    final (List<Map<String, dynamic>>? staff, String? problem) = await KioskTerminal.enrolStaff(widget.grant);
    if (!mounted) return;
    if (staff == null && problem != null && problem.contains('expired')) return _leave(problem);
    setState(() {
      _staff = staff;
      _problem = problem;
    });
  }

  Future<void> _enrol(Map<String, dynamic> person) async {
    final List<String> taken = [for (final f in (person['fingers'] as List? ?? const [])) '${(f as Map)['finger']}'];
    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => KioskEnrolDialog(grant: widget.grant, userId: '${person['user_id']}', name: '${person['name']}', taken: taken),
    );
    if (result == 'expired' && mounted) return _leave('The manager approval has expired. Ask again.');
    if (result != null && mounted) {
      await KioskTerminal.refreshGallery();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color text = ThemeController.getPrimaryTextColor(context);
    final Color soft = ThemeController.getSecondaryTextColor(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Add fingerprints', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: text)),
                ),
                Text('Approved by ${widget.grant.approverName}', style: TextStyle(color: soft)),
              ]),
              const SizedBox(height: 8),
              Text('Tap a person, then enrol a finger. Clean the reader\'s glass first; '
                  'a touch of skin oil on a dry fingertip helps.', style: TextStyle(color: soft)),
              const SizedBox(height: 16),
              Expanded(
                child: _staff == null
                    ? Center(
                        child: _problem == null
                            ? const CircularProgressIndicator()
                            : Text(_problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
                    : ListView.separated(
                        itemCount: _staff!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final Map<String, dynamic> p = _staff![i];
                          final List fingers = p['fingers'] as List? ?? const [];
                          return ListTile(
                            minVerticalPadding: 14,
                            title: Text('${p['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text)),
                            subtitle: Text(
                              fingers.isEmpty
                                  ? '${p['role'] ?? ''} · no finger yet'
                                  : '${p['role'] ?? ''} · ${fingers.map((f) => fingerLabel('${(f as Map)['finger']}')).join(', ')}',
                              style: TextStyle(color: soft),
                            ),
                            trailing: const Icon(Icons.fingerprint_rounded),
                            onTap: () => _enrol(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Step { choose, presses, check, saving, done }

/// One finger for one person. Pops 'saved', 'expired' or null.
class KioskEnrolDialog extends StatefulWidget {
  const KioskEnrolDialog({super.key, required this.grant, required this.userId, required this.name, this.taken = const []});

  final KioskGrant grant;
  final String userId;
  final String name;
  final List<String> taken;

  @override
  State<KioskEnrolDialog> createState() => _KioskEnrolDialogState();
}

class _KioskEnrolDialogState extends State<KioskEnrolDialog> {
  late String _finger = kioskFingers.firstWhere((f) => !widget.taken.contains(f), orElse: () => kioskFingers.first);
  bool _consent = false;
  _Step _step = _Step.choose;
  String _line = '';
  String? _error;
  int _done = 0;
  int _of = 5;

  bool get _running => _step == _Step.presses || _step == _Step.check;

  @override
  void dispose() {
    if (_running) FingerprintReader.instance.cancel();
    super.dispose();
  }

  String? _someoneElse(dynamic duplicates) {
    if (duplicates is! List) return null;
    for (final d in duplicates) {
      final String id = '${(d as Map)['user_id']}';
      if (id != widget.userId) return KioskTerminal.byUser(id)?.name ?? 'someone else';
    }
    return null;
  }

  void _fail(String message) => setState(() {
        _step = _Step.choose;
        _error = message;
      });

  Future<void> _start() async {
    if (!widget.grant.live) {
      Navigator.of(context).pop('expired');
      return;
    }
    setState(() {
      _step = _Step.presses;
      _error = null;
      _done = 0;
      _line = 'Getting the reader ready…';
    });
    await KioskTerminal.refreshGallery();
    final ReaderResult enrolled = await FingerprintReader.instance.enroll(
      userId: widget.userId,
      finger: _finger,
      onProgress: (e) {
        if (!mounted) return;
        setState(() {
          switch (e['event']) {
            case 'waiting':
              _line = 'Press the ${fingerLabel(_finger).toLowerCase()} on the reader, then lift it';
            case 'stage':
              _done = (e['done'] as num).toInt();
              _of = (e['of'] as num?)?.toInt() ?? 5;
              _line = _done < _of ? 'Lift, then press again ($_done of $_of)' : 'Checking the presses…';
            case 'retry':
              _line = 'Press again — hold the finger flat and still';
          }
        });
      },
    );
    if (!mounted || _step == _Step.choose) return;
    if (enrolled.event == 'enroll_failed') {
      return _fail('The presses were not all one finger. Start again with the same finger each time.');
    }
    if (enrolled.event != 'enrolled') return _fail(enrolled.problem ?? 'Not enrolled.');
    final String? already = _someoneElse(enrolled.data['duplicates']);
    if (already != null) return _fail('This finger is already enrolled as $already.');

    final String print = enrolled.data['print'] as String;
    setState(() {
      _step = _Step.check;
      _line = 'Press the same finger once more to check it';
    });
    final ReaderResult check = await FingerprintReader.instance.verify(userId: widget.userId, print: print);
    if (!mounted || _step == _Step.choose) return;
    if (check.event != 'verified') return _fail(check.problem ?? 'The check press was not read.');
    if (check.data['ok'] != true) return _fail('The check press did not match. Start again.');
    final String? also = _someoneElse(check.data['duplicates']);
    if (also != null) return _fail('This finger is already enrolled as $also.');

    setState(() {
      _step = _Step.saving;
      _line = 'Saving…';
    });
    final Map<String, dynamic> saved = await KioskTerminal.enrol(widget.grant,
        userId: widget.userId,
        finger: _finger,
        driver: FingerprintReader.instance.status.value.driver ?? 'uru4000',
        print: print);
    if (!mounted) return;
    if (saved['status'] == 201 || saved['status'] == 200) {
      setState(() {
        _step = _Step.done;
        _line = '${fingerLabel(_finger)} saved for ${widget.name}.';
      });
    } else if (saved['code'] == 'grant_expired') {
      Navigator.of(context).pop('expired');
    } else {
      _fail('${saved['message'] ?? 'Not saved.'}');
    }
  }

  Future<void> _cancel() async {
    if (_running) {
      await FingerprintReader.instance.cancel();
      if (mounted) setState(() => _step = _Step.choose);
      return;
    }
    if (mounted) Navigator.of(context).pop(_step == _Step.done ? 'saved' : null);
  }

  @override
  Widget build(BuildContext context) {
    final Color text = ThemeController.getPrimaryTextColor(context);
    final bool choosing = _step == _Step.choose;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Enrol ${widget.name}', style: TextStyle(fontWeight: FontWeight.bold, color: text)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (choosing) ...[
              CheckboxListTile(
                key: const ValueKey('enrol-consent'),
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                title: Text('${widget.name} has signed the fingerprint consent form'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _finger,
                decoration: const InputDecoration(labelText: 'Finger'),
                items: [
                  for (final f in kioskFingers)
                    DropdownMenuItem(
                        value: f, child: Text(widget.taken.contains(f) ? '${fingerLabel(f)} (replaces it)' : fingerLabel(f))),
                ],
                onChanged: (f) => setState(() => _finger = f ?? _finger),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, key: const ValueKey('enrol-error'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
              ],
            ] else ...[
              Icon(_step == _Step.done ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                  size: 96, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              if (_step == _Step.presses)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 1; i <= _of; i++)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(i <= _done ? Icons.circle : Icons.circle_outlined, size: 18,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                ]),
              const SizedBox(height: 8),
              Text(_line, key: const ValueKey('enrol-line'), textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text)),
            ],
          ],
        ),
      ),
      actions: [
        if (_step != _Step.saving)
          TextButton(onPressed: _cancel, child: Text(_step == _Step.done ? 'Done' : (choosing ? 'Close' : 'Cancel'))),
        if (choosing)
          FilledButton(onPressed: _consent ? _start : null, child: const Text('Start')),
      ],
    );
  }
}
