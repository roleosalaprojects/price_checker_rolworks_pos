import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log_service.dart';

/// Reader lifecycle state surfaced to the UI.
enum FingerprintStatus {
  /// Platform/binary unavailable, or disabled in settings.
  unavailable,

  /// Sidecar launched, waiting for the device handshake.
  starting,

  /// Reader connected and idle — ready to arm a capture.
  ready,

  /// Sidecar running but no reader plugged in.
  noDevice,

  /// A finger has been placed; capture in progress.
  scanning,
}

/// A captured fingerprint template from the sidecar.
class FingerprintCapture {
  final String template; // base64
  final String format; // matcher key, e.g. "ISO-19794-2" / "MOCK"
  final int quality;

  const FingerprintCapture({
    required this.template,
    required this.format,
    required this.quality,
  });
}

/// Bridges the Flutter app to the native `fingerprint_bridge` sidecar.
///
/// Spawns the sidecar as a child process and speaks the newline-delimited JSON
/// protocol over stdin/stdout (see native/fingerprint_bridge/README.md). The
/// service is intentionally tolerant: if the binary is missing or no reader is
/// present, it stays in [FingerprintStatus.unavailable]/[noDevice] and the
/// attendance screen falls back to barcode-only.
class FingerprintService {
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  final _statusController = StreamController<FingerprintStatus>.broadcast();
  final _captureController = StreamController<FingerprintCapture>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<FingerprintStatus> get statusStream => _statusController.stream;
  Stream<FingerprintCapture> get captureStream => _captureController.stream;
  Stream<String> get errorStream => _errorController.stream;

  FingerprintStatus _status = FingerprintStatus.unavailable;
  FingerprintStatus get status => _status;

  bool _deviceConnected = false;
  bool get isReady => _deviceConnected && _process != null;

  /// Windows/Linux are the production targets. macOS is allowed so the mock
  /// sidecar can drive end-to-end testing on dev machines.
  static bool get isSupportedPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Launch the sidecar. [sidecarPathOverride] takes precedence over the
  /// auto-discovered binary location.
  Future<void> start({String? sidecarPathOverride}) async {
    if (_process != null) return;
    if (!isSupportedPlatform) {
      _setStatus(FingerprintStatus.unavailable);
      return;
    }

    final path = _resolveSidecarPath(sidecarPathOverride);
    if (path == null) {
      logger.w('Fingerprint sidecar binary not found; barcode-only mode.');
      _setStatus(FingerprintStatus.unavailable);
      return;
    }

    try {
      _setStatus(FingerprintStatus.starting);
      _process = await Process.start(path, const []);
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onLine, onError: (Object e) => _errorController.add('$e'));
      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => logger.d('[fpb stderr] $line'));
      unawaited(_process!.exitCode.then((code) => _onExit(code)));
    } catch (e) {
      logger.e('Failed to start fingerprint sidecar', error: e);
      _process = null;
      _setStatus(FingerprintStatus.unavailable);
    }
  }

  /// Arm a single capture. The attendance screen calls this to (re)start the
  /// "waiting for finger" loop after handling each result.
  void capture({String mode = 'identify', int timeoutMs = 15000}) {
    if (!isReady) return;
    _send({'cmd': 'capture', 'mode': mode, 'timeoutMs': timeoutMs});
  }

  void cancel() => _send({'cmd': 'cancel'});

  void _onLine(String line) {
    if (line.trim().isEmpty) return;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return; // ignore non-JSON noise
    }

    switch (msg['event']) {
      case 'ready':
        logger.d('Fingerprint backend: ${msg['backend']}');
        break;
      case 'device':
        _deviceConnected = msg['connected'] == true;
        _setStatus(
          _deviceConnected ? FingerprintStatus.ready : FingerprintStatus.noDevice,
        );
        break;
      case 'placed':
        _setStatus(FingerprintStatus.scanning);
        break;
      case 'captured':
        _captureController.add(FingerprintCapture(
          template: (msg['template'] ?? '').toString(),
          format: (msg['format'] ?? '').toString(),
          quality: (msg['quality'] is int) ? msg['quality'] as int : 0,
        ));
        _setStatus(
          _deviceConnected ? FingerprintStatus.ready : FingerprintStatus.noDevice,
        );
        break;
      case 'error':
        _errorController.add((msg['message'] ?? 'Fingerprint error').toString());
        _setStatus(
          _deviceConnected ? FingerprintStatus.ready : FingerprintStatus.noDevice,
        );
        break;
    }
  }

  void _onExit(int code) {
    logger.w('Fingerprint sidecar exited (code $code)');
    _process = null;
    _deviceConnected = false;
    _setStatus(FingerprintStatus.unavailable);
  }

  void _send(Map<String, dynamic> cmd) {
    try {
      _process?.stdin.writeln(jsonEncode(cmd));
    } catch (e) {
      logger.e('Failed to write to fingerprint sidecar', error: e);
    }
  }

  void _setStatus(FingerprintStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  /// Locate the sidecar binary: explicit override → next to the app executable
  /// → a dev build inside the repo.
  String? _resolveSidecarPath(String? override) {
    final binName =
        Platform.isWindows ? 'fingerprint_bridge.exe' : 'fingerprint_bridge';

    final candidates = <String>[
      if (override != null && override.trim().isNotEmpty) override.trim(),
    ];

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates
        ..add('$exeDir${Platform.pathSeparator}$binName')
        ..add('$exeDir${Platform.pathSeparator}data'
            '${Platform.pathSeparator}flutter_assets'
            '${Platform.pathSeparator}native'
            '${Platform.pathSeparator}$binName');
    } catch (_) {
      // resolvedExecutable can throw in some contexts; ignore.
    }

    // Dev fallback: the binary built straight from the repo.
    candidates.add('native/fingerprint_bridge/build/$binName');

    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  Future<void> dispose() async {
    _send({'cmd': 'quit'});
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _process?.kill();
    _process = null;
    await _statusController.close();
    await _captureController.close();
    await _errorController.close();
  }
}
