import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/model/order_details.dart' as api;
import '../../../../core/model/ServiceModal.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/order_modification_provider.dart';
import 'approval_waiting_screen.dart';

class ModifyOrderScreen extends ConsumerStatefulWidget {
  final api.OrderDetails? order;
  const ModifyOrderScreen({super.key, this.order});

  @override
  ConsumerState<ModifyOrderScreen> createState() => _ModifyOrderScreenState();
}

class _ModifyOrderScreenState extends ConsumerState<ModifyOrderScreen> {
  List<ServiceModal> _services = [];
  bool _isSubmitting = false;

  // Controller for the reason field — persists across rebuilds so cursor doesn't reset
  final TextEditingController _reasonController = TextEditingController();

  // Stores the pending replacement for the Submit call:
  // { 'orderItemId': String, 'serviceId': String }
  Map<String, String>? _pendingReplacement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load real order items into modification state
      final apiItems = widget.order?.items ?? [];
      final modItems = apiItems.map((item) {
        final imageUrl = (item.media != null && item.media!.isNotEmpty)
            ? item.media!.first.url
            : null;
        return OrderItem(
          id: item.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: item.itemDetails?.name ?? 'Unknown Item',
          price: double.tryParse(item.price ?? '0') ?? 0.0,
          quantity: item.quantity ?? 1,
          imageUrl: imageUrl,
          type: item.type,
        );
      }).toList();
      ref.read(orderModificationProvider.notifier).loadFromOrderItems(modItems);

