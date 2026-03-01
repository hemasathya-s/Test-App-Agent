import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class RequestTrackingScreen extends StatelessWidget {
  const RequestTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for requests
    final requests = [
      {
        'id': 'REQ-789',
        'orderId': 'ORD-123',
        'customer': 'Jane Doe',
        'type': 'Order Modification',
        'status': 'Pending',
        'time': '10 mins ago',
        'items': 'Deep Cleaning (3h) x 1',
        'note': 'Customer requested additional deep cleaning for the kitchen.'
      },
      {
        'id': 'REQ-788',
        'orderId': 'ORD-120',
        'customer': 'John Smith',
        'type': 'Price Adjustment',
        'status': 'Approved',
        'time': '2 hours ago',
        'items': 'Furniture Polish x 2',
        'note': 'Material cost increased.'
      },
      {
        'id': 'REQ-785',
        'orderId': 'ORD-115',
        'customer': 'Alice Brown',
        'type': 'Order Modification',
        'status': 'Rejected',
        'time': 'Yesterday',
        'items': 'Kitchen Sink Unclogging',
        'note': 'Duplicate request.'
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Request History",
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(context, request);
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, String> request) {
    Color statusColor;
    IconData statusIcon;
    
    switch (request['status']) {
      case 'Approved':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Rejected':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.highlight_off;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['id']!,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request['type']!,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        request['status']!,
                        style: GoogleFonts.outfit(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.shopping_bag_outlined, 'Order: ${request['orderId']}'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.person_outline, 'Customer: ${request['customer']}'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.list_alt, request['items']!),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request['note']!,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request['time']!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (request['status'] == 'Pending')
                  Text(
                    'Waiting for Customer...',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
