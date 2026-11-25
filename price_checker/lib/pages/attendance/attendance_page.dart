import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../components/custom_snack_bar.dart';
import '../../controllers/main_controller.dart';
import '../../controllers/price_checker_page_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/attendance_record_model.dart';
import '../../services/fingerprint/kiosk_terminal.dart';
import '../../services/fingerprint/reader.dart';
import '../../services/http_service.dart';
import '../fingerprint/enrol_page.dart';
import '../fingerprint/higher_access_dialog.dart';
import 'attendance_history_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();

  AttendanceRecord? _todayRecord;
  Map<String, dynamic>? _employee;
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;

  // Fingerprint (2026-11-25): tap, then a finger. The reader is armed on a
  // tap only (libfprint stops a reader left waiting ~4 min); the barcode
  // stays (refused by the server once the store switches it off).
  bool _fpScanning = false;
  String _fpLine = '';

  bool get _fpReady =>
      fingerprintEnabled &&
      FingerprintReader.instance.supported &&
      KioskTerminal.registered &&
      KioskTerminal.prints.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () => _focusOnBarcode());
    if (fingerprintEnabled && FingerprintReader.instance.supported && KioskTerminal.registered) {
      FingerprintReader.instance.ensureStarted().then((_) async {
        await KioskTerminal.refreshGallery();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    if (_fpScanning) FingerprintReader.instance.cancel();
    super.dispose();
  }

  Future<void> _scanFinger() async {
    setState(() {
      _fpScanning = true;
      _fpLine = 'Getting the reader ready…';
      _errorMessage = null;
    });
    await KioskTerminal.refreshGallery();
    final ReaderResult result = await FingerprintReader.instance.scan(onProgress: (e) {
      if (!mounted) return;
      setState(() {
        _fpLine = switch (e['event']) {
          'waiting' => 'Place your finger on the reader',
          'retry' => 'Press again — hold the finger flat and still',
          'paused' => 'Too many fingers not recognised: wait ${e['seconds']} seconds',
          _ => _fpLine,
        };
      });
    });
    if (!mounted) return;
    final KioskPrint? who = result.isMatch ? KioskTerminal.byPrint(result.printId) : null;
    if (who == null) {
      setState(() {
        _fpScanning = false;
        _errorMessage = result.event == 'cancelled' ? null : (result.problem ?? 'Not recognised.');
      });
      if (_errorMessage != null) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _employee == null) setState(() => _errorMessage = null);
        });
      }
      return;
    }
    setState(() => _isLoading = true);
    final Map<String, dynamic>? today = await KioskTerminal.today(who.userId);
    if (!mounted) return;
    setState(() {
      _fpScanning = false;
      _isLoading = false;
      _applyLookupResponse({
        'success': true,
        'data': {
          'employee': {'id': int.tryParse(who.userId) ?? 0, 'name': who.name, 'barcode': null, 'finger': who},
          'today_status': today,
        },
      });
    });
  }

  Future<void> _addFingerprints() async {
    if (_fpScanning) await _cancelScan();
    if (!mounted) return;
    final KioskGrant? grant = await askHigherAccess(context, purpose: 'enrol');
    if (grant == null || !mounted) return;
    final dynamic why = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KioskEnrolPage(grant: grant)));
    await KioskTerminal.refreshGallery();
    if (!mounted) return;
    setState(() {});
    if (why is String) showSnack(customSnack('Add fingerprints', why, ContentType.warning), context);
  }

  Future<void> _cancelScan() async {
    await FingerprintReader.instance.cancel();
    if (mounted) setState(() => _fpScanning = false);
  }

  /// A punch by the finger that matched (signed by this kiosk).
  Future<void> _punchByFinger(KioskPrint who, String action) async {
    final Map<String, dynamic> response = await KioskTerminal.punch(who: who, action: action);
    final bool ok = response['success'] == true;
    if (ok && response['data'] is Map && response['data']['attendance'] is Map) {
      _todayRecord = AttendanceRecord.fromJson(Map<String, dynamic>.from(response['data']['attendance']));
    }
    if (!mounted) return;
    showSnack(
      customSnack(
        ok ? (action == 'in' ? 'Time-In Recorded' : 'Time-Out Recorded') : 'Not Recorded',
        '${response['message'] ?? (ok ? 'Done.' : 'The server refused the punch.')}',
        ok ? ContentType.success : ContentType.failure,
      ),
      context,
    );
  }

  /// Populate employee + today's status from a lookup/identify response. Shared
  /// by the barcode and fingerprint paths so both behave identically.
  void _applyLookupResponse(Map<String, dynamic> response) {
    if (response['success'] == true) {
      _employee = response['data']['employee'];
      final todayStatus = response['data']['today_status'];

      if (todayStatus != null) {
        _todayRecord = AttendanceRecord(
          id: 0,
          uuid: '',
          employeeId: _employee!['id'],
          storeId: currentStoreId,
          date: DateTime.now(),
          timeIn: todayStatus['time_in'] != null
              ? DateFormat('hh:mm a').parse(todayStatus['time_in'])
              : null,
          timeOut: todayStatus['time_out'] != null
              ? DateFormat('hh:mm a').parse(todayStatus['time_out'])
              : null,
          hoursRendered: parseDouble(todayStatus['hours_rendered']),
          status: todayStatus['has_timed_in'] == true ? 'present' : 'absent',
        );
      } else {
        _todayRecord = null;
      }
      _errorMessage = null;
    } else {
      _errorMessage = response['message'] ?? 'Employee not found';
      _employee = null;
      _todayRecord = null;
    }
  }

  void _focusOnBarcode() {
    _barcodeFocus.requestFocus();
  }

  void _clearState() {
    setState(() {
      _todayRecord = null;
      _employee = null;
      _errorMessage = null;
    });
  }

  Future<void> _onBarcodeSubmitted(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await httpGet('/v1/attendance/lookup', {'barcode': barcode});
      _applyLookupResponse(response);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('HttpException: ', '');
      _employee = null;
      _todayRecord = null;
    }

    _barcodeController.clear();
    _focusOnBarcode();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _timeIn() async {
    if (_employee == null) return;

    setState(() => _isProcessing = true);

    if (_employee!['finger'] is KioskPrint) {
      await _punchByFinger(_employee!['finger'] as KioskPrint, 'in');
      if (mounted) setState(() => _isProcessing = false);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _clearState();
      });
      return;
    }

    try {
      final response = await httpPost('/v1/attendance/time-in', {
        'barcode': _employee!['barcode'],
        'store_id': currentStoreId,
      });

      if (response['success'] == true) {
        _todayRecord = AttendanceRecord.fromJson(response['data']['attendance']);
        if (mounted) {
          showSnack(
            customSnack(
              'Time-In Recorded',
              response['message'] ?? 'Welcome! Have a great day at work.',
              ContentType.success,
            ),
            context,
          );
        }
      } else {
        if (mounted) {
          showSnack(
            customSnack('Error', response['message'] ?? 'Failed to record time-in', ContentType.failure),
            context,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          customSnack('Time-In Failed', e.toString().replaceAll('HttpException: ', ''), ContentType.failure),
          context,
        );
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }

    // Auto-clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _clearState();
    });
  }

  Future<void> _timeOut() async {
    if (_employee == null) return;

    setState(() => _isProcessing = true);

    if (_employee!['finger'] is KioskPrint) {
      await _punchByFinger(_employee!['finger'] as KioskPrint, 'out');
      if (mounted) setState(() => _isProcessing = false);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _clearState();
      });
      return;
    }

    try {
      final response = await httpPost('/v1/attendance/time-out', {
        'barcode': _employee!['barcode'],
      });

      if (response['success'] == true) {
        _todayRecord = AttendanceRecord.fromJson(response['data']['attendance']);
        if (mounted) {
          showSnack(
            customSnack(
              'Time-Out Recorded',
              response['message'] ?? 'Great work today! See you tomorrow.',
              ContentType.success,
            ),
            context,
          );
        }
      } else {
        if (mounted) {
          showSnack(
            customSnack('Error', response['message'] ?? 'Failed to record time-out', ContentType.failure),
            context,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          customSnack('Time-Out Failed', e.toString().replaceAll('HttpException: ', ''), ContentType.failure),
          context,
        );
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }

    // Auto-clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _clearState();
    });
  }

  Widget _buildTimeDisplay(BuildContext context) {
    final now = DateTime.now();
    return Column(
      children: [
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            return Text(
              DateFormat('hh:mm:ss a').format(DateTime.now()),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: ThemeController.getPrimaryTextColor(context),
                letterSpacing: 2,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEEE, MMMM d, y').format(now),
          style: TextStyle(
            fontSize: 18,
            color: ThemeController.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleState(BuildContext context) {
    if (_fpScanning) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fingerprint, size: 120, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            _fpLine,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ThemeController.getPrimaryTextColor(context)),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 220,
            height: 56,
            child: OutlinedButton(onPressed: _cancelScan, child: const Text('Cancel', style: TextStyle(fontSize: 18))),
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeDisplay(context),
        const SizedBox(height: 48),
        Icon(Icons.badge_outlined, size: 80, color: appColor.withValues(alpha: 0.6)),
        const SizedBox(height: 24),
        Text(
          _fpReady ? 'Tap Fingerprint, or scan your ID' : 'Scan your ID barcode',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ThemeController.getPrimaryTextColor(context)),
        ),
        const SizedBox(height: 8),
        Text(
          'to clock in or out',
          style: TextStyle(fontSize: 16, color: ThemeController.getSecondaryTextColor(context)),
        ),
        if (_fpReady) ...[
          const SizedBox(height: 28),
          SizedBox(
            width: 320,
            height: 72,
            child: ElevatedButton.icon(
              key: const ValueKey('kiosk-fingerprint'),
              onPressed: _scanFinger,
              icon: const Icon(Icons.fingerprint, size: 36),
              label: const Text('Fingerprint', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ),
        ] else if (fingerprintEnabled && FingerprintReader.instance.supported) ...[
          const SizedBox(height: 24),
          ValueListenableBuilder<ReaderStatus>(
            valueListenable: FingerprintReader.instance.status,
            builder: (context, status, _) => Text(
              !KioskTerminal.registered
                  ? 'Fingerprint: not set up (Settings → Register this kiosk)'
                  : (status.problem ?? 'Fingerprint: no one enrolled yet'),
              style: TextStyle(fontSize: 14, color: ThemeController.getSecondaryTextColor(context)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(appColor),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Looking up employee...',
          style: TextStyle(
            fontSize: 18,
            color: ThemeController.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 80,
          color: Colors.red.shade400,
        ),
        const SizedBox(height: 24),
        Text(
          'Employee Not Found',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: ThemeController.getPrimaryTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage ?? 'Invalid barcode. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: ThemeController.getSecondaryTextColor(context),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _clearState,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: appColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeState(BuildContext context) {
    final hasTimedIn = _todayRecord?.hasTimedIn ?? false;
    final hasTimedOut = _todayRecord?.hasTimedOut ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Left column - Time Display
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeDisplay(context),
              ],
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),

          // Right column - Employee Info & Actions
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Employee info card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: appColor.withValues(alpha: 0.2),
                            child: Text(
                              (_employee?['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: appColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _employee?['name'] ?? 'Unknown Employee',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: ThemeController.getPrimaryTextColor(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _employee?['finger'] != null ? 'Fingerprint' : 'ID: ${_employee?['barcode'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: ThemeController.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Today's status inline
                          if (hasTimedIn) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatusItem(
                                    context,
                                    'In',
                                    _todayRecord?.timeIn != null
                                        ? DateFormat('hh:mm a').format(_todayRecord!.timeIn!)
                                        : '--:--',
                                    Colors.green,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  _buildStatusItem(
                                    context,
                                    'Out',
                                    _todayRecord?.timeOut != null
                                        ? DateFormat('hh:mm a').format(_todayRecord!.timeOut!)
                                        : '--:--',
                                    Colors.red,
                                  ),
                                  if (hasTimedOut) ...[
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    _buildStatusItem(
                                      context,
                                      'Hours',
                                      _todayRecord!.hoursRendered.toStringAsFixed(2),
                                      appColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Action button
                          if (_isProcessing)
                            const SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(appColor),
                              ),
                            )
                          else if (!hasTimedIn)
                            _buildActionButton(
                              label: 'TIME IN',
                              icon: Icons.login_rounded,
                              color: Colors.green,
                              onPressed: _timeIn,
                            )
                          else if (hasTimedIn && !hasTimedOut)
                            _buildActionButton(
                              label: 'TIME OUT',
                              icon: Icons.logout_rounded,
                              color: Colors.red,
                              onPressed: _timeOut,
                            )
                          else
                            _buildCompletedBadge(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.green.shade400,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'Complete',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(220, 70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: ThemeController.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_errorMessage != null && _employee == null) {
      return _buildErrorState(context);
    }

    if (_employee != null) {
      return _buildEmployeeState(context);
    }

    return _buildIdleState(context);
  }

  Widget _buildBarcodeInput(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _barcodeController,
        focusNode: _barcodeFocus,
        autofocus: true,
        textInputAction: TextInputAction.go,
        onSubmitted: _onBarcodeSubmitted,
        style: TextStyle(
          fontSize: 18,
          color: ThemeController.getPrimaryTextColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Scan employee ID barcode...',
          hintStyle: TextStyle(
            fontSize: 16,
            color: ThemeController.getSecondaryTextColor(context),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 28,
              color: appColor,
            ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    AppTheme.darkBackground,
                    Color(0xFF1A1A2E),
                  ]
                : const [
                    AppTheme.lightBackground,
                    Color(0xFFE8E8E8),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ThemeController.getCardColor(context)
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color:
                                ThemeController.getSecondaryTextColor(context),
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                    // Title
                    Text(
                      'Attendance',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeController.getPrimaryTextColor(context),
                      ),
                    ),

                    Row(children: [
                    // Add fingerprints (2026-11-25): after a manager's higher access.
                    if (fingerprintEnabled && FingerprintReader.instance.supported && KioskTerminal.registered) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const ValueKey('kiosk-enrol'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _addFingerprints,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThemeController.getCardColor(context).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.fingerprint_rounded,
                                color: ThemeController.getSecondaryTextColor(context), size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // History button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceHistoryPage(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ThemeController.getCardColor(context)
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color:
                                ThemeController.getSecondaryTextColor(context),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    ]),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: _buildContent(context),
              ),

              // Barcode input at bottom
              Padding(
                padding: const EdgeInsets.all(24),
                child: _buildBarcodeInput(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