      // Fetch real service list for Replace Item dropdown
      try {
        final services = await ApiService.listService();
        if (mounted) {
          setState(() => _services = services);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderModificationProvider);
    final controller = ref.read(orderModificationProvider.notifier);

    final apiItems = widget.order?.items ?? [];
    final customerName = widget.order?.customerName ?? 'Unknown Customer';
    final customerEmail = widget.order?.userDetails?.email ?? '';
    final orderId = widget.order?.id ?? 'N/A';
    final orderStatus = widget.order?.orderStatus ?? 'Active';
    final totalPrice = widget.order?.totalPrice ?? '0.00';

    // Build dropdown list from real fetched services (includes serviceId for API)
    final products = _services.map((s) => {
          'name': s.title,
          'price': s.price,
          'serviceId': s.serviceId ?? '',
        }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Modify Order',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Customer & Order Info Header ──
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Customer: $customerName',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (customerEmail.isNotEmpty)
                          Text(
                            customerEmail,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            orderStatus.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Items List ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Logic to clear all items
                      },
                      child: Text(
                        'Clear all',
                        style:
                            GoogleFonts.outfit(color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // If no active items, show add dropdown
                if (state.items.where((i) => !i.isRemoved).isEmpty)
                  _buildAddDropdown(products, controller),

                // Render each item card
                ...state.items
                    .where((i) => !i.isRemoved)
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Item image
                                      _buildItemImage(item.imageUrl),
                                      const SizedBox(width: 16),
                                      // Name + price
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (item.quantity > 0)
                                              Text(
                                                '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppTheme.primaryColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Qty controls
                                      // if (item.quantity >= 1)
                                      //   Column(
                                      //     mainAxisAlignment:
                                      //         MainAxisAlignment.center,
                                      //     children: [
                                      //       const SizedBox(height: 24),
                                      //       Container(
                                      //         decoration: BoxDecoration(
                                      //           color: Colors.grey[50],
                                      //           borderRadius:
                                      //               BorderRadius.circular(8),
                                      //           border: Border.all(
                                      //               color: Colors
                                      //                   .grey.shade100),
                                      //         ),
                                      //         padding:
                                      //             const EdgeInsets.all(2),
                                      //         child: Row(
                                      //           mainAxisSize:
                                      //               MainAxisSize.min,
                                      //           children: [
                                      //             _buildQtyBtn(
                                      //               Icons.remove,
                                      //               () =>
                                      //                   controller
                                      //                       .updateQuantity(
                                      //                 item.id,
                                      //                 item.quantity - 1,
                                      //               ),
                                      //             ),
                                      //             Padding(
                                      //               padding: const EdgeInsets
                                      //                   .symmetric(
                                      //                   horizontal: 8),
                                      //               child: Text(
                                      //                 item.quantity
                                      //                     .toString(),
                                      //                 style:
                                      //                     GoogleFonts.outfit(
                                      //                   fontSize: 14,
                                      //                   fontWeight:
                                      //                       FontWeight.bold,
                                      //                 ),
                                      //               ),
                                      //             ),
                                      //             _buildQtyBtn(
                                      //               Icons.add,
                                      //               () =>
                                      //                   controller
                                      //                       .updateQuantity(
                                      //                 item.id,
                                      //                 item.quantity + 1,
                                      //               ),
                                      //               isColor: true,
                                      //             ),
                                      //           ],
                                      //         ),
                                      //       ),
                                      //     ],
                                      //   ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Replace dropdown — only for service type items
                                  if ((item.type ?? '').toLowerCase() == 'service')
                                    _buildAddDropdown(products, controller,
                                        isSmall: true, replaceId: item.id, orderId: orderId),
                                ],
                              ),
                            ),
                            // X button top-right
                            // Positioned(
                            //   top: 3,
                            //   right: 3,
                            //   child: GestureDetector(
                            //     onTap: () => controller.removeItem(item.id),
                            //     child: Container(
                            //       padding: const EdgeInsets.all(4),
                            //       decoration: BoxDecoration(
                            //         color: Colors.grey[100],
                            //         shape: BoxShape.circle,
                            //       ),
                            //       child: const Icon(
                            //         Icons.close,
                            //         color: AppTheme.textSecondary,
                            //         size: 16,
                            //       ),
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ),

                const SizedBox(height: 16),

                // Totals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original Total',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '₹$totalPrice',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Total',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${state.newTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Difference',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+ ₹${(state.newTotal - state.originalTotal).toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Reason Input
                Text(
                  'Reason for change',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Add a note for the approver explaining why this change is necessary...',
                    hintStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _isSubmitting
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                )
              : ElevatedButton(
                  onPressed: _submitForApproval,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Submit for Approval',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// Called when Submit for Approval is tapped.
  /// If a replacement was selected, calls serviceModification API first.
  Future<void> _submitForApproval() async {
    final orderId = widget.order?.id;
    // Read directly from controller — avoids stale provider state
    final note = _reasonController.text.trim().isEmpty
        ? null
        : _reasonController.text.trim();
    final controller = ref.read(orderModificationProvider.notifier);

    setState(() => _isSubmitting = true);

    try {
      final pending = _pendingReplacement;
      if (pending != null &&
          orderId != null &&
          pending['orderItemId'] != null &&
          pending['serviceId'] != null) {
        // Call serviceModification with all required IDs
        await ApiService.serviceModification(
          orderId,
          pending['orderItemId']!,
          pending['serviceId']!,
          note, // reason — may be null
        );
      }

      // Record the request locally
      controller.submitRequest();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ApprovalWaitingScreen(orderId: orderId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildItemImage(String? imageUrl) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.grey,
                  size: 32,
                ),
              ),
            )
          : const Icon(
              Icons.inventory_2_outlined,
              color: Colors.grey,
              size: 32,
            ),
    );
  }

  Widget _buildAddDropdown(
    List<Map<String, dynamic>> products,
    OrderModificationController controller, {
    bool isSmall = false,
    String? replaceId,
    String? orderId,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          hint: Row(
            children: [
              Icon(
                replaceId != null
                    ? Icons.swap_horiz
                    : Icons.add_circle_outline,
                color: AppTheme.primaryColor,
                size: isSmall ? 18 : 24,
              ),
              const SizedBox(width: 8),
              Text(
                replaceId != null ? 'Replace Item' : 'Add Item from List',
                style: GoogleFonts.outfit(
                  fontSize: isSmall ? 13 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon:
              const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
          items: products.map((product) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: product,
              child: Text(
                '${product['name']} - ₹${product['price']}',
                style: GoogleFonts.outfit(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              if (replaceId != null) {
                // Update UI immediately; API is called on Submit
                controller.replaceItem(
                  replaceId,
                  val['name'] as String,
                  val['price'] as double,
                );
                // Store pending replacement data for Submit to send to API
                setState(() {
                  _pendingReplacement = {
                    'orderItemId': replaceId,
                    'serviceId': val['serviceId'] as String? ?? '',
                  };
                });
              } else {
                controller.addItem(
                  val['name'] as String,
                  val['price'] as double,
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap,
      {bool isColor = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isColor ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isColor
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                  )
                ],
        ),
        child: Icon(
          icon,
          size: 14,
          color: isColor ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }
}