import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(isUpcoming: true),
          _buildOrdersList(isUpcoming: false),
        ],
      ),
    );
  }

  Widget _buildOrdersList({required bool isUpcoming}) {
    // Mock Data
    final orders = isUpcoming
        ? [
            {
              'title': 'Ac Repair & Service',
              'time': 'Today, 02:00 PM',
              'address': '4521 Elm Street',
              'price': '\$85.00',
              'status': 'SCHEDULED',
            },
            {
              'title': 'Washing Machine Fix',
              'time': 'Today, 04:30 PM',
              'address': '882 Melvyn Avenue',
              'price': '\$65.00',
              'status': 'PENDING',
            },
          ]
        : [
            {
              'title': 'Sofa Cleaning',
              'time': 'Yesterday, 10:00 AM',
              'address': '123 Pine Road',
              'price': '\$45.00',
              'status': 'COMPLETED',
            },
            {
              'title': 'Kitchen Deep Clean',
              'time': 'Dec 28, 09:00 AM',
              'address': '776 Oak Lane',
              'price': '\$120.00',
              'status': 'COMPLETED',
            },
          ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(
          context,
          order['title'] as String,
          order['time'] as String,
          order['address'] as String,
          order['price'] as String,
          order['status'] as String,
          isUpcoming,
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String title,
    String time,
    String address,
    String price,
    String status,
    bool isUpcoming,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: GoogleFonts.outfit(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/job-details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SCHEDULED':
        return Colors.blue;
      case 'URGENT':
        return Colors.red;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
