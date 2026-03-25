import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/model/order_details.dart';
import '../../../../core/model/slot_availability.dart';
import '../../../jobs/presentation/pages/job_details_screen.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderDetails> _allOrders = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      String? dateParam;
      if (_selectedDate != null) {
        dateParam = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }
      final orders = await ApiService.getAgentOrderHistory(startDate: dateParam);
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadOrders();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft01, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          // if (_selectedDate != null)
          //   IconButton(
          //     onPressed: () {
          //       setState(() {
          //         _selectedDate = null;
          //       });
          //       _loadOrders();
          //     },
          //     icon: const Icon(Icons.close, color: Colors.red),
          //     tooltip: 'Clear Filter',
          //   ),
          IconButton(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: GoogleFonts.outfit()),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                onRefresh:_loadOrders,
                child: Column(
                    children: [
                      if (_selectedDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOrdersList(isUpcoming: true),
                            _buildOrdersList(isUpcoming: false),
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
    );
  }

  Widget _buildOrdersList({required bool isUpcoming}) {
    final filteredOrders = _allOrders.where((order) {
      // Local date filtering for strict matching if date is selected
      if (_selectedDate != null && order.createdAt != null) {
        try {
          DateTime orderDate = DateTime.parse(order.createdAt!);
          if (orderDate.year != _selectedDate!.year ||
              orderDate.month != _selectedDate!.month ||
              orderDate.day != _selectedDate!.day) {
            return false;
          }
        } catch (_) {
          return false;
        }
      }

      final status = order.orderStatus?.toUpperCase() ?? '';
      final approvalStatus = order.agentApproval?.toUpperCase() ?? '';
      if (isUpcoming) {
        return status != 'COMPLETED' &&
            status != 'CANCELLED' &&
            status != 'DELIVERED' &&
            approvalStatus != 'REJECTED';
      } else {
        return status == 'COMPLETED' ||
            status == 'CANCELLED' ||
            status == 'DELIVERED';
      }
    }).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming orders' : 'No order history',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildOrderCard(context, order);
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderDetails order) {
    final String title = order.items != null && order.items!.isNotEmpty
        ? order.items![0].itemDetails?.name ?? 'Service'
        : 'Unknown Service';
    
    final String subtitle = order.items != null && order.items!.length > 1
        ? '${order.items!.length - 1} more items'
        : 'Order #${order.id?.substring(0, 8) ?? 'N/A'}';

    String timeStr = 'N/A';
    if (order.createdAt != null) {
      try {
        DateTime dt = DateTime.parse(order.createdAt!);
        timeStr = DateFormat('MMM d, hh:mm a').format(dt);
      } catch (_) {}
    }

    final String status = order.orderStatus ?? 'PENDING';
    final String price = '₹${order.totalPrice ?? '0.00'}';
    final String address = order.address ?? 'No address provided';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to JobDetailsScreen using go_router with extra parameter
          context.push(
            '/job-details',
            extra: SlotAvailability(
              id: order.id,
              orderId: order.id,
              orderDetails: order,
              status: order.orderStatus,
              date: timeStr,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    price,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 0.5),
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const Spacer(),
                  Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      address,
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    status = status.toUpperCase();
    switch (status) {
      case 'CONFIRMED':
      case 'ACCEPTED':
        return Colors.blue;
      case 'PENDING':
        return Colors.orange;
      case 'COMPLETED':
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

