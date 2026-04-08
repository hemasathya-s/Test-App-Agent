import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/model/order_details.dart';
import '../../../../core/model/product_model.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';


class ProductListPage extends StatefulWidget {
  final OrderDetails order;
  const ProductListPage({super.key, required this.order});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  // Map of productId to Possession details from inventory
  Map<String, Possession> possessionMap = {};
  bool isLoading = true;
  String? errorMessage;
  
  // Map of productId to Set of selected serial numbers
  final Map<String, Set<String>> _selectionsByProduct = {};

  List<OrderItem> get _productItems => widget.order.items
      ?.where((item) => (item.type ?? '').toUpperCase() == 'PRODUCT')
      .toList() ?? [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final productIds = _productItems
          .map((item) => item.productId ?? item.itemDetails?.fullDetails?.id)
          .whereType<String>()
          .toSet()
          .toList();

      if (productIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      final String productIdQuery = productIds.join(',');
      // Fetching without pagination limits (using a large size)
      final response = await ApiService.getProductDetails(productIdQuery, page: 1, size: 100);
      
      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final Map<String, Possession> newMap = {};
        for (var pos in response.data!.myPossession) {
          newMap[pos.productDetails.id] = pos;
        }
        setState(() {
          possessionMap = newMap;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response.error ?? "Failed to load inventory details";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  // Helper to get total required quantity for a specific product ID across all matching order items
  int _getRequiredQuantity(String productId) {
    if (widget.order.items == null) return 0;
    return widget.order.items!
        .where((item) => (item.productId ?? item.itemDetails?.fullDetails?.id) == productId && (item.type ?? '').toUpperCase() == 'PRODUCT')
        .fold(0, (sum, item) => sum + (item.quantity ?? 1));
  }

  // Helper to get total required count across all products in the order
  int get _totalRequiredCount {
    if (widget.order.items == null) return 0;
    return widget.order.items!
        .where((item) => (item.type ?? '').toUpperCase() == 'PRODUCT')
        .fold(0, (sum, item) => sum + (item.quantity ?? 1));
  }

  int get _totalSelectedCount {
    return _selectionsByProduct.values.fold(0, (sum, set) => sum + set.length);
  }

  void _toggleSelection(String productId, String serial) {
    final requiredQuantity = _getRequiredQuantity(productId);
    
    if (requiredQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This product is not required in the current order.', style: GoogleFonts.outfit()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      if (!_selectionsByProduct.containsKey(productId)) {
        _selectionsByProduct[productId] = {serial};
      } else {
        if (_selectionsByProduct[productId]!.contains(serial)) {
          _selectionsByProduct[productId]!.remove(serial);
          if (_selectionsByProduct[productId]!.isEmpty) {
            _selectionsByProduct.remove(productId);
          }
        } else {
          // Check if we already reached the required quantity
          if (_selectionsByProduct[productId]!.length >= requiredQuantity) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You can only select $requiredQuantity unit(s) for this product.', style: GoogleFonts.outfit()),
                backgroundColor: Colors.black87,
              ),
            );
            return;
          }
          _selectionsByProduct[productId]!.add(serial);
        }
      }
    });
  }

  List<Map<String, dynamic>> _buildPayload() {
    final List<Map<String, dynamic>> payload = [];
    if (widget.order.items == null) return payload;

    _selectionsByProduct.forEach((productId, serials) {
      final relevantItems = widget.order.items!
          .where((item) => (item.productId ?? item.itemDetails?.fullDetails?.id) == productId && (item.type ?? '').toUpperCase() == 'PRODUCT')
          .toList();

      final List<String> serialList = serials.toList();
      int serialIndex = 0;

      for (var item in relevantItems) {
        final int qty = item.quantity ?? 1;
        final int take = (serialList.length - serialIndex).clamp(0, qty);
        if (take > 0) {
          payload.add({
            "order_item_id": item.id,
            "serial_numbers": serialList.sublist(serialIndex, serialIndex + take),
          });
          serialIndex += take;
        }
      }
    });
    return payload;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Inventory Products',
          style: GoogleFonts.outfit(
            color: AppTheme.secondaryColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft01, color: Colors.black),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadProducts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _productItems.isEmpty
                  ? Center(
                      child: Text(
                        'No products found.',
                        style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      color: AppTheme.primaryColor,
                      child: SafeArea(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _productItems.length,
                          itemBuilder: (context, index) {
                            final item = _productItems[index];
                            final productId = item.productId ?? item.itemDetails?.fullDetails?.id ?? '';
                            final possession = possessionMap[productId];
                            final selectedSerials = _selectionsByProduct[productId] ?? {};
                            final requiredQuantity = item.quantity ?? 1;
                            
                            return ProductCard(
                              key: ValueKey(productId),
                              orderItem: item,
                              possession: possession,
                              selectedSerials: selectedSerials,
                              requiredQuantity: requiredQuantity,
                              onSelect: (serial) => _toggleSelection(productId, serial),
                            );
                          },
                        ),
                      ),
                    ),
      bottomNavigationBar: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_totalSelectedCount / $_totalRequiredCount Selected',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _totalSelectedCount == _totalRequiredCount ? Colors.green : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _totalSelectedCount == _totalRequiredCount 
                                ? 'All requirements met' 
                                : 'Select all required serials to proceed',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _totalSelectedCount == _totalRequiredCount ? Colors.green : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _totalSelectedCount != _totalRequiredCount
                          ? null
                          : () {
                              final payload = _buildPayload();

                              context.push('/checklist', extra: {
                                'order': widget.order,
                                'inventory': payload,
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: const Text(
                        'Product Update',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final OrderItem orderItem;
  final Possession? possession;
  final Set<String> selectedSerials;
  final int requiredQuantity;
  final Function(String) onSelect;

  const ProductCard({
    super.key,
    required this.orderItem,
    this.possession,
    required this.selectedSerials,
    required this.requiredQuantity,
    required this.onSelect,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  bool isLiked = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleExpanded() {
    setState(() {
      isExpanded = !isExpanded;
      if (isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = widget.possession != null;
    final String productName = widget.orderItem.itemDetails?.name ?? widget.orderItem.itemDetails?.fullDetails?.name ?? 'Unknown Product';
    final String productDescription = widget.orderItem.itemDetails?.fullDetails?.description ?? '';
    final String? imageUrl = (widget.orderItem.itemDetails?.fullDetails?.media != null && widget.orderItem.itemDetails!.fullDetails!.media!.isNotEmpty)
        ? (widget.orderItem.itemDetails!.fullDetails!.media!.first is Map ? widget.orderItem.itemDetails!.fullDetails!.media!.first['url'] : null)
        : null;

    final Color cardColor = isAvailable ? Colors.white : Colors.grey.shade100;
    final Color textColor = isAvailable ? AppTheme.secondaryColor : Colors.grey;
    final Color subTextColor = isAvailable ? AppTheme.textSecondary : Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: isAvailable ? toggleExpanded : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isAvailable ? const Color(0xFFF0F0F0) : Colors.grey.shade200,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              color: isAvailable ? null : Colors.grey,
                              colorBlendMode: isAvailable ? null : BlendMode.saturation,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          productDescription,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: subTextColor,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              isAvailable ? 'Stock: ${widget.possession!.availableStock}' : 'Out of Stock',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isAvailable ? AppTheme.primaryColor : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // if (isAvailable)
                            //   Container(
                            //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            //     decoration: BoxDecoration(
                            //       color: widget.selectedSerials.length == widget.requiredQuantity
                            //           ? Colors.green.withOpacity(0.1)
                            //           : Colors.orange.withOpacity(0.1),
                            //       borderRadius: BorderRadius.circular(6),
                            //     ),
                            //     child: Text(
                            //       'Selected: ${widget.selectedSerials.length}/${widget.requiredQuantity}',
                            //       style: GoogleFonts.outfit(
                            //         fontSize: 12,
                            //         fontWeight: FontWeight.bold,
                            //         color: widget.selectedSerials.length == widget.requiredQuantity
                            //             ? Colors.green
                            //             : Colors.orange,
                            //       ),
                            //     ),
                            //   ),
                            const Spacer(),
                            // Expand Arrow
                            if (isAvailable)
                              RotationTransition(
                                turns: _rotationAnimation,
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable Dropdown Section
          if (isAvailable)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Text(
                            'Select Serial Numbers',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.possession!.availableSerialNumbers.map((serialNumber) {
                            final isSelected = widget.selectedSerials.contains(serialNumber);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => widget.onSelect(serialNumber),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primaryColor.withOpacity(0.1)
                                        : const Color(0xFFF5F7FA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primaryColor
                                                : AppTheme.textSecondary.withOpacity(0.5),
                                            width: 2,
                                          ),
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          serialNumber,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? AppTheme.primaryColor
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Selected',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}