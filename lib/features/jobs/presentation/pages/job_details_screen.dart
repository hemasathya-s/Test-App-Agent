import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_agent_app/core/model/slot_availability.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/service_modification.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';
import '../../../order/presentation/providers/order_modification_provider.dart';

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
    // Real service modifications from API
    final serviceModifications = effectiveOrder?.serviceModifications ?? [];

    // Latest modification (last in list)
    final latestMod = serviceModifications.isNotEmpty ? serviceModifications.last : null;

    // Legacy mock — kept so provider-based pending button still works
    final modificationState = ref.watch(orderModificationProvider);
    final latestModification = modificationState.requestHistory.isNotEmpty
        ? modificationState.requestHistory.firstWhere(
            (req) => req.orderId == 'ORD-123',
            orElse: () => RequestRecord(id: '', orderId: '', type: '', status: '', time: '', items: '', note: ''),
          )
        : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
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
                    // IconButton(
                    //   icon: const Icon(
                    //     Icons.message,
                    //     color: AppTheme.primaryColor,
                    //   ),
                    //   onPressed: () => _sendSMS(customerMobile),
                    // ),
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
                // 🔹 Real Modification Request Section (from API data)
                if (latestMod != null) ...[
                  _buildSectionHeader('Modification Request'),
                  _buildServiceModificationCard(context, latestMod),
                  const SizedBox(height: 24),
                ] else if (latestModification != null && latestModification.id.isNotEmpty) ...[
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
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      controller.startNavigation();
                      // PASS THE ORDER/SLOT DATA HERE
                      context.push('/navigation', extra: order ?? slot);
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
                  // Modify Order button — driven by real API serviceModifications
                  if (latestMod == null)
                    // No modification exists → show Modify Order button
                    TextButton.icon(
                      onPressed: () => context.push('/modify-order', extra: effectiveOrder),
                      icon: const Icon(Icons.edit_note, color: AppTheme.primaryColor),
                      label: Text(
                        'Modify Order',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  else if ((latestMod.status ?? '').toUpperCase() == 'PENDING')
                    // Modification pending → show waiting label, no tap
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_empty,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Waiting for Request Approval',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    )
                  // APPROVED / APPLIED / REJECTED → show nothing
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
    )  // Scaffold
    );  // PopScope
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

  Widget _buildServiceModificationCard(BuildContext context, ServiceModification mod) {
    final st = (mod.status ?? '').toUpperCase();
    final isFinal = st == 'APPLIED' || st == 'APPROVED' || st == 'REJECTED' || st == 'DECLINED';
    final isApproved = st == 'APPLIED' || st == 'APPROVED';

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_top;
    String statusLabel = 'Waiting for Approval';

    if (isFinal) {
      if (isApproved) {
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        statusLabel = 'Approved';
      } else {
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        statusLabel = 'Rejected';
      }
    }

    final originalName = mod.originalServiceName ?? 'Original Service';
    final newName = mod.newServiceName ?? 'New Service';
    final originalPrice = mod.originalPrice ?? '—';
    final newPrice = mod.newPrice ?? '—';
    final reason = mod.reason;
    final modId = (mod.id ?? '').length > 8
        ? '#${(mod.id ?? '').substring(0, 8).toUpperCase()}'
        : '#${mod.id ?? '—'}';

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
              if (isFinal)
                Row(
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: statusColor,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              Text(
                modId,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Text(
            'Requested Service',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    Text(
                      originalName,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₹ $originalPrice',
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'New',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    Text(
                      newName,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      '₹ $newPrice',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
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
          ],
        ],
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
}
