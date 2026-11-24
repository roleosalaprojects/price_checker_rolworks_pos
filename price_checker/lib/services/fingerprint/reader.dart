// A copy of apex_pos/lib/services/fingerprint/reader.dart — change it there and copy it here.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Fingerprints (1.1.18, 2026-11-25): the fingerprint reader, through the
/// reader program `apex_fingerprint` (native/apex_fingerprint) that the Linux
/// bundle carries next to `apex_pos` — one JSON object per line each way.
///
/// One owner: every page goes through [FingerprintReader.instance], which
/// runs one action at a time (a new one waits for the last to end) and is
/// told by the program when an action is over (`idle`). The reader is armed
/// on a tap and every action has a timeout: libfprint stops a reader that
/// waited about 4 minutes ("too hot") for about 3.
class FingerprintReader {
  FingerprintReader._();

  static final FingerprintReader instance = FingerprintReader._();

  /// Test seam: starts something that talks the reader program's protocol.
  static Future<ReaderProcess> Function()? starter;

  final ValueNotifier<ReaderStatus> status =
      ValueNotifier<ReaderStatus>(const ReaderStatus());

  ReaderProcess? _process;
  Future<void>? _starting;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  int _req = 0;
  String? _currentReq;
  Future<void> _lastAction = Future<void>.value();

  /// What the reader program holds (the gallery version it was given).
  String? loadedGalleryVersion;

  /// Where the reader program is: next to the app (the bundle), or
  /// APEX_FP_BIN for a development run. Null where there is none (iPad,
  /// macOS, a bundle built without libfprint).
  static String? binaryPath() {
    final String? env = Platform.environment['APEX_FP_BIN'];
    if (env != null && env.isNotEmpty) return env;
    if (!Platform.isLinux) return null;
    final String path =
        '${File(Platform.resolvedExecutable).parent.path}/apex_fingerprint';
    return File(path).existsSync() ? path : null;
  }

  /// This terminal can read fingers at all.
  bool get supported => starter != null || binaryPath() != null;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> ensureStarted() async {
    if (_process != null) return;
    _starting ??= _start();
    await _starting;
  }

  Future<void> _start() async {
    try {
      final ReaderProcess process = starter != null
          ? await starter!()
          : await SidecarProcess.start(binaryPath()!);
      _process = process;
      final Completer<void> first = Completer<void>();
      process.lines.listen((String line) {
        final Map<String, dynamic>? event = _parse(line);
        if (event == null) return;
        if (event['event'] == 'reader') {
          status.value = ReaderStatus.fromEvent(event);
          if (!first.isCompleted) first.complete();
        }
        _events.add(event);
      });
      unawaited(process.exitCode.then((int code) {
        _process = null;
        loadedGalleryVersion = null;
        status.value = code == 127
            ? const ReaderStatus(
                problem:
                    'The fingerprint reader is not set up on this terminal (run setup_terminal.sh --fingerprint).')
            : const ReaderStatus(problem: 'The reader program stopped.');
        _events.add({'event': 'exit', 'code': code});
      }));
      await first.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    } catch (e) {
      status.value = ReaderStatus(problem: 'The reader program could not start: $e');
    } finally {
      _starting = null;
    }
  }

