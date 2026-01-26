import 'dart:async';

import 'package:flutter/material.dart';
import 'package:price_checker/pages/attendance/attendance_page.dart';
import 'package:price_checker/pages/products/product_details_page.dart';
import 'package:price_checker/services/http_service.dart';
import 'package:price_checker/services/helpers.dart';

import '../components/custom_snack_bar.dart';
import '../controllers/price_checker_page_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/product_model.dart';

class PriceCheckerPage extends StatefulWidget {
  const PriceCheckerPage({super.key});

  @override
  State<PriceCheckerPage> createState() => _PriceCheckerPageState();
}

class _PriceCheckerPageState extends State<PriceCheckerPage> {
  Timer? _timer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isEmpty = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _onSubmitted(String value) async {
    if (value.length <= 2) {
      showSnack(
        customSnack(
          'Not enough keywords!',
          "Please enter at least 3 or more letters.",
          ContentType.warning,
        ),
        context,
      );
      _searchController.clear();
      _focusOnSearch();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await httpGet('/items/search', {'term': value});
      final productsJson = response['data']['products'];
      products = productsJson
          .map<ProductModel>((e) => ProductModel.fromJson(e))
          .toList();

      if (!mounted) return;

      if (products.isEmpty) {
        showSnack(
          customSnack(
            'Product not found.',
            "We can't seem to find the product you are looking for. Please ask cashiers for more info.",
            ContentType.failure,
          ),
          context,
        );
      }

      setState(() {
        _isEmpty = products.isEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to connect to server. Please check your connection.';
      });
      showSnack(
        customSnack(
          'Connection Error',
          _errorMessage!,
          ContentType.failure,
        ),
        context,
      );
    }

    _searchController.clear();
    _focusOnSearch();
    _startTimer();
  }

  void _focusOnSearch() {
    _searchFocus.requestFocus();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 6), () {
      setState(() {
        _isEmpty = true;
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () => _focusOnSearch());
    _startTimer();
  }

  Widget _buildLogoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 100,
        height: 100,
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/transparent_store.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildIdleStateCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 64,
              color: appColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Scan barcode\nto check price',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: ThemeController.getPrimaryTextColor(context),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'or type product name below',
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? AppTheme.darkSecondaryText
                    : AppTheme.lightSecondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(appColor),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Searching...',
              style: TextStyle(
                fontSize: 20,
                color: ThemeController.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
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
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: ThemeController.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleProductsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          itemCount: products.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              title: Text(
                product.name ?? 'Unknown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ThemeController.getPrimaryTextColor(context),
                ),
              ),
              subtitle: product.barcode != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Barcode: ${product.barcode}',
                        style: TextStyle(
                          fontSize: 13,
                          color: ThemeController.getSecondaryTextColor(context),
                        ),
                      ),
                    )
                  : null,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: appColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₱ ${numberFormatter.format(getProductPrice(product))}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: appColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductStatusWidget() {
    if (_isLoading) {
      return _buildLoadingCard(context);
    }

    if (_errorMessage != null) {
      return _buildErrorCard(context);
    }

    if (_isEmpty) {
      return _buildIdleStateCard(context);
    }

    if (products.length == 1) {
      return ProductDetailsPage(product: products[0]);
    }

    return _buildMultipleProductsCard(context);
  }

  Widget _buildSearchCard(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: true,
        textInputAction: TextInputAction.go,
        onSubmitted: _onSubmitted,
        style: TextStyle(
          fontSize: 18,
          color: ThemeController.getPrimaryTextColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Tap here, then scan or type product name...',
          hintStyle: TextStyle(
            fontSize: 16,
            color: ThemeController.getSecondaryTextColor(context),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search_rounded,
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
              // Header with logo and settings
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo card at top left
                    _buildLogoCard(context),

                    // Right side buttons
                    Row(
                      children: [
                        // Attendance button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AttendancePage(),
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
                                Icons.calendar_today_outlined,
                                color: ThemeController.getSecondaryTextColor(
                                    context),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Settings button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => promptHostDialog(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ThemeController.getCardColor(context)
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.settings_rounded,
                                color: ThemeController.getSecondaryTextColor(
                                    context),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildProductStatusWidget(),
                ),
              ),

              // Search bar at bottom
              Padding(
                padding: const EdgeInsets.all(24),
                child: _buildSearchCard(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
