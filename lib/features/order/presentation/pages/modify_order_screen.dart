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
  bool _isLoadingServices = false;
  bool _hasMoreServices = true;
  int _servicesPage = 1;
  bool _isSubmitting = false;

  final TextEditingController _reasonController = TextEditingController();
  Map<String, String>? _pendingReplacement;
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
        );
      }).toList();
      ref.read(orderModificationProvider.notifier).loadFromOrderItems(modItems);

      // Load first page of services
      _loadMoreServices();
    });
  }

  Future<void> _loadMoreServices() async {
    if (_isLoadingServices || !_hasMoreServices) return;
    setState(() => _isLoadingServices = true);
    try {
      final result = await ApiService.listService(page: _servicesPage);
      final fetched = result['services'] as List<ServiceModal>;
      final hasMore = result['hasMore'] as bool;
      if (mounted) {
        setState(() {
          _services.addAll(fetched);
          _hasMoreServices = hasMore;
          _servicesPage++;
          _isLoadingServices = false;
          print('Services loaded: ${_services.length}, hasMore: $hasMore');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Opens a paginated bottom sheet to select (or replace) a service.
  Future<void> _openServicePicker({
    required OrderModificationController controller,
    String? replaceId,
    required String orderId,
  }) async {
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
              );
              setState(() {
                _pendingReplacement = {
                  'orderItemId': replaceId,
                  'serviceId': service.serviceId ?? '',
                };
              });
            } else {
              controller.addItem(service.title, service.price);
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
                    // Text(
                    //   '${_services.length} services loaded',
                    //   style: GoogleFonts.outfit(
                    //     fontSize: 12,
                    //     color: AppTheme.textSecondary,
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 16),

                // If no active items, show add service button
                if (state.items.where((i) => !i.isRemoved).isEmpty)
                  _buildServicePickerButton(
                    controller: controller,
                    orderId: orderId,
                  ),

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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildItemImage(item.imageUrl),
                                  const SizedBox(width: 16),
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
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (item.quantity > 0)
                                          Text(
                                            '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Replace button — only for service type items
                              if ((item.type ?? '').toLowerCase() == 'service')
                                _buildServicePickerButton(
                                  controller: controller,
                                  replaceId: item.id,
                                  orderId: orderId,
                                  isReplace: true,
                                ),
                            ],
                          ),
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

  Widget _buildServicePickerButton({
    required OrderModificationController controller,
    String? replaceId,
    required String orderId,
    bool isReplace = false,
  }) {
    return GestureDetector(
      onTap: () => _openServicePicker(
        controller: controller,
        replaceId: replaceId,
        orderId: orderId,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              isReplace ? Icons.swap_horiz : Icons.add_circle_outline,
              color: AppTheme.primaryColor,
              size: isReplace ? 18 : 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isReplace ? 'Replace Item' : 'Add Item from List',
                style: GoogleFonts.outfit(
                  fontSize: isReplace ? 13 : 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            if (_isLoadingServices && _services.isEmpty)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            else
              Text(
                '${_services.length} services',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                color: AppTheme.primaryColor, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForApproval() async {
    final orderId = widget.order?.id;
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
        await ApiService.serviceModification(
          orderId,
          pending['orderItemId']!,
          pending['serviceId']!,
          note,
        );
      }

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
