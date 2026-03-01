import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_agent_app/core/model/slot_availability.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';

class JobDetailsScreen extends ConsumerWidget {
  final SlotAvailability? slot;
  final OrderDetails? order;

  const JobDetailsScreen({super.key, this.slot, this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(jobProvider.notifier);
    final effectiveOrder = order ?? slot?.orderDetails;
    
    final customerName = effectiveOrder?.customerName ?? 'Unknown Customer';
    final customerEmail = effectiveOrder?.userDetails?.email ?? '';
    final customerMobile = effectiveOrder?.customerNumber ?? '';
    final orderId = effectiveOrder?.id ?? slot?.orderId ?? 'N/A';
    final address = effectiveOrder?.address ?? 'No address provided';
    final items = effectiveOrder?.items ?? [];
    final totalPrice = effectiveOrder?.totalPrice ?? '0.00';
    
    // Use fields from OrderDetails/FullDetails if possible, else fallback to slot
    final date = slot?.date ?? (effectiveOrder?.createdAt?.split('T')[0]) ?? 'N/A';
    final timeSlot = slot != null 
        ? '${slot?.etaStartTime ?? ""} - ${slot?.etaEndTime ?? ""}'
        : 'Scheduled';

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'Job #$orderId',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        customerEmail,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
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
                      onPressed: () => _makePhoneCall(customerMobile),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.message,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () => _sendSMS(customerMobile),
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
                _buildSectionHeader('Job Details'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // List each item in the order
                      ...items.map((item) {
                        return Column(
                          children: [
                            _buildDetailRow(
                              Icons.build_circle_outlined,
                              'Service/Product',
                              '${item.itemDetails?.name ?? "Unknown"} (x${item.quantity ?? 1})',
                            ),
                            const Divider(height: 24),
                          ],
                        );
                      }).toList(),
                      
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date & Time',
                        '$date, $timeSlot',
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(
                        Icons.location_on,
                        'Address',
                        address,
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(
                        Icons.payments_outlined,
                        'Total Payout',
                        '₹ $totalPrice',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Status Info'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusItem('Order Status', order?.orderStatus ?? 'N/A'),
                      _buildStatusItem('Payment Status', order?.paymentStatus ?? 'N/A'),
                      _buildStatusItem('Approval', order?.agentApproval ?? 'N/A'),
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
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    controller.startNavigation();
                    context.push('/navigation');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(0, 56), // FIXED
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
              ),

              const SizedBox(width: 12),

              TextButton.icon(
                key: const Key('modify_order_btn'),
                icon: const Icon(Icons.edit_note, color: AppTheme.primaryColor),
                label: Text(
                  'Modify Order',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                onPressed: () => context.push('/modify-order'),
              ),
            ],
          ),
        ),
      )
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

  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}

