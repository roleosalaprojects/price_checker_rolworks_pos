import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../components/custom_snack_bar.dart';
import '../../controllers/main_controller.dart';
import '../../controllers/price_checker_page_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/attendance_record_model.dart';
import '../../services/http_service.dart';
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

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () => _focusOnBarcode());
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
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

      if (response['success'] == true) {
        _employee = response['data']['employee'];
        final todayStatus = response['data']['today_status'];

        if (todayStatus != null) {
          // Build a minimal attendance record from the status
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
      } else {
        _errorMessage = response['message'] ?? 'Employee not found';
        _employee = null;
        _todayRecord = null;
      }
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeDisplay(context),
        const SizedBox(height: 48),
        Icon(
          Icons.badge_outlined,
          size: 80,
          color: appColor.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 24),
        Text(
          'Scan your ID barcode',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: ThemeController.getPrimaryTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'to clock in or out',
          style: TextStyle(
            fontSize: 16,
            color: ThemeController.getSecondaryTextColor(context),
          ),
        ),
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeDisplay(context),
            const SizedBox(height: 24),

            // Employee info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: appColor.withValues(alpha: 0.2),
                      child: Text(
                        (_employee?['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: appColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _employee?['name'] ?? 'Unknown Employee',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ThemeController.getPrimaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${_employee?['barcode'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeController.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action button
            if (_isProcessing)
              const SizedBox(
                width: 60,
                height: 60,
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
              _buildCompletedState(context),

            const SizedBox(height: 16),

            // Today's status
            if (hasTimedIn) _buildTodayStatusCard(context),
          ],
        ),
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

  Widget _buildCompletedState(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 80,
          color: Colors.green.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          'Attendance Complete',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'See you tomorrow!',
          style: TextStyle(
            fontSize: 16,
            color: ThemeController.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayStatusCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
            if (_todayRecord?.hasTimedOut ?? false) ...[
              Container(
                width: 1,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
