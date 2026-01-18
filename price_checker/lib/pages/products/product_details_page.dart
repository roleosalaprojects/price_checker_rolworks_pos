import 'package:flutter/material.dart';
import 'package:price_checker/controllers/price_checker_page_controller.dart';
import 'package:price_checker/services/helpers.dart';

import '../../controllers/theme_controller.dart';
import '../../models/product_model.dart';
import '../../services/http_service.dart';

class ProductDetailsPage extends StatelessWidget {
  final ProductModel product;
  const ProductDetailsPage({super.key, required this.product});

  Widget _buildUnitPriceCard(
    BuildContext context,
    String unitName,
    double price,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkBackground.withValues(alpha: 0.5)
            : AppTheme.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            unitName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: ThemeController.getSecondaryTextColor(context),
            ),
          ),
          Text(
            '₱ ${numberFormatter.format(price)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeController.getPrimaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemUnits(BuildContext context, ProductModel product) {
    if (product.itemUnits == null || product.itemUnits!.isEmpty) {
      return [];
    }

    return product.itemUnits!.map((e) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildUnitPriceCard(
          context,
          e.unit?.name ?? 'Unknown Unit',
          getProductUnitPrice(product, e).toDouble(),
        ),
      );
    }).toList();
  }

  Widget _buildProductImage(BuildContext context) {
    if (product.image == null) {
      return _buildPlaceholderImage(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        'http://$host/${product.image}',
        fit: BoxFit.cover,
        height: double.infinity,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: appColor,
              strokeWidth: 3,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(context);
        },
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkBackground
            : AppTheme.lightBackground,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: ThemeController.getSecondaryTextColor(context),
            ),
            const SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(
                fontSize: 12,
                color: ThemeController.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemUnits = _buildItemUnits(context, product);
    final hasUnitPrices = itemUnits.isNotEmpty;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image card
            SizedBox(
              width: 180,
              height: 180,
              child: Card(
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildProductImage(context),
              ),
            ),
            const SizedBox(width: 24),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Product name
                  Text(
                    product.name ?? 'Unknown Product',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: ThemeController.getPrimaryTextColor(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Divider
                  Container(
                    height: 3,
                    width: 60,
                    decoration: BoxDecoration(
                      color: appColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main price
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appColor,
                          appColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: appColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '₱ ${numberFormatter.format(getProductPrice(product))}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Unit prices section
                  if (hasUnitPrices) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Other Unit Prices',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ThemeController.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...itemUnits,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
