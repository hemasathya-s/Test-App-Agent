import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../../../Model/Product.dart';
import '../../../../Model/ToolStock.dart';
import '../../../../Model/ProductStock.dart';
import '../../../../Model/Tool.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';
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

  // ── Toggle ─────────────────────────────────────────────────────────────────
  String _activeTab = 'Tools'; // 'Tools' | 'Products'
  bool   _isLoading = true;
  String? _toolsError;
  String? _productsError;

  // For the Add-Item dialog dropdown
  List<Product> _apiProducts = [];
  List<Tool> _apiTools = [];

  // Temporary list to track movements for "In Process" badges
  List<Map<String, dynamic>> _allMovements = [];

  // ── Real stock data from API ───────────────────────────────────────────────
  final List<Map<String, dynamic>> _toolsItems = [];
  final List<Map<String, dynamic>> _productItems = [];

  // ── Shimmer animation ──────────────────────────────────────────────────────
  late AnimationController _shimmerController;
  late Animation<double>   _shimmerAnimation;

  List<Map<String, dynamic>> get _items =>
      _activeTab == 'Tools' ? _toolsItems : _productItems;

  List<String> get _dropdownOptions =>
      _activeTab == 'Tools'
          ? [] // tools stock dropdown not needed here; tools selected from product catalog
          : _apiProducts.map((p) => p.name).toList();

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
    // Listen to Product Movements
    _prodWsSub = _apiService.movementStream.listen((data) => _handleWsMessage(data));
    
    // Listen to Tool Movements
    _toolWsSub = _apiService.toolMovementStream.listen((data) => _handleWsMessage(data));
  }

  void _handleWsMessage(Map<String, dynamic> data) {
    print('📦 InventoryScreen: Received WS Data: $data');
    if (data['type'] == 'initial_data') {
      setState(() {
        final List movements = data['movements'] ?? [];
        for (var nm in movements) {
          final newId = (nm['id'] ?? nm['movement_id'] ?? '').toString();
          if (newId.isNotEmpty && !_allMovements.any((m) => (m['id'] ?? m['movement_id'] ?? '').toString() == newId)) {
            _allMovements.add(nm);
          }
        }
      });
    } else {
      final status = (data['approved_status'] ?? '').toString().toUpperCase();
      final mid = (data['id'] ?? data['movement_id'] ?? '').toString();
      
      if (status == 'APPROVED') {
        _loadInitialData(); // Refresh stock on approve
      }
      
      if (mid.isNotEmpty) {
        setState(() {
          bool found = false;
          for (var m in _allMovements) {
            final existingId = (m['id'] ?? m['movement_id'] ?? '').toString();
            if (existingId == mid) {
              m['approved_status'] = data['approved_status'];
              found = true;
            }
          }
          if (!found) {
            _allMovements.add(data);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _prodWsSub?.cancel();
    _toolWsSub?.cancel();
    _apiService.disposeWebSocket();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadToolStocks(),
      _loadProductStocks(),
      _loadProducts(), // for add-item dialog dropdown
      _loadToolsCatalog(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadToolsCatalog() async {
    final res = await _apiService.getTools();
    if (res.isSuccess && mounted) {
      print('📦 InventoryScreen: Fetched ${res.data?.length} tools');
      setState(() {
        _apiTools = res.data ?? [];
      });
    } else {
      print('❌ InventoryScreen: Failed to fetch tools: ${res.error}');
    }
  }

  Future<void> _loadToolStocks() async {
    print('📦 [INVENTORY DIAGNOSTICS] Loading Tool Stocks...');
    final res = await _apiService.getMyToolStocks(page: 1, size: 50); // Fetch more for safety
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      print('✅ [INVENTORY DIAGNOSTICS] Successfully loaded ${res.data?.length} tool stocks');
      setState(() {
        _toolsItems.clear();
        _toolsItems.addAll(res.data!.map((t) {
          final map = t.toItemMap();
          print('📦 [INVENTORY DIAGNOSTICS] Tool: ${map['name']}, Qty: ${map['qty']}');
          return map;
        }));
        _toolsError = null;
      });
    } else {
      print('❌ [INVENTORY DIAGNOSTICS] Failed to load tool stocks: ${res.error}');
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

  Future<void> _loadProducts() async {
    final response = await _apiService.getProducts();
    if (response.isSuccess && response.data != null && mounted) {
      print('📦 InventoryScreen: Fetched ${response.data?.length} products');
      setState(() => _apiProducts = response.data!);
    } else {
      print('❌ InventoryScreen: Failed to fetch products: ${response.error}');
    }
  }

  void _onTabSwitch(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _isLoading = true;
    });
    // Reload the relevant tab
    final load = tab == 'Tools' ? _loadToolStocks() : _loadProductStocks();
    load.then((_) { if (mounted) setState(() => _isLoading = false); });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'My Bag Stock',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
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
      body: Column(
        children: [
          // ── Sliding Toggle ─────────────────────────────────────────────
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
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: isActive
                              ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
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

          // ── List, Shimmer, Error, or Empty ────────────────────────────
          Expanded(
            child: _buildListContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: Text('Add Item', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Shimmer ────────────────────────────────────────────────────────────────
  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1500),
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 14,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 12,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(width: 80, height: 36,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
            ],
          ),
        ),
      ),
    );
  }

  // ── List Content Dispatcher ────────────────────────────────────────────────
  Widget _buildListContent() {
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
                  setState(() { _isLoading = true; });
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

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No $_activeTab in stock', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Tap "Add Item" to request stock', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return _buildItemList();
  }

  Widget _buildItemList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isTool = item['category'] == 'Tools';
        final status = item['status'] as String? ?? 'Approved';
        final isApproved = status == 'Approved';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Header Accent Bar ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTool ? Icons.build_outlined : Icons.inventory_2_outlined,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['category'].toString().toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    if (!isApproved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'Rejected'
                              ? Colors.red.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: status == 'Rejected' ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Content Area ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 12, color: AppTheme.textSecondary.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                'Current stock balance',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // ── Stock Badge & In Process Info ─────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item['qty'].toString(),
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'UNITS',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textSecondary.withOpacity(0.7),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Check for pending movements of this item
                        ...(() {
                          final pendingMovements = _allMovements.where((m) {
                            final mStatus = m['approved_status'] ?? 'PENDING';
                            if (mStatus != 'PENDING') return false;
                            
                            final isToolTab = _activeTab == 'Tools';
                            final isMovementTool = m['tool'] != null || m['tools'] != null || m['tools_id'] != null;
                            
                            if (isToolTab != isMovementTool) return false;
                            
                            String mItemName = '';
                            if (isMovementTool) {
                              final toolData = m['tool'] ?? m['tools'];
                              if (toolData is Map) {
                                mItemName = toolData['name'] ?? 'Unknown';
                              } else if (m['tool_name'] != null) {
                                mItemName = m['tool_name'];
                              } else {
                                mItemName = toolData?.toString() ?? 'Unknown';
                              }
                            } else {
                              mItemName = m['product'] is Map ? m['product']['name'] : m['product'].toString();
                            }
                            
                            return mItemName == item['name'];
                          }).toList();
                          
                          if (pendingMovements.isEmpty) return <Widget>[];
                          
                          final totalPending = pendingMovements.fold<int>(0, (sum, m) => sum + ((m['stock'] as num?)?.toInt() ?? 0));
                          
                          return [
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history_toggle_off, size: 10, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$totalPending IN PROCESS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange,
                                    ),
                                  ),
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
      },
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 16, color: AppTheme.textSecondary),
      ),
    );
  }

  void _showAddItemDialog() {
    String? selectedItemName;
    Tool? selectedTool;
    Product? selectedProduct;
    int quantity = 1;
    bool isRequesting = false;

    showDialog(
      context: context,
      barrierDismissible: !isRequesting,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Add to ${_activeTab == 'Tools' ? 'Bag' : 'Stock'}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text('Select Item',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField2<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                      hint: Text(
                        _activeTab == 'Tools' 
                            ? (_apiTools.isEmpty ? 'Loading tools...' : 'Choose a tool')
                            : (_apiProducts.isEmpty ? 'Loading products...' : 'Choose a product'),
                        style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade400),
                      ),
                      items: _activeTab == 'Tools'
                          ? { for (var t in _apiTools) t.name : t }.values.map((t) => DropdownMenuItem<String>(
                                value: t.name,
                                child: Text(t.name, style: GoogleFonts.outfit(fontSize: 14)),
                              )).toList()
                          : { for (var p in _apiProducts) p.name : p }.values.map((p) => DropdownMenuItem<String>(
                                value: p.name,
                                child: Text(p.name, style: GoogleFonts.outfit(fontSize: 14)),
                              )).toList(),
                      onChanged: (isRequesting || (_activeTab == 'Tools' ? _apiTools.isEmpty : _apiProducts.isEmpty))
? null
: (value) {
                              setDialogState(() {
                                selectedItemName = value;
                                if (_activeTab == 'Tools') {
                                  selectedTool = _apiTools.firstWhere((t) => t.name == value);
                                } else if (_activeTab == 'Products') {
                                  selectedProduct = _apiProducts.firstWhere((p) => p.name == value);
                                }
                              });
                            },
                      buttonStyleData: const ButtonStyleData(padding: EdgeInsets.only(right: 8)),
                      iconStyleData: const IconStyleData(
                        icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                        iconSize: 22,
                      ),
                      dropdownStyleData: DropdownStyleData(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white),
                        maxHeight: 250,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Quantity',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDialogQtyBtn(Icons.remove, isRequesting ? null : () {
                          if (quantity > 1) setDialogState(() => quantity--);
                        }),
                        const SizedBox(width: 12),
                        Container(
                          width: 50,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: AppTheme.surfaceColor,
                          ),
                          child: Text(quantity.toString(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        _buildDialogQtyBtn(Icons.add, isRequesting ? null : () => setDialogState(() => quantity++)),
                      ],
                    ),
                  ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isRequesting ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (selectedItemName == null || isRequesting)
                    ? null
                    : () async {
                        setDialogState(() => isRequesting = true);

                        bool success = false;
                        String? movementId;
                        String movementType = 'GET';

                            if (_activeTab == 'Products' && selectedProduct != null) {
                              final res = await _apiService.requestProductMovement(
                                productId: selectedProduct!.id,
                                stock: quantity,
                                type: movementType,
                              );
                              success = res.isSuccess;
                              movementId = res.data?.id;
                            } else if (_activeTab == 'Tools' && selectedTool != null) {
                              final res = await _apiService.requestToolMovement(
                                toolId: selectedTool!.id,
                                stock: quantity,
                                type: movementType,
                              );
                              success = res.isSuccess;
                              movementId = res.data?.id;
                            }

                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Movement request submitted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setDialogState(() => isRequesting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to submit request'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(120, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isRequesting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Add Item',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogQtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade100
              : AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 20,
            color: onTap == null ? Colors.grey : AppTheme.primaryColor),
      ),
    );
  }
}
