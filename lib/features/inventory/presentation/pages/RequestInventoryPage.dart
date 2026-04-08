import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:intl/intl.dart';
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
  DateTime _selectedDate = DateTime.now();
  Set<String> _toolDates = {};
  Set<String> _productDates = {};

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _connectWithDate(_selectedDate);
    _listenToWebSockets();
    _fetchRequestDates();
  }

  Future<void> _fetchRequestDates() async {
    try {
      final data = await ApiService.getRequestDates();
      if (mounted) {
        setState(() {
          _toolDates = Set<String>.from(data['tools'] ?? []);
          _productDates = Set<String>.from(data['products'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error fetching request dates: $e");
    }
  }

  void _connectWithDate(DateTime date) {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    _apiService.connectMovementWebSocket(startDate: dateStr, endDate: dateStr);
    _apiService.connectToolMovementWebSocket(startDate: dateStr, endDate: dateStr);
  }

  void _onDateChanged(DateTime newDate) {
    if (newDate.year == _selectedDate.year &&
        newDate.month == _selectedDate.month &&
        newDate.day == _selectedDate.day) return;

    setState(() {
      _selectedDate = newDate;
      _isLoading = true;
      _requestedItems.clear();
    });

    // Reset connections with new date
    _apiService.disconnectMovementWebSocket();
    _apiService.disconnectToolMovementWebSocket();
    
    _connectWithDate(newDate);
  }

  void _listenToWebSockets() {
    _isLoading = true;
    _requestedItems.clear(); // Clear initial local state
    
    // Listen to Product Movements
    _prodWsSub = _apiService.movementStream.listen((data) {
      _handleWsMessage(data, isToolStream: false);
    });
    
    // Listen to Tool Movements
    _toolWsSub = _apiService.toolMovementStream.listen((data) {
      _handleWsMessage(data, isToolStream: true);
    });

    // Fallback: stop shimmer if WS takes too long
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _handleWsMessage(Map<String, dynamic> data, {required bool isToolStream}) {
    final encoder = JsonEncoder.withIndent('  ');
    final prettyData = encoder.convert(data);
    if (data['type'] == 'initial_data') {
      final List movements = data['movements'] ?? data['results'] ?? data['data'] ?? [];
      setState(() {
        _isLoading = false;
        for (var m in movements) {
          _processSingleMovement(m, isToolStream: isToolStream);
        }
      });
      return;
    }

    // Live update
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
          'qty': _toInt(m['stock'] ?? m['quantity'] ?? m['current_stock'] ?? m['available_stock'] ?? 0),
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

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? (double.tryParse(value)?.toInt() ?? 0);
    return 0;
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

  void _showHighlightDatePicker() {
    DateTime viewedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final firstDayOfMonth = DateTime(viewedMonth.year, viewedMonth.month, 1);
              final lastDayOfMonth = DateTime(viewedMonth.year, viewedMonth.month + 1, 0);
              final daysInMonth = lastDayOfMonth.day;
              final startingWeekday = firstDayOfMonth.weekday; // 1 (Mon) - 7 (Sun)
              
              // Adjust for grid (Mon=1 ... Sun=7)
              final prevMonthLastDay = DateTime(viewedMonth.year, viewedMonth.month, 0).day;
              final prevMonthDaysToDisplay = (startingWeekday - 1) % 7;
          
              return Container(
                height: MediaQuery.of(context).size.height * 0.57,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(viewedMonth),
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () {
                                  setModalState(() {
                                    viewedMonth = DateTime(viewedMonth.year, viewedMonth.month - 1);
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () {
                                  setModalState(() {
                                    viewedMonth = DateTime(viewedMonth.year, viewedMonth.month + 1);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Weekdays
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => SizedBox(
                          width: 40,
                          child: Text(d, 
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Days Grid
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: 42, // Fix grid size
                        itemBuilder: (context, index) {
                          int dayNum = index - prevMonthDaysToDisplay + 1;
                          bool isCurrentMonth = dayNum > 0 && dayNum <= daysInMonth;
                          
                          if (!isCurrentMonth) return const SizedBox();
                          
                          final date = DateTime(viewedMonth.year, viewedMonth.month, dayNum);
                          final dateStr = DateFormat('yyyy-MM-dd').format(date);
                          final isSelected = isSameDay(date, _selectedDate);
                          final isToday = isSameDay(date, DateTime.now());
                          
                          // Highlighting logic
                          bool hasHighlight = false;
                          Color highlightColor = Colors.transparent;
                          
                          if (_activeTab == 'Tools') {
                            if (_toolDates.contains(dateStr)) {
                              hasHighlight = true;
                              highlightColor = AppTheme.primaryColor;
                            }
                          } else {
                            if (_productDates.contains(dateStr)) {
                              hasHighlight = true;
                              highlightColor = Colors.amber;
                            }
                          }
          
                          return GestureDetector(
                            onTap: () {
                              _onDateChanged(date);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isToday && !isSelected 
                                  ? Border.all(color: AppTheme.secondaryColor, width: 2) 
                                  : null,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    dayNum.toString(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (hasHighlight && !isSelected)
                                    Positioned(
                                      bottom: 6,
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: highlightColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Legend
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          _buildLegendItem(AppTheme.primaryColor, "Today", isBorder: true),
                          const SizedBox(width: 16),
                          if (_activeTab == 'Tools')
                             _buildLegendItem(AppTheme.primaryColor, "Tool Requests")
                          else
                             _buildLegendItem(Colors.amber, "Product Requests"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isBorder = false}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isBorder ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: isBorder ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: AppTheme.primaryColor),
            onPressed: () => _showHighlightDatePicker(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "${_selectedDate.day}/${_selectedDate.month}",
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
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
