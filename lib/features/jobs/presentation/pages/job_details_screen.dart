import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';
import '../../../order/presentation/providers/order_modification_provider.dart';

class JobDetailsScreen extends ConsumerWidget {
  const JobDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(jobProvider.notifier);
    final modificationState = ref.watch(orderModificationProvider);
    
    // Find the latest modification for this order (ORD-123 is hardcoded in mock)
    final latestModification = modificationState.requestHistory.isNotEmpty 
        ? modificationState.requestHistory.firstWhere((req) => req.orderId == 'ORD-123', orElse: () => RequestRecord(id: '', orderId: '', type: '', status: '', time: '', items: '', note: ''))
        : null;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'Job #12345',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Customer Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=5',
                  ), // Mock Image
                  backgroundColor: Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jane Doe',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '4.8 (12 jobs)',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.phone,
                        color: AppTheme.successColor,
                      ),
                      onPressed: () {}, // Mock Call
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.message,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () {}, // Mock Chat
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Job Info List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 🔹 New Modification Status Card (Only if a request exists)
                if (latestModification != null && latestModification.id.isNotEmpty) ...[
                  _buildSectionHeader('Modification Request'),
                  _buildModificationStatusCard(context, latestModification),
                  const SizedBox(height: 24),
                ],

                _buildSectionHeader('Job Details'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.cleaning_services,
                        'Service',
                        'Deep Cleaning (3h)',
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date & Time',
                        'Today, 02:30 PM',
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(
                        Icons.location_on,
                        'Address',
                        '4521 Elm Street, Apt 4B',
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(Icons.attach_money, 'Payout', '₹85.00'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Requirements'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCheckItem('Bring Vacuum Cleaner'),
                      _buildCheckItem('Wear Mask & Gloves'),
                      _buildCheckItem('Take Photos before start'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      controller.startNavigation();
                      context.push('/navigation');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.navigation, color: Colors.white),
                    label: Text(
                      'Get Directions',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Modify Order button logic: hide if pending
                  if (latestModification == null || latestModification.status != 'Pending')
                    TextButton.icon(
                      onPressed: () => context.push('/modify-order'),
                      icon: const Icon(Icons.edit_note, color: AppTheme.primaryColor),
                      label: Text(
                        'Modify Order',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Request Pending Approval',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildModificationStatusCard(BuildContext context, RequestRecord record) {
    Color statusColor;
    IconData statusIcon;
    
    switch (record.status) {
      case 'Approved':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_filled;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 20, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${record.status}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              Text(
                record.id,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Requested Items:',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            record.items,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          if (record.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: ${record.note}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (record.status == 'Pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/approval-waiting'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'View Waiting Status',
                  style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AppTheme.successColor,
          ),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.outfit(fontSize: 16)),
        ],
      ),
    );
  }
}
