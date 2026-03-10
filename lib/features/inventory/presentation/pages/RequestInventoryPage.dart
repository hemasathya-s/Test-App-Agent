import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';

class RequestInventoryPage extends StatefulWidget {
  const RequestInventoryPage({super.key});

  @override
  State<RequestInventoryPage> createState() => _RequestInventoryPageState();
}

class _RequestInventoryPageState extends State<RequestInventoryPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  StreamSubscription? _prodWsSub;
  StreamSubscription? _toolWsSub;

  bool _isLoading = true;
  String _activeTab = 'Tools'; // 'Tools' | 'Products'
  final List<Map<String, dynamic>> _requestedItems = [];

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _apiService.connectMovementWebSocket();
    _apiService.connectToolMovementWebSocket();
    _listenToWebSockets();
  }

  void _listenToWebSockets() {
    _isLoading = true;
    _requestedItems.clear(); // Clear initial local state
    
    // Listen to Product Movements
    _prodWsSub = _apiService.movementStream.listen((data) {
      print('📦 RequestPage: Received Product WS Data');
      _handleWsMessage(data, isToolStream: false);
    });
    
    // Listen to Tool Movements
    _toolWsSub = _apiService.toolMovementStream.listen((data) {
      print('📦 RequestPage: Received Tool WS Data');
      _handleWsMessage(data, isToolStream: true);
    });

    // Fallback: stop shimmer if WS takes too long
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        print('⏱️ RequestPage: WS Timeout fallback');
        setState(() => _isLoading = false);
      }
    });
  }

  void _handleWsMessage(Map<String, dynamic> data, {required bool isToolStream}) {
    final encoder = JsonEncoder.withIndent('  ');
    final prettyData = encoder.convert(data);
    print('📦 RequestPage: Received Data (${isToolStream ? "Tools" : "Products"}):\n$prettyData');
    if (data['type'] == 'initial_data') {
      final List movements = data['movements'] ?? [];
      print('📦 RequestPage: Processing ${movements.length} initial items');
      setState(() {
        _isLoading = false;
        for (var m in movements) {
          _processSingleMovement(m, isToolStream: isToolStream);
        }
      });
      return;
    }

    // Live update
    print('📦 RequestPage: Processing live update (${isToolStream ? "Tools" : "Products"})');
    _processSingleMovement(data, isToolStream: isToolStream);
  }

  void _processSingleMovement(Map<String, dynamic> m, {required bool isToolStream}) {
    final movementId = (m['id'] ?? m['movement_id'] ?? '').toString();
    final String? status = m['approved_status'];
    
    if (movementId.isEmpty) return;

    setState(() {
      int existingIdx = _requestedItems.indexWhere((item) => item['movement_id'].toString() == movementId);
      
      if (existingIdx != -1) {
        // Update existing status if status is provided in message
        if (status != null) {
          _requestedItems[existingIdx]['status'] = _formatStatus(status);
        }
      } else {
        // Add new item
        final bool isTool = isToolStream || m['tool'] != null || m['tools'] != null || m['tools_id'] != null;
        
        String itemName = 'Unknown';
        if (isTool) {
          final toolData = m['tool'] ?? m['tools'];
          if (toolData is Map) {
            itemName = toolData['name'] ?? 'Unknown';
          } else if (m['tool_name'] != null) {
            itemName = m['tool_name'];
          } else if (m['tools_id'] != null) {
            final tid = m['tools_id'].toString();
            itemName = 'Tool ${tid.length > 6 ? tid.substring(0, 6) : tid}';
          } else {
            itemName = toolData?.toString() ?? 'Unknown';
          }
        } else {
          if (m['product'] is Map) {
            itemName = m['product']['name'] ?? 'Unknown';
          } else if (m['product'] is String) {
            itemName = m['product'];
          }
        }

        String agentName = '';
        if (m['agent'] is Map) {
          agentName = m['agent']['user_name'] ?? m['agent']['user_details']?['name'] ?? '';
        } else if (m['agent'] is String) {
          agentName = m['agent'];
        }

        String timestamp = '';
        // Prioritize movement's own timestamps
        timestamp = (m['created_at'] ?? m['timestamp'] ?? '').toString();
        
        if (timestamp.isEmpty && m['agent'] is Map) {
          final agentMap = m['agent'] as Map;
          if (agentMap['user_details'] is Map) {
            timestamp = (agentMap['user_details']['date_joined'] ?? '').toString();
          }
          if (timestamp.isEmpty) {
            timestamp = (agentMap['date_joined'] ?? '').toString();
          }
        }
        
        if (timestamp.isEmpty) {
          timestamp = DateTime.now().toIso8601String();
        }

        final newItem = {
          'movement_id': movementId,
          'name': itemName,
          'qty': m['stock'] ?? 0,
          'type': (m['type'] ?? 'GET').toString().toUpperCase(),
          'status': _formatStatus(status ?? 'PENDING'),
          'agent': agentName,
          'category': isTool ? 'Tools' : 'Products',
          'created_at': timestamp,
        };

        _requestedItems.insert(0, newItem);
      }

      // Sort by date (newest first)
      _requestedItems.sort((a, b) {
        try {
          DateTime dtA = DateTime.parse(a['created_at']);
          DateTime dtB = DateTime.parse(b['created_at']);
          return dtB.compareTo(dtA);
        } catch (e) {
          return 0;
        }
      });
    });
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Pending';
    final upper = status.toUpperCase();
    if (upper == 'PENDING') return 'In Process';
    return upper[0] + upper.substring(1).toLowerCase();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _prodWsSub?.cancel();
    _toolWsSub?.cancel();
    _apiService.disposeWebSocket();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'My Requests',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Sliding Tab Toggle ────────────────────────────────────────
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
                      onTap: () => setState(() => _activeTab = tab),
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

          // ── Filtered List or Shimmer ──────────────────────────────────
          Expanded(
            child: _isLoading ? _buildShimmerList() : _buildRequestList(),
          ),
        ],
      ),
    );
  }

  // ── Request List ─────────────────────────────────────────────────────────
  Widget _buildRequestList() {
    final filtered = _requestedItems
        .where((item) => item['category'] == _activeTab)
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No $_activeTab requests yet',
                style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Use "Add Item" on the Inventory screen to submit a $_activeTab request',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final status = item['status'] as String;
        final isApproved = status == 'Approved';
        final isRejected = status == 'Rejected';
        final movementId = (item['movement_id'] ?? '').toString();
        final shortId = movementId.length > 5 ? movementId.substring(0, 5).toUpperCase() : movementId.toUpperCase();
        final agentName = (item['agent'] ?? '').toString();
        final itemType = (item['type'] ?? 'GET').toString();
        final createdAt = (item['created_at'] ?? '').toString();

        // Format time
        String timeStr = 'N/A';
        try {
          if (createdAt.isNotEmpty) {
            final dt = DateTime.parse(createdAt).toLocal();
            final period = dt.hour >= 12 ? 'PM' : 'AM';
            final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final h = hour12.toString().padLeft(2, '0');
            final m = dt.minute.toString().padLeft(2, '0');
            final d = dt.day.toString().padLeft(2, '0');
            final mo = dt.month.toString().padLeft(2, '0');
            timeStr = '$d/$mo  $h:$m $period';
          }
        } catch (e) {
          print('❌ Error parsing date $createdAt: $e');
        }

        final statusColor = isApproved
            ? Colors.green
            : isRejected
                ? Colors.red
                : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Header bar ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.07),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Text(
                      'ID: #$shortId',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status,
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _trackRow(
                      Icons.inventory_2_outlined,
                      'Item',
                      '${item['name']}',
                    ),
                    const SizedBox(height: 10),
                    _trackRow(
                      Icons.numbers_outlined,
                      'Quantity',
                      '${item['qty']} units',
                    ),
                    const SizedBox(height: 10),
                    _trackRow(
                      Icons.schedule_outlined,
                      'Requested On',
                      timeStr,
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

  Widget _trackRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.outfit(
              fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


  // ── Shimmer ──────────────────────────────────────────────────────────────
  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1500),
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                      height: 14,
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(6))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
