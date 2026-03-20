import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/model/order_details.dart' as api;
import '../../../../core/model/ServiceModal.dart';
import '../../../../Model/Product.dart';
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
  final ApiService _apiService = ApiService();
  List<ServiceModal> _services = [];
  List<Product> _products = [];
  bool _isLoadingServices = false;
  bool _isLoadingProducts = false;
  bool _hasMoreServices = true;
  int _servicesPage = 1;
  bool _isSubmitting = false;

  /// Tracks how many distinct modifications the agent has made (max 3).
  /// Computed dynamically from provider state:
  ///   - Removing an ORIGINAL item = +1
  ///   - Adding a NEW item (still in list) = +1
  ///   - Replacing an ORIGINAL item = +1
  ///   - Adding then removing a NEW item => both cancel out (0)
  int get _modificationCount {
    final state = ref.read(orderModificationProvider);
    // Original items removed (not newly added)
    final removedOriginal = state.items.where((i) => i.isRemoved && !i.isNew).length;
    // Newly added items still present (not removed)
    final addedAndKept = state.newlyAddedItems.length;
    // Original items replaced (price or name changed, not removed, not new)
    final replaced = state.modifiedOriginalItems.length;
    return removedOriginal + addedAndKept + replaced;
  }

  final TextEditingController _reasonController = TextEditingController();
  // Tracks the selected serviceId per item (keyed by replaceId or 'add')
  final Map<String, String?> _selectedServiceByItem = {};


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load order items into modification state
      final apiItems = widget.order?.items ?? [];
      final modItems = apiItems.map((item) {
        final imageUrl = (item.media != null && item.media!.isNotEmpty)
            ? item.media!.first.url
            : null;
        final price = double.tryParse(item.price ?? '0') ?? 0.0;
        final qty = item.quantity ?? 1;
        return OrderItem(
          id: item.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: item.itemDetails?.name ?? 'Unknown Item',
          price: price,
          quantity: qty,
          originalPrice: price,
          originalQuantity: qty,
          imageUrl: imageUrl,
          type: item.type,
          // Store the item type in uppercase for the API payload
          itemType: (item.type ?? '').toUpperCase(),
          newEntityId: item.productId ?? item.serviceId,
          originalEntityId: item.productId ?? item.serviceId,
        );
      }).toList();
      ref.read(orderModificationProvider.notifier).loadFromOrderItems(modItems);

      // Load all services and products using the order's location
      final lat = widget.order?.latitude?.toString();
      final lng = widget.order?.longitude?.toString();
      _loadServices(lat: lat, lng: lng);
      _loadProducts(lat: lat, lng: lng);
    });
  }

  Future<void> _loadServices({String? lat, String? lng}) async {
    if (_isLoadingServices) return;
    setState(() => _isLoadingServices = true);
    try {
      final result = await ApiService.listService(page: 1, size: 100, lat: lat, lng: lng);
      final fetched = result['services'] as List<ServiceModal>;
      if (mounted) {
        setState(() {
          _services = fetched;
          _hasMoreServices = false;
          _isLoadingServices = false;
          print('All services loaded: ${_services.length}');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _loadProducts({String? lat, String? lng}) async {
    if (_isLoadingProducts) return;
    setState(() => _isLoadingProducts = true);
    try {
      final result = await _apiService.getProducts(page: 1, size: 100, lat: lat, lng: lng);
      if (mounted && result.isSuccess && result.data != null) {
        setState(() {
          _products = result.data!;
          _isLoadingProducts = false;
          print('All products loaded: ${_products.length}');
        });
      } else {
        if (mounted) setState(() => _isLoadingProducts = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Returns true if a modification can still be made (computed count < 3).
  /// Shows an alert and returns false when the limit is already reached.
  Future<bool> _checkModCount() async {
    if (_modificationCount >= 3) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Modification Limit Reached',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You can only make 3 modifications per request. You have already reached the limit.',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  /// Opens a paginated bottom sheet to select (or replace) a service.
  Future<void> _openServicePicker({
    required OrderModificationController controller,
    String? replaceId,
    required String orderId,
  }) async {
   // if (!await _checkModCount()) return;
    if (!mounted) return;
    final itemKey = replaceId ?? 'add';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: _ServicePickerSheet(
          initialServices: _services,
          hasMoreInitially: _hasMoreServices,
          nextPage: _servicesPage,
          replaceId: replaceId,
          initialSelectedServiceId: _selectedServiceByItem[itemKey],
          onServiceSelected: (service) {
            setState(() {
              _selectedServiceByItem[itemKey] = service.serviceId;
            });
            if (replaceId != null) {
              controller.replaceItem(
                replaceId,
                service.title,
                service.price,
                newEntityId: service.serviceId,
              );
            } else {
              final added = controller.addItem(
                service.title,
                service.price,
                type: 'service',
                newEntityId: service.serviceId,
              );
              if (!added && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${service.title} is already in the list', style: GoogleFonts.outfit()),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
          onServicesUpdated: (updatedList, hasMore, nextPage) {
            setState(() {
              _services = updatedList;
              _hasMoreServices = hasMore;
              _servicesPage = nextPage;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderModificationProvider);
    final controller = ref.read(orderModificationProvider.notifier);

    final customerName = widget.order?.customerName ?? 'Unknown Customer';
    final customerEmail = widget.order?.userDetails?.email ?? '';
    final orderId = widget.order?.id ?? 'N/A';
    final orderStatus = widget.order?.orderStatus ?? 'Active';
    final totalPrice = widget.order?.totalPrice ?? '0.00';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
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
          // Customer & Order Info Header
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

          // Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Service Section ---
                _buildSectionHeader(
                  title: 'Service',
                  addLabel: 'Add Service',
                  color: AppTheme.primaryColor,
                  onAdd: () => _openServicePicker(controller: controller, orderId: orderId),
                ),
                const SizedBox(height: 12),
                ...state.items
                    .where((i) => !i.isRemoved && (i.type ?? '').toLowerCase() == 'service')
                    .map((item) => _buildItemCard(item, controller, orderId, isReadOnly: !item.isNew)),
                const SizedBox(height: 24),

                // --- Product Section ---
                _buildSectionHeader(
                  title: 'Product',
                  addLabel: 'Add Product',
                  color: AppTheme.primaryColor,
                  onAdd: () => _openProductPicker(controller: controller),
                ),
                const SizedBox(height: 12),
                ...state.items
                    .where((i) => !i.isRemoved && (i.type ?? '').toLowerCase() == 'product')
                    .map((item) => _buildItemCard(item, controller, orderId, isReadOnly: !item.isNew)),
                const SizedBox(height: 24),

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
                  onPressed: _showSummaryBeforeSubmit,
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

  Future<void> _showSummaryBeforeSubmit() async {
    final state = ref.read(orderModificationProvider);
    if (state.newlyAddedItems.isEmpty && state.modifiedOriginalItems.isEmpty && state.removedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to submit.')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Review Modifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.newlyAddedItems.isNotEmpty) ...[
                  _summaryHeader('New Items Added'),
                  ...state.newlyAddedItems.map((i) => _summaryItem(i.name, i.price, i.quantity)),
                  const SizedBox(height: 12),
                ],
                if (state.modifiedOriginalItems.isNotEmpty) ...[
                  _summaryHeader('Modifications'),
                  ...state.modifiedOriginalItems.map((i) => _summaryItem(i.name, i.price, i.quantity, isUpdate: true)),
                  const SizedBox(height: 12),
                ],
                if (state.removedItems.isNotEmpty) ...[
                  _summaryHeader('Items Removed'),
                  ...state.removedItems.map((i) => Text('• ${i.name}', style: GoogleFonts.outfit(color: Colors.red))),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    Text('₹${state.newTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Dismiss', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm & Proceed', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _submitForApproval();
    }
  }

  Future<void> _submitForApproval() async {
    final orderId = widget.order?.id;
    if (orderId == null) return;

    final note = _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim();
    final state = ref.read(orderModificationProvider);
    final controller = ref.read(orderModificationProvider.notifier);

    // Build the items payload from all modified/added/removed items.
    final List<Map<String, dynamic>> apiItems = [];

    for (final item in state.items) {
      if (item.isNew && item.isRemoved) continue; // Added then removed locally

      final typeLabel = item.itemType ?? (item.type ?? '').toUpperCase();

      if (item.isRemoved) {
        apiItems.add({
          'modification_type': 'REMOVE',
          'item_type': typeLabel,
          'quantity': item.originalQuantity,
          'order_item_id': item.id,
        });
      } else if (item.isNew) {
        apiItems.add({
          'modification_type': 'ADD',
          'item_type': typeLabel,
          'quantity': item.quantity,
          'new_entity_id': item.newEntityId,
        });
      } else if (item.isChanged) {
        final isDifferentEntity = item.newEntityId != item.originalEntityId;

        if (isDifferentEntity) {
          // Changed to a different product/service
          apiItems.add({
            'modification_type': 'REPLACE',
            'item_type': typeLabel,
            'quantity': item.quantity,
            'order_item_id': item.id,
            'new_entity_id': item.newEntityId,
          });
        } else if (item.quantity > item.originalQuantity) {
          // Same entity, increased quantity -> Use ADD for the delta
          apiItems.add({
            'modification_type': 'ADD',
            'item_type': typeLabel,
            'quantity': item.quantity - item.originalQuantity,
            'new_entity_id': item.newEntityId,
          });
        } else if (item.quantity < item.originalQuantity) {
          // Same entity, decreased quantity -> Use REMOVE for the delta
          apiItems.add({
            'modification_type': 'REMOVE',
            'item_type': typeLabel,
            'quantity': item.originalQuantity - item.quantity,
            'order_item_id': item.id,
          });
        } else if (item.price != item.originalPrice) {
          // Price change only (if ever implemented) -> STILL use REPLACE with same ID
          // (Server might allow this, or might need a different method)
          apiItems.add({
            'modification_type': 'REPLACE',
            'item_type': typeLabel,
            'quantity': item.quantity,
            'order_item_id': item.id,
            'new_entity_id': item.newEntityId,
          });
        }
      }
    }

    if (apiItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to submit.')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ApiService.serviceAndProductModification(orderId, note, apiItems);

      controller.submitRequest();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ApprovalWaitingScreen(orderId: orderId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _summaryHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textSecondary)),
  );

  Widget _summaryItem(String name, double price, int qty, {bool isUpdate = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(isUpdate ? '• ' : '+ ', style: TextStyle(color: isUpdate ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
        Expanded(child: Text(name, style: GoogleFonts.outfit(fontSize: 13))),
        Text('${qty}x ₹${price.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _buildSectionHeader({required String title, required String addLabel, required Color color, required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: onAdd,
          child: Text(
            addLabel,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(OrderItem item, OrderModificationController controller, String orderId, {bool isReadOnly = false}) {
    final itemType = (item.type ?? '').toLowerCase();
    final isService = itemType == 'service';
    final typeLabel = isService ? 'SERVICE' : 'PRODUCT';
    final typeColor =  AppTheme.primaryColor ;
    final typeBgColor =  AppTheme.primaryColor.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: item.isChanged || item.isNew ? typeBgColor : Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              children: [
                Icon(isService ? Icons.design_services_outlined : Icons.inventory_2_outlined, size: 12, color: typeColor),
                const SizedBox(width: 6),
                Text(typeLabel, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor, letterSpacing: 1.0)),
                if (item.isNew) ...[
                  const SizedBox(width: 8),
                  _badge('NEW', Colors.orange),
                ] else if (item.isChanged) ...[
                  const SizedBox(width: 8),
                  _badge('MODIFIED', Colors.blue),
                ],
                const Spacer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildItemImage(item.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₹${(item.price * item.quantity).toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                _qtyButton(
                                  icon: Icons.remove,
                                  onTap: () => controller.updateQuantity(item.id, item.quantity - 1),
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 30),
                                  alignment: Alignment.center,
                                  child: Text(
                                    item.quantity.toString(),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                _qtyButton(
                                  icon: Icons.add,
                                  onTap: () => controller.updateQuantity(item.id, item.quantity + 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(HugeIcons.strokeRoundedDelete02, color: Colors.red, size: 24),
                  onPressed: () => _confirmRemoveItem(controller, item),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: _buildReplacementPickerButton(
              controller: controller,
              replaceId: item.id,
              orderId: orderId,
              type: itemType,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
  );

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildItemImage(String? imageUrl) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 32)),
            )
          : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 32),
    );
  }

  Future<void> _confirmRemoveItem(OrderModificationController controller, OrderItem item) async {
    // if (!await _checkModCount()) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Item?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to Remove "${item.name}" from this order?', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Remove', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.removeItem(item.id);
    }
  }

  Future<void> _openProductPicker({required OrderModificationController controller, String? replaceId}) async {
    // if (!await _checkModCount()) return;
    if (!mounted) return;
    String query = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bsCtx) => SafeArea(
        child: StatefulBuilder(
          builder: (bsCtx, setSheetState) {
            final filtered = _products.where((p) => p.name.toLowerCase().contains(query)).toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, sc) => Container(
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    Container(margin: const EdgeInsets.only(top: 12, bottom: 16), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor, size: 22),
                          const SizedBox(width: 10),
                          Expanded(child: Text(replaceId != null ? 'Replace Product' : 'Add Product', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                          Text('${_products.length} products', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        onChanged: (v) => setSheetState(() => query = v.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search products…',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isLoadingProducts
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                          : filtered.isEmpty
                              ? Center(child: Text('No products found', style: GoogleFonts.outfit(color: AppTheme.textSecondary)))
                              : ListView.builder(
                                  controller: sc,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final p = filtered[i];
                                    final double price = p.price.toDouble();
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      leading: Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                        child: Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor, size: 22),
                                      ),
                                      title: Text(p.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                      subtitle: p.brand != null ? Text(p.brand!, style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12)) : null,
                                      trailing: Text(
                                        '₹${price.toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      onTap: () {
                                        if (replaceId != null) {
                                          controller.replaceItem(
                                            replaceId,
                                            p.name,
                                            price,
                                            newEntityId: p.id,
                                          );
                                        } else {
                                          final added = controller.addItem(
                                            p.name,
                                            price,
                                            type: 'product',
                                            newEntityId: p.id,
                                          );
                                          if (!added && mounted) {
                                            ScaffoldMessenger.of(bsCtx).showSnackBar(
                                              SnackBar(
                                                content: Text('${p.name} is already in the list', style: GoogleFonts.outfit()),
                                                backgroundColor: Colors.black87,
                                              ),
                                            );
                                          }
                                        }
                                        Navigator.pop(bsCtx);
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReplacementPickerButton({
    required OrderModificationController controller,
    required String replaceId,
    required String orderId,
    required String type,
  }) {
    final isService = type.toLowerCase() == 'service';
    final count = isService ? _services.length : _products.length;
    final label = isService ? 'services' : 'products';
    final isLoading = isService ? _isLoadingServices : _isLoadingProducts;

    return GestureDetector(
      onTap: () {
        if (isService) {
          _openServicePicker(
            controller: controller,
            replaceId: replaceId,
            orderId: orderId,
          );
        } else {
          _openProductPicker(
            controller: controller,
            replaceId: replaceId,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Replace Item',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            if (isLoading && count == 0)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              )
            else
              Text(
                '$count $label',
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor, size: 14),
          ],
        ),
      ),
    );
  }
  Widget _buildServicePickerButton({required OrderModificationController controller, String? replaceId, required String orderId, bool isReplace = false}) {
    return GestureDetector(
      onTap: () => _openServicePicker(controller: controller, replaceId: replaceId, orderId: orderId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2))),
        child: Row(
          children: [
            Icon(isReplace ? Icons.swap_horiz : Icons.add_circle_outline, color: AppTheme.primaryColor, size: isReplace ? 18 : 22),
            const SizedBox(width: 10),
            Expanded(child: Text(isReplace ? 'Replace Item' : 'Add Item from List', style: GoogleFonts.outfit(fontSize: isReplace ? 13 : 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
            if (_isLoadingServices && _services.isEmpty) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
            else Text('${_services.length} services', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor, size: 14),
          ],
        ),
      ),
    );
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
    );
  }


// ─────────────────────────────────────────────────────────────────────────────
// Paginated Service Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ServicePickerSheet extends StatefulWidget {
  final List<ServiceModal> initialServices;
  final bool hasMoreInitially;
  final int nextPage;
  final String? replaceId;
  final String? initialSelectedServiceId; // pre-select previously chosen service
  final void Function(ServiceModal service) onServiceSelected;
  final void Function(List<ServiceModal> updatedList, bool hasMore, int nextPage)
      onServicesUpdated;

  const _ServicePickerSheet({
    required this.initialServices,
    required this.hasMoreInitially,
    required this.nextPage,
    required this.replaceId,
    this.initialSelectedServiceId,
    required this.onServiceSelected,
    required this.onServicesUpdated,
  });

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  late List<ServiceModal> _services;
  late bool _hasMore;
  late int _nextPage;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedServiceId;

  @override
  void initState() {
    super.initState();
    _services = List.from(widget.initialServices);
    _hasMore = widget.hasMoreInitially;
    _nextPage = widget.nextPage;
    // Restore previously selected service
    _selectedServiceId = widget.initialSelectedServiceId;

    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });

    // If we have no services yet, load first page
    if (_services.isEmpty && _hasMore) {
      _fetchMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels >= metrics.maxScrollExtent - 200) {
        _fetchMore();
      }
    }
    return false;
  }

  Future<void> _fetchMore() async {
    if (_isLoading || !_hasMore) return;
    if(!mounted)return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.listService(page: _nextPage);
      final fetched = result['services'] as List<ServiceModal>;
      final hasMore = result['hasMore'] as bool;
      if (mounted) {
        setState(() {
          _services.addAll(fetched);
          _hasMore = hasMore;
          _nextPage++;
          _isLoading = false;
        });
        // Notify parent to keep state in sync
        widget.onServicesUpdated(_services, _hasMore, _nextPage);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ServiceModal> get _filtered {
    if (_query.isEmpty) return _services;
    return _services
        .where((s) => s.title.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final isReplace = widget.replaceId != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.62,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    isReplace ? Icons.swap_horiz : Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isReplace ? 'Replace Service' : 'Select Service',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_services.length}${_hasMore ? '+' : ''} services',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search services...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade100),

            // Service list
            Expanded(
              child: filtered.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _query.isNotEmpty
                                ? 'No services match "$_query"'
                                : 'No services available',
                            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 24,
                            endIndent: 24,
                            color: Colors.grey.shade50),
                        itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          // Loading indicator at the bottom (only shows if we have more)
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: AppTheme.primaryColor,
                                      strokeWidth: 2,
                                    )
                                  : const SizedBox.shrink(), // Automatic scroll handles it
                            ),
                          );
                        }

                        final service = filtered[index];
                        final isSelected =
                            _selectedServiceId == service.serviceId;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.04)
                              : Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            title: Text(
                              service.title,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '₹${service.price.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              setState(() =>
                                  _selectedServiceId = service.serviceId);
                              widget.onServiceSelected(service);
                              Future.delayed(
                                  const Duration(milliseconds: 180),
                                  () => Navigator.of(context).pop());
                            },
                          ),
                        );
                      },
                    ),
            ),
            ),
            // Footer
            if(!_hasMore && _services.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8, bottom: 20, left: 16, right: 16),
                child: Text(
                  'End of list • ${_services.length} services loaded',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
