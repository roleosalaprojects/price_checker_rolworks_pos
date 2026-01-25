import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/price_checker_page_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/attendance_record_model.dart';
import '../../services/http_service.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();

  List<AttendanceRecord> _records = [];
  AttendanceSummary? _summary;
  Map<String, dynamic>? _employee;
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _selectedMonth = DateTime.now();

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

  Future<void> _onBarcodeSubmitted(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _fetchData(barcode);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('HttpException: ', '');
      _employee = null;
      _records = [];
      _summary = null;
    }

    _barcodeController.clear();
    _focusOnBarcode();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData(String barcode) async {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    // Fetch history
    final historyResponse = await httpGet('/v1/attendance/history', {
      'barcode': barcode,
      'from': DateFormat('yyyy-MM-dd').format(startOfMonth),
      'to': DateFormat('yyyy-MM-dd').format(endOfMonth),
    });

    if (historyResponse['success'] == true) {
      _employee = historyResponse['data']['employee'];
      final recordsList = historyResponse['data']['records'] as List;
      _records = recordsList.map((e) => AttendanceRecord.fromJson(e)).toList();
    } else {
      throw Exception(historyResponse['message'] ?? 'Failed to fetch history');
    }

    // Fetch summary
    final summaryResponse = await httpGet('/v1/attendance/summary', {
      'barcode': barcode,
      'month': _selectedMonth.month.toString(),
      'year': _selectedMonth.year.toString(),
    });

    if (summaryResponse['success'] == true) {
      _summary = AttendanceSummary.fromJson(summaryResponse['data']);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
    if (_employee != null) {
      _onBarcodeSubmitted(_employee!['barcode']);
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return DateFormat('hh:mm a').format(dateTime);
  }

  Widget _buildIdleState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            'to view attendance history',
            style: TextStyle(
              fontSize: 16,
              color: ThemeController.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
              color: ThemeController.getSecondaryTextColor(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ThemeController.getPrimaryTextColor(context),
                ),
              ),
            ),
            IconButton(
              onPressed: _selectedMonth.month == DateTime.now().month &&
                      _selectedMonth.year == DateTime.now().year
                  ? null
                  : () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
              color: ThemeController.getSecondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeHeader(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: appColor.withValues(alpha: 0.2),
              child: Text(
                (_employee?['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: appColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _employee?['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeController.getPrimaryTextColor(context),
                  ),
                ),
                Text(
                  'ID: ${_employee?['barcode'] ?? '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeController.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    if (_summary == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              context,
              'Present',
              _summary!.totalDaysPresent.toString(),
              Colors.green,
              Icons.check_circle_outline_rounded,
            ),
            Container(
              height: 50,
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
            _buildSummaryItem(
              context,
              'Absent',
              _summary!.totalDaysAbsent.toString(),
              Colors.red,
              Icons.cancel_outlined,
            ),
            Container(
              height: 50,
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
            _buildSummaryItem(
              context,
              'Hours',
              _summary!.totalHoursRendered.toStringAsFixed(1),
              appColor,
              Icons.timer_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ThemeController.getPrimaryTextColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: ThemeController.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(BuildContext context, AttendanceRecord record) {
    final isPresent = record.status == 'present';
    final statusColor = isPresent ? Colors.green : Colors.red;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date column
            Container(
              width: 60,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd').format(record.date),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    DateFormat('EEE').format(record.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Time info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.login_rounded,
                        size: 16,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(record.timeIn),
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeController.getPrimaryTextColor(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.logout_rounded,
                        size: 16,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(record.timeOut),
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeController.getPrimaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  if (record.hoursRendered > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${record.hoursRendered.toStringAsFixed(2)} hours',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeController.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                record.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList(BuildContext context) {
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: ThemeController.getSecondaryTextColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ThemeController.getPrimaryTextColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No records found for this month',
              style: TextStyle(
                fontSize: 14,
                color: ThemeController.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        return _buildRecordCard(context, _records[index]);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(appColor),
        ),
      );
    }

    if (_errorMessage != null && _employee == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ThemeController.getPrimaryTextColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ThemeController.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_employee == null) {
      return _buildIdleState(context);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildEmployeeHeader(context),
        ),
        const SizedBox(height: 8),
        _buildMonthSelector(context),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSummaryCard(context),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildRecordsList(context),
        ),
      ],
    );
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
                    const SizedBox(width: 16),

                    // Title
                    Text(
                      'Attendance History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeController.getPrimaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _buildContent(context),
              ),

              // Barcode input
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
