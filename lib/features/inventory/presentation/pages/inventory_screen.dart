import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../Model/Product.dart';
import '../../../../Model/ToolStock.dart';
import '../../../../Model/ProductStock.dart';
import '../../../../Model/Tool.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../Model/ServiceCategory.dart';
import '../../../../Model/PaginatedProductResponse.dart';
import '../../../../Model/AuthResponse.dart';
import 'package:flutter/material.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  StreamSubscription? _prodWsSub;
  StreamSubscription? _toolWsSub;

  // ── Tab ─────────────────────────────────────────────────────────────────────
  String _activeTab = 'Tools';
  bool _isLoading = true;
  String? _toolsError;
  String? _productsError;

  // ── Search ───────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ── Browse / Add-Item Panel ───────────────────────────────────────────────
  bool _showAddPanel = false; // controls the inline add-item UI
  // 'all' means no filter
  String _selectedCategoryId = 'all';
  List<Map<String, dynamic>> _catalogCategories = [];

  // ── Catalog Browse State ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _catalogItems = [];
  bool _isBrowseLoading = false;

  // ── Cart State ───────────────────────────────────────────────────────────────
  // itemId -> quantity (0 means not in cart)
  final Map<String, int> _cartQty = {};
  // itemId -> submitting flag
  final Map<String, bool> _submitting = {};

  // ── Movements (for stock view) ────────────────────────────────────────────────
  List<Map<String, dynamic>> _allMovements = [];

  // ── Real stock data ───────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _toolsItems = [];
  final List<Map<String, dynamic>> _productItems = [];

  // ── Shimmer ───────────────────────────────────────────────────────────────────
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  List<Map<String, dynamic>> get _items =>
      _activeTab == 'Tools' ? _toolsItems : _productItems;

  // ─────────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );

    _loadInitialData();
    _apiService.connectMovementWebSocket();
    _apiService.connectToolMovementWebSocket();
    _listenToWebSockets();
  }

  void _listenToWebSockets() {
    _prodWsSub = _apiService.movementStream.listen(_handleWsMessage);
    _toolWsSub = _apiService.toolMovementStream.listen(_handleWsMessage);
  }

  void _handleWsMessage(Map<String, dynamic> data) {
    if (data['type'] == 'initial_data') {
      setState(() {
        final List movements = data['movements'] ?? [];
        for (var nm in movements) {
          final newId = (nm['id'] ?? nm['movement_id'] ?? '').toString();
          if (newId.isNotEmpty &&
              !_allMovements.any((m) =>
                  (m['id'] ?? m['movement_id'] ?? '').toString() == newId)) {
            _allMovements.add(nm);
          }
        }
      });
    } else {
      final status = (data['approved_status'] ?? '').toString().toUpperCase();
      final mid = (data['id'] ?? data['movement_id'] ?? '').toString();
      if (status == 'APPROVED') _loadInitialData();
      if (mid.isNotEmpty) {
        setState(() {
          bool found = false;
          for (var m in _allMovements) {
            if ((m['id'] ?? m['movement_id'] ?? '').toString() == mid) {
              m['approved_status'] = data['approved_status'];
              found = true;
            }
          }
          if (!found) _allMovements.add(data);
        });
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _prodWsSub?.cancel();
    _toolWsSub?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _apiService.disposeWebSocket();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadToolStocks(), _loadProductStocks()]);
    if (mounted) setState(() => _isLoading = false);
  }

  void _onTabSwitch(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _isLoading = true;
      _searchQuery = '';
      _selectedCategoryId = 'all';
      _catalogItems = [];
      _catalogCategories = [];
      _showAddPanel = false;
      _cartQty.clear();
    });
    _searchController.clear();
    final load = tab == 'Tools' ? _loadToolStocks() : _loadProductStocks();
    load.then((_) { if (mounted) setState(() => _isLoading = false); });
  }

  Future<void> _loadToolStocks() async {
    final res = await _apiService.getMyToolStocks(page: 1, size: 50);
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() {
        _toolsItems.clear();
        _toolsItems.addAll(res.data!.map((t) => t.toItemMap()));
        _toolsError = null;
      });
    } else {
      setState(() => _toolsError = res.error ?? 'Failed to load tool stocks');
    }
  }

  Future<void> _loadProductStocks() async {
    final res = await _apiService.getMyProductStocks();
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() {
        _productItems.clear();
        _productItems.addAll(res.data!.map((p) => p.toItemMap()));
        _productsError = null;
      });
    } else {
      setState(() => _productsError = res.error ?? 'Failed to load product stocks');
    }
  }

  // ── Search & Browse ───────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), _fetchCatalog);
  }

  void _onCategorySelected(String catId) {
    setState(() => _selectedCategoryId = catId);
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    setState(() => _isBrowseLoading = true);

    final catId = _selectedCategoryId == 'all' ? null : _selectedCategoryId;

    if (_activeTab == 'Tools') {
      final res = await ApiService.listTools(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: catId,
        size: 100,
      );
      if (!mounted) return;
      final items = <Map<String, dynamic>>[];
      final catSet = <String, Map<String, dynamic>>{};
      if (res.isSuccess && res.data != null) {
        for (final t in res.data!) {
          items.add({
            'id': t.id,
            'name': t.name,
            'price': null,
            'categoryId': t.categoryId,
            'categoryName': t.categoryName,
            'isTool': true,
          });
          if (t.categoryId != null) {
            catSet[t.categoryId!] = {
              'id': t.categoryId,
              'name': t.categoryName ?? 'Other'
            };
          }
        }
      }
      setState(() {
        _catalogItems = items;
        // ✅ Only update categories if we don't have them yet, or if we are showing "All"
        if (_catalogCategories.isEmpty ||
            (_searchQuery.isEmpty && _selectedCategoryId == 'all')) {
          _catalogCategories = catSet.values.toList();
        }
        _isBrowseLoading = false;
      });
    } else {
      final res = await ApiService.listProduct(size: 100);
      if (!mounted) return;
      final items = <Map<String, dynamic>>[];
      final catSet = <String, Map<String, dynamic>>{};
      if (res.isSuccess && res.data != null) {
        final q = _searchQuery.toLowerCase();
        for (final p in res.data!.products) {
          if (q.isNotEmpty &&
              !p['name'].toString().toLowerCase().contains(q)) {
            continue;
          }
          // Extract pricing
          final pricing =
              (p['pricing'] is List && (p['pricing'] as List).isNotEmpty)
                  ? (p['pricing'] as List).first
                  : null;
          final price = pricing?['price'];

          // Extract categories
          final cats = (p['categories'] is List) ? p['categories'] as List : [];

          // Check if matches selected category
          if (catId != null) {
            final matchesCat =
                cats.any((c) => c is Map && c['id']?.toString() == catId);
            if (!matchesCat) continue;
          }

          items.add({
            'id': p['id'],
            'name': p['name'],
            'price': price,
            'categories': cats,
            'isTool': false,
          });

          for (final cat in cats) {
            if (cat is Map && cat['id'] != null) {
              catSet[cat['id'].toString()] = {
                'id': cat['id'],
                'name': cat['name'] ?? 'Other'
              };
            }
          }
        }
      }
      setState(() {
        _catalogItems = items;
        // ✅ Only update categories if we don't have them yet, or if we are showing "All"
        if (_catalogCategories.isEmpty ||
            (_searchQuery.isEmpty && _selectedCategoryId == 'all')) {
          _catalogCategories = catSet.values.toList();
        }
        _isBrowseLoading = false;
      });
    }
  }

  // ── Submit Request ────────────────────────────────────────────────────────────
  Future<void> _submitRequest(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final qty = _cartQty[id] ?? 1;
    setState(() => _submitting[id] = true);

    bool success = false;
    if (item['isTool'] == true) {
      final res = await _apiService.requestToolMovement(toolId: id, stock: qty, type: 'GET');
      success = res.isSuccess;
    } else {
      final res = await _apiService.requestProductMovement(productId: id, stock: qty, type: 'GET');
      success = res.isSuccess;
    }

    if (mounted) {
      setState(() {
        _submitting.remove(id);
        // Always reset to "Add" button state after attempt, as requested
        _cartQty.remove(id); 
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(success ? 'Request submitted!' : 'Unavaliable to submit request'),
          backgroundColor:  Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          'My Bag Stock',
          style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.textSecondary),
            onPressed: () => context.push('/request-inventory'),
          ),
        ],
      ),
      floatingActionButton: _showAddPanel
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _showAddPanel = true;
                  _selectedCategoryId = 'all';
                  _catalogItems = [];
                  _catalogCategories = [];
                });
                // Load all catalog items immediately
                _fetchCatalog();
              },
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add Item',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
      body: Column(
        children: [
          // ── Tab Toggle ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: ['Tools', 'Products'].map((tab) {
                  final isActive = _activeTab == tab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onTabSwitch(tab),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: isActive
                              ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tab,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Main Content Area (stock view OR add-item panel) ───────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _showAddPanel
                  ? _buildAddItemPanel()
                  : _buildStockContent(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add-Item Inline Panel ─────────────────────────────────────────────────────
  Widget _buildAddItemPanel() {
    return Column(
      key: const ValueKey('add_panel'),
      children: [
        // ── Panel Header: Search + Close ─────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search ${_activeTab.toLowerCase()}...',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            })
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                  ),
                  style: GoogleFonts.outfit(fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              // Close button
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _showAddPanel = false;
                    _searchQuery = '';
                    _selectedCategoryId = 'all';
                    _catalogItems = [];
                    _catalogCategories = [];
                    _cartQty.clear();
                  });
                  _searchDebounce?.cancel();
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),

        // ── Category Chips ───────────────────────────────────────────────
        if (_catalogCategories.isNotEmpty) _buildCategoryChips(),

        // ── Catalog List ─────────────────────────────────────────────────
        Expanded(child: _buildBrowseContent()),
      ],
    );
  }

  // ── Category Chips ────────────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    final chips = <Map<String, dynamic>>[
      {'id': 'all', 'name': 'All'},
      ..._catalogCategories,
    ];
    return Container(
      height: 48,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final chip = chips[idx];
          final chipId = chip['id'].toString();
          final isSelected = _selectedCategoryId == chipId;
          return GestureDetector(
            onTap: () => _onCategorySelected(chipId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Icon(Icons.check, size: 13, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    chip['name'].toString(),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Browse / Catalog View ─────────────────────────────────────────────────────
  Widget _buildBrowseContent() {
    if (_isBrowseLoading) return _buildShimmerList();

    if (_catalogItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No items found',
              style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _catalogItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) => _buildCatalogCard(_catalogItems[idx]),
    );
  }

  // ── Catalog Item Card (with Add/[-][+]/Submit) ────────────────────────────────
  Widget _buildCatalogCard(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final qty = _cartQty[id] ?? 0;
    final isInCart = qty > 0;
    final isSubmitting = _submitting[id] == true;

    // Extract price text
    final price = item['price'];
    String priceText = '';
    if (price != null) {
      priceText = '₹${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: isInCart
            ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.2)
            : null,
      ),
      child: Row(
        children: [
          // ── Name + Price ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (priceText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    priceText,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Action Area ───────────────────────────────────────────────
          if (!isInCart)
            // Add Button
            GestureDetector(
              onTap: () => setState(() => _cartQty[id] = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            // Qty Stepper + Submit
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // [-] qty [+]
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(22),
                    color: AppTheme.surfaceColor,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minus
                      GestureDetector(
                        onTap: () => setState(() {
                          if (((_cartQty[id] ?? 1) - 1) <= 0) {
                            _cartQty.remove(id);
                          } else {
                            _cartQty[id] = (_cartQty[id] ?? 1) - 1;
                          }
                        }),
                        child: Container(
                          width: 32, height: 32,
                          alignment: Alignment.center,
                          child: Icon(Icons.remove, size: 16, color: AppTheme.textPrimary),
                        ),
                      ),
                      // Quantity
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$qty',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      // Plus
                      GestureDetector(
                        onTap: () => setState(() => _cartQty[id] = (_cartQty[id] ?? 1) + 1),
                        child: Container(
                          width: 32, height: 32,
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, size: 16, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Submit
                GestureDetector(
                  onTap: isSubmitting ? null : () => _submitRequest(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSubmitting
                          ? Colors.grey.shade300
                          : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Submit',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Stock View (default, no search/filter) ─────────────────────────────────────
  Widget _buildStockContent() {
    if (_isLoading) return _buildShimmerList();

    final error = _activeTab == 'Tools' ? _toolsError : _productsError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Could not load items', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text(error, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  final load = _activeTab == 'Tools' ? _loadToolStocks() : _loadProductStocks();
                  load.then((_) { if (mounted) setState(() => _isLoading = false); });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final visibleItems = _items.where((item) {
      final qty = int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
      if (qty > 0) return true;
      return _allMovements.any((m) {
        if (m['approved_status'] != 'PENDING') return false;
        final isToolTab = _activeTab == 'Tools';
        final isMovementTool = m['tool'] != null || m['tools'] != null || m['tools_id'] != null;
        if (isToolTab != isMovementTool) return false;
        String mItemName = '';
        if (isMovementTool) {
          final toolData = m['tool'] ?? m['tools'];
          if (toolData is Map) mItemName = toolData['name'] ?? '';
          else if (m['tool_name'] != null) mItemName = m['tool_name'];
          else mItemName = toolData?.toString() ?? '';
        } else {
          mItemName = m['product'] is Map ? m['product']['name'] ?? '' : m['product'].toString();
        }
        return mItemName == item['name'];
      });
    }).toList();

    if (visibleItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No $_activeTab in stock', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Use the search bar to find and request items',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) => _buildStockCard(visibleItems[index]),
    );
  }

  // ── Stock Item Card ────────────────────────────────────────────────────────────
  Widget _buildStockCard(Map<String, dynamic> item) {
    final category = item['category'];
    String categoryName = 'Item';
    if (category is Map) categoryName = category['name'] ?? 'Item';
    else if (category != null) categoryName = category.toString();

    final isTool = _activeTab == 'Tools';
    final status = (item['status'] ?? 'Approved').toString();
    final isApproved = status.toLowerCase() == 'approved';
    final qty = item['qty'] ?? item['stock_balance'] ?? item['stock'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(isTool ? Icons.build_outlined : Icons.inventory_2_outlined,
                    size: 13, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  categoryName.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor, letterSpacing: 1.1),
                ),
                const Spacer(),
                if (!isApproved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: status.toLowerCase() == 'rejected'
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: status.toLowerCase() == 'rejected' ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown Item',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text('Current stock balance',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            qty.toString(),
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryColor, height: 1),
                          ),
                          Text('UNITS', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900,
                              color: AppTheme.textSecondary.withOpacity(0.7), letterSpacing: 1.4)),
                        ],
                      ),
                    ),
                    // Pending movements
                    ...(() {
                      final pending = _allMovements.where((m) {
                        if ((m['approved_status'] ?? 'PENDING') != 'PENDING') return false;
                        final isMovementTool = m['tool'] != null || m['tools'] != null;
                        if (isTool != isMovementTool) return false;
                        String mName = '';
                        if (isMovementTool) {
                          final td = m['tool'] ?? m['tools'];
                          if (td is Map) mName = td['name'] ?? '';
                          else if (m['tool_name'] != null) mName = m['tool_name'];
                        } else {
                          mName = m['product'] is Map ? m['product']['name'] ?? '' : m['product'].toString();
                        }
                        return mName == (item['name'] ?? '');
                      }).toList();
                      if (pending.isEmpty) return <Widget>[];
                      final total = pending.fold<int>(0, (s, m) => s + ((m['stock'] as num?)?.toInt() ?? 0));
                      return [
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_toggle_off, size: 10, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text('$total IN PROCESS',
                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.orange)),
                            ],
                          ),
                        ),
                      ];
                    })(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shimmer ────────────────────────────────────────────────────────────────────
  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1500),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(width: 70, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            ],
          ),
        ),
      ),
    );
  }
}