  static Map<String, dynamic>? _parse(String line) {
    try {
      final dynamic decoded = jsonDecode(line);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  void _send(Map<String, dynamic> command) =>
      _process?.write(jsonEncode(command));

  /// Hands the reader program the prints to match against.
  Future<bool> loadGallery({
    required String version,
    required Map<String, dynamic> params,
    required List<Map<String, dynamic>> prints,
  }) async {
    await ensureStarted();
    if (_process == null) return false;
    final Future<Map<String, dynamic>> answer = events
        .firstWhere((e) => e['event'] == 'gallery' || e['event'] == 'exit')
        .timeout(const Duration(seconds: 20),
            onTimeout: () => {'event': 'timeout'});
    _send({'cmd': 'gallery', 'params': params, 'prints': prints});
    final Map<String, dynamic> result = await answer;
    if (result['event'] != 'gallery') return false;
    loadedGalleryVersion = version;
    return true;
  }

  /// A finger, scored against the gallery. [onProgress] hears `waiting`,
  /// `retry {reason}` and `paused {seconds}`.
  Future<ReaderResult> scan({
    String purpose = 'punch',
    int timeoutSeconds = 20,
    void Function(Map<String, dynamic>)? onProgress,
  }) =>
      _run({'cmd': 'scan', 'purpose': purpose, 'timeout': timeoutSeconds},
          const {'match', 'no_match'}, onProgress);

  /// Five presses of one finger; `stage {done, of}` on the way.
  Future<ReaderResult> enroll({
    required String userId,
    required String finger,
    void Function(Map<String, dynamic>)? onProgress,
  }) =>
      _run({'cmd': 'enroll', 'user_id': userId, 'finger': finger, 'timeout': 120},
          const {'enrolled', 'enroll_failed'}, onProgress);

  /// One press checked against a just-enrolled print.
  Future<ReaderResult> verify({
    required String userId,
    required String print,
    void Function(Map<String, dynamic>)? onProgress,
  }) =>
      _run({'cmd': 'verify', 'user_id': userId, 'print': print, 'timeout': 20},
          const {'verified'}, onProgress);

  /// Stops the action in progress (a dialog closing); returns when the
  /// reader is free.
  Future<void> cancel() async {
    if (_currentReq == null || _process == null) return;
    _send({'cmd': 'cancel'});
    await _lastAction.timeout(const Duration(seconds: 6), onTimeout: () {});
  }

  Future<ReaderResult> _run(
    Map<String, dynamic> command,
    Set<String> results,
    void Function(Map<String, dynamic>)? onProgress,
  ) async {
    await ensureStarted();
    if (_process == null) {
      return ReaderResult({'event': 'error', 'code': 'NO_PROGRAM', 'message': status.value.problem});
    }
    // One action at a time: wait for the last one's `idle`.
    await _lastAction.timeout(const Duration(seconds: 8), onTimeout: () {});
    final String req = 'r${++_req}';
    final Completer<ReaderResult> result = Completer<ReaderResult>();
    final Completer<void> idle = Completer<void>();
    _currentReq = req;
    _lastAction = idle.future;
    late final StreamSubscription<Map<String, dynamic>> subscription;
    subscription = events.listen((Map<String, dynamic> e) {
      final String? name = e['event'] as String?;
      if (name == 'exit') {
        if (!result.isCompleted) {
          result.complete(ReaderResult({'event': 'error', 'code': 'NO_PROGRAM', 'message': 'The reader program stopped.'}));
        }
      } else if (e['req'] != req) {
        return;
      } else if (results.contains(name) ||
          name == 'error' ||
          name == 'timeout' ||
          name == 'cancelled') {
        if (!result.isCompleted) result.complete(ReaderResult(e));
        if (name == 'error' && e['code'] == 'BUSY') idle.complete();
        return;
      } else if (name == 'idle') {
        if (!result.isCompleted) result.complete(ReaderResult({'event': 'cancelled'}));
      } else {
        onProgress?.call(e);
        return;
      }
      if (!idle.isCompleted) idle.complete();
      if (_currentReq == req) _currentReq = null;
      subscription.cancel();
    });
    _send({...command, 'req': req});
    return result.future;
  }

  /// Stops the reader program (tests; the app leaves it running).
  Future<void> stop() async {
    _send({'cmd': 'quit'});
    _process?.kill();
    _process = null;
    _currentReq = null;
    _lastAction = Future<void>.value();
    loadedGalleryVersion = null;
  }
}

/// What an action ended with (the reader program's final event).
class ReaderResult {
  ReaderResult(this.data);

  final Map<String, dynamic> data;

  String get event => data['event'] as String? ?? 'error';
  bool get isMatch => event == 'match';
  String? get userId => data['user_id']?.toString();
  String? get printId => data['print_id']?.toString();
  int get score => (data['score'] as num?)?.toInt() ?? 0;

  /// For a person: what went wrong, or null.
  String? get problem => switch (event) {
        'no_match' => 'Not recognised. Press the finger flat and still, then try again.',
        'timeout' => 'No finger was read.',
        'cancelled' => null,
        'error' => switch (data['code']) {
            'HOT' => 'The reader is resting: it was in use for a few minutes. Try again in about 3 minutes.',
            'NO_READER' => 'No fingerprint reader is plugged in.',
            'BUSY' => 'The reader is busy. Try again.',
            _ => (data['message'] as String?) ?? 'The reader failed.',
          },
        _ => null,
      };
}

/// The reader as the app sees it: plugged in, and how warm.
@immutable
class ReaderStatus {
  const ReaderStatus({
    this.connected = false,
    this.name,
    this.driver,
    this.temperature = 'cold',
    this.problem,
  });

  factory ReaderStatus.fromEvent(Map<String, dynamic> e) => ReaderStatus(
        connected: e['connected'] == true,
        name: e['name'] as String?,
        driver: e['driver'] as String?,
        temperature: (e['temperature'] as String?) ?? 'cold',
        problem: e['connected'] == true ? null : 'No fingerprint reader is plugged in.',
      );

  final bool connected;
  final String? name;
  final String? driver;
  final String temperature;
  final String? problem;
}

/// The reader program as a stream of lines (a seam for tests).
abstract class ReaderProcess {
  Stream<String> get lines;
  void write(String line);
  Future<int> get exitCode;
  void kill();
}

class SidecarProcess implements ReaderProcess {
  SidecarProcess._(this._process);

  final Process _process;

  static Future<SidecarProcess> start(String path) async {
    final Process process = await Process.start(path, const []);
    // A write after the program died must not throw from nowhere.
    unawaited(process.stdin.done.catchError((_) {}));
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => debugPrint('[apex_fingerprint] $line'));
    return SidecarProcess._(process);
  }

  @override
  late final Stream<String> lines = _process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  @override
  void write(String line) {
    try {
      _process.stdin.writeln(line);
    } catch (_) {}
  }

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void kill() => _process.kill();
}
