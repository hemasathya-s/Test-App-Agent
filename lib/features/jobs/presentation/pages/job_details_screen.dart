import 'dart:io';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/services/apiservices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:urban_agent_app/core/model/slot_availability.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/service_modification.dart';
import 'package:urban_agent_app/core/model/order_item_modification.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/job_provider.dart';
import '../../../order/presentation/providers/order_modification_provider.dart' hide OrderItem;

class JobDetailsScreen extends ConsumerStatefulWidget {
  final SlotAvailability? slot;
  final OrderDetails? order;

  const JobDetailsScreen({super.key, this.slot, this.order});

  @override
  ConsumerState<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends ConsumerState<JobDetailsScreen> {
  OrderDetails? _fetchedOrder;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
    print("Order Id ${widget.order?.id}");
  }

  Future<void> _loadFullDetails() async {
    final orderId = widget.order?.id ?? widget.slot?.orderId;
    if (orderId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fullOrder = await ApiService.getOrderbyId(orderId);
      if (mounted) {
        setState(() {
          _fetchedOrder = fullOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load order details: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(jobProvider.notifier);
    final dashboardState = ref.watch(dashboardProvider);
    final isAgentActive = dashboardState.isAvailable;
   // final effectiveOrder = _fetchedOrder;
     final effectiveOrder = _fetchedOrder ?? widget.order ?? widget.slot?.orderDetails;
    final customerName = effectiveOrder?.customerName ?? 'Unknown Customer';
    final customerEmail = effectiveOrder?.userDetails?.email ?? '';
    final customerMobile = effectiveOrder?.customerNumber ?? '';
    final orderId = effectiveOrder?.id ?? widget.slot?.orderId ?? 'N/A';
    final address = effectiveOrder?.address ?? 'No address provided';
    final items = effectiveOrder?.items ?? [];
    final totalPrice = effectiveOrder?.totalPrice ?? '0.00';

    // Use fields from OrderDetails/FullDetails if possible, else fallback to slot
    final date = widget.slot?.date ?? (effectiveOrder?.createdAt?.split('T')[0]) ?? 'N/A';
    final timeSlot = widget.slot != null
        ? '${widget.slot?.etaStartTime ?? ""} - ${widget.slot?.etaEndTime ?? ""}'
        : (effectiveOrder?.slotTime is String ? effectiveOrder?.slotTime as String : 'Scheduled');

    final isInstant = effectiveOrder?.isInstantSlot ?? false;

    // Real service modifications from API (Old structure)
    final serviceModifications = effectiveOrder?.serviceModifications ?? [];
    final latestMod = serviceModifications.isNotEmpty ? serviceModifications.last : null;

    // New order item modifications (Bulk structure)
    final orderItemModifications = effectiveOrder?.orderItemModifications ?? [];
    final latestOrderItemMod = orderItemModifications.isNotEmpty ? orderItemModifications.last : null;

    // Legacy mock — kept so provider-based pending button still works
    // final modificationState = ref.watch(orderModificationProvider);
    // final latestModification = modificationState.requestHistory.isNotEmpty
    //     ? modificationState.requestHistory.firstWhere(
    //         (req) => req.orderId == 'ORD-123',
    //         orElse: () => RequestRecord(id: '', orderId: '', type: '', status: '', time: '', items: '', note: ''),
    //       )
    //     : null;

    // Define the body separately to avoid nested ternary type issues
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFullDetails,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
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
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Modification Request Section
                      if (latestOrderItemMod != null) ...[
                        _buildSectionHeader('Modification Request'),
                        _buildOrderItemModificationCard(context, latestOrderItemMod),
                        const SizedBox(height: 24),
                      ] else if (latestMod != null) ...[
                        _buildSectionHeader('Modification Request'),
                        _buildServiceModificationCard(context, latestMod),
                        const SizedBox(height: 24),
                      ]
                      // else if (latestModification != null && latestModification.id.isNotEmpty) ...[
                      //   _buildSectionHeader('Modification Request'),
                      //   _buildModificationStatusCard(context, latestModification),
                      //   const SizedBox(height: 24),
                      // ],
                      ,
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
                      const SizedBox(height: 15),
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
                            _buildStatusItem('Order ID', '#${effectiveOrder?.id?.substring(0, 8).toUpperCase() ?? 'N/A'}'),
                            _buildStatusItem('Order Status', effectiveOrder?.orderStatus ?? 'N/A', isStatus: true),
                            _buildStatusItem('Order Date', DateFormat('MMM d, yyyy, hh:mm a').format(DateTime.parse(effectiveOrder?.createdAt ?? DateTime.now().toString()))),
                            _buildStatusItem('Payment Status', effectiveOrder?.paymentStatus ?? 'N/A'),
                            _buildStatusItem('Approval', effectiveOrder?.agentApproval ?? 'N/A'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 35),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 35),
          // Action Bar
          if (effectiveOrder?.orderStatus?.toUpperCase() != 'COMPLETED' &&
              effectiveOrder?.orderStatus?.toUpperCase() != 'CANCELLED' &&
              effectiveOrder?.orderStatus?.toUpperCase() != 'DELIVERED')
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
                  // Get Directions button — only visible if NOT completed/cancelled
                  if (effectiveOrder?.orderStatus?.toUpperCase() != 'COMPLETED' && 
                      effectiveOrder?.orderStatus?.toUpperCase() != 'CANCELLED')
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (!isAgentActive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Your status is currently inactive. Please go online to proceed."),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      debugPrint('DEBUG: Get Directions button pressed');
                      controller.startNavigation();

                      if (effectiveOrder != null) {
                        await context.push('/navigation', extra: effectiveOrder);
                        _loadFullDetails();
                      } else if (widget.slot != null) {
                        await context.push('/navigation', extra: widget.slot);
                        _loadFullDetails();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAgentActive ? AppTheme.primaryColor : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.navigation, color: Colors.white),
                    label: Text(
                      'Get Directions',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Modify Order button — driven by real API serviceModifications
                  // if (latestOrderItemMod == null &&
                  //     effectiveOrder?.orderStatus?.toUpperCase() != 'COMPLETED' &&
                  //     effectiveOrder?.orderStatus?.toUpperCase() != 'CANCELLED' &&
                  //     effectiveOrder?.orderStatus?.toUpperCase() != 'CONFIRMED')
                    TextButton.icon(
                      onPressed: () async {
                        if (!isAgentActive) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Your status is currently inactive. Please go online to proceed."),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        await context.push('/modify-order', extra: effectiveOrder);
                        _loadFullDetails();
                      },
                      icon: Icon(Icons.edit_note, color: isAgentActive ? AppTheme.primaryColor : Colors.grey),
                      label: Text(
                        'Modify Order',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: isAgentActive ? AppTheme.primaryColor : Colors.grey,
                        ),
                      ),
                    )
                  // else if ((latestOrderItemMod?.status ?? '').toUpperCase() == 'PENDING')
                  // // Modification pending → show waiting label, no tap
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(vertical: 8),
                  //     child: Row(
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         const Icon(Icons.hourglass_empty,
                  //             size: 16, color: Colors.orange),
                  //         const SizedBox(width: 8),
                  //         Text(
                  //           'Waiting for Request Approval',
                  //           style: GoogleFonts.outfit(
                  //             fontWeight: FontWeight.bold,
                  //             color: Colors.orange,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   )
                  // // APPROVED / APPLIED / REJECTED ? show nothing
                  // else
                  //   const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      );
    }

print("Order ttt $orderId");
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
        actions: [
          if (effectiveOrder?.orderStatus?.toUpperCase() != 'COMPLETED' && 
              effectiveOrder?.orderStatus?.toUpperCase() != 'CANCELLED')
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            color: Colors.white,
            offset: const Offset(0, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (!isAgentActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Your status is currently inactive. Please go online to proceed."),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              print('🎯 Menu Selected: $value');
              final modifications = effectiveOrder?.serviceModifications ?? [];
              print('📦 Total Modifications: ${modifications.length}');
              for (var m in modifications) {
                print('🔹 Mod: Type="${m.modificationType}", Status="${m.status}"');
              }

              if (value == 'hub_service') {
                final hasHubRequest = modifications.any((m) {
                  final type = (m.modificationType ?? '').toUpperCase();
                  final status = (m.status ?? '').toUpperCase();
                  print('🔍 Checking Hub: Type=$type, Status=$status');
                  // Hub types might be HUB_SERVICE or just SERVICE or empty for legacy
                  final isHubType = type.contains('HUB') || type.contains('SERVICE') || type.isEmpty;
                  final isActive = status == 'PENDING' || status == 'APPROVED' || status == 'APPLIED' || status == 'REQUESTED';
                  return isHubType && isActive;
                });

                if (hasHubRequest) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('The request is already pending'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      )
                  );
                } else {
                  _showHubServiceRequestSheet(context, effectiveOrder);
                }
              } else if (value == 'slot_change') {
                final hasSlotRequest = modifications.any((m) {
                  final type = (m.modificationType ?? '').toUpperCase();
                  final status = (m.status ?? '').toUpperCase();
                  print('🔍 Checking Slot: Type=$type, Status=$status');
                  // Common slot types: SLOT_CHANGE, TIME_CHANGE, SERVICE_MODIFICATION
                  final isSlotType = type.contains('SLOT') || type.contains('TIME');
                  final isActive = status == 'PENDING' || status == 'APPROVED' || status == 'APPLIED' || status == 'REQUESTED';
                  return isSlotType && isActive;
                });

                if (hasSlotRequest) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A slot change request is already pending'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      )
                  );
                } else {
                  _showSlotChangeRequestSheet(context, effectiveOrder);
                }
              } else if (value == 'cancellation') {
                final hasCancelRequest = modifications.any((m) {
                  final type = (m.modificationType ?? '').toUpperCase();
                  final status = (m.status ?? '').toUpperCase();
                  print('🔍 Checking Cancel: Type=$type, Status=$status');
                  final isCancelType = type.contains('CANCEL') || type.contains('DELETE');
                  final isActive = status == 'PENDING' || status == 'APPROVED' || status == 'APPLIED' || status == 'REQUESTED';
                  return isCancelType && isActive;
                });

                if (hasCancelRequest) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A cancellation request is already pending'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      )
                  );
                } else {
                  _showCancellationSheet(context, effectiveOrder);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'hub_service',
                child: Text('Hub service', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
              ),
              PopupMenuItem(
                value: 'slot_change',
                child: Text('Slot change request', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
              ),
              PopupMenuItem(
                value: 'cancellation',
                child: Text('Cancellations', style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft01, color: Colors.black),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: body,
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

  /// Card for real ServiceModification data from the API
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

    // Get item info
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
          // Header: status badge + ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status badge — only visible for final states
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

          // Requested Service Section
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

          // Note / Reason (only if not null/empty)
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
                onPressed: () async {
                  await context.push('/approval-waiting');
                  _loadFullDetails();
                },
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

  /// Card for real OrderItemModification data from the API (Bulk)
  Widget _buildOrderItemModificationCard(BuildContext context, OrderItemModification mod) {
    final st = (mod.status ?? '').toUpperCase();
    final isFinal = mod.isApproved || mod.isRejected;
    final isApproved = mod.isApproved;

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

          // Modification Items
          ...(mod.modificationItems ?? []).map((item) => _buildModificationItemRow(item)).toList(),

          // Note / Reason
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

  Widget _buildModificationItemRow(ModificationItem item) {
    final type = (item.modificationType ?? '').toUpperCase();
    Color typeColor = Colors.blue;
    IconData typeIcon = Icons.edit_note;
    String typeLabel = type;

    if (item.isAdd) {
      typeColor = Colors.green;
      typeIcon = Icons.add_circle_outline;
      typeLabel = 'ADDED';
    } else if (item.isRemove) {
      typeColor = Colors.red;
      typeIcon = Icons.remove_circle_outline;
      typeLabel = 'REMOVED';
    } else if (item.isReplace) {
      typeColor = Colors.orange;
      typeIcon = Icons.swap_horiz;
      typeLabel = 'REPLACED';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, size: 14, color: typeColor),
              const SizedBox(width: 4),
              Text(
                typeLabel,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
              const Spacer(),
              Text(
                item.itemType ?? '',
                style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (item.isReplace)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.originalName ?? 'Original', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('₹ ${item.originalPrice ?? "—"}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(item.newName ?? 'New', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
                      Text('₹ ${item.newPrice ?? "—"}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor), textAlign: TextAlign.end),
                    ],
                  ),
                ),
              ],
            )
          else if (item.isAdd)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.newName ?? 'New Item', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('₹ ${item.newPrice ?? "—"} (x${item.quantity ?? 1})', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ],
            )
          else if (item.isRemove)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.originalName ?? 'Original Item', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.lineThrough)),
                Text('₹ ${item.originalPrice ?? "—"}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
              ],
            ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.5),
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

  Widget _buildStatusItem(String label, String value, {bool isStatus = false}) {
    // Replace underscores with spaces for cleaner UI
    final displayValue = value.replaceAll('_', ' ');
    final statusColor = isStatus ? _getStatusColor(value) : AppTheme.primaryColor;
    
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
              color: statusColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              displayValue,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
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
      case 'ARRIVED':
      case 'STARTED':
      case 'IN_PROGRESS':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }


  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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

  void _showHubServiceRequestSheet(BuildContext context, OrderDetails? order) {
    if (order == null) return;
    final idController = TextEditingController();
    final notesController = TextEditingController();
    List<File> selectedImages = [];
    List<File> selectedVideos = [];
    OrderItem? selectedItem;

    bool isSubmitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (stateContext, setState) {
        // Redundant check: if somehow opened while pending, close it
        final currentModifications = order?.serviceModifications ?? [];
        final alreadyHasHub = currentModifications.any((m) {
          final type = (m.modificationType ?? '').toUpperCase();
          final status = (m.status ?? '').toUpperCase();
          final isHubType = type.contains('HUB') || type.contains('SERVICE') || type.isEmpty;
          final isActive = status == 'PENDING' || status == 'APPROVED' || status == 'APPLIED' || status == 'REQUESTED';
          return isHubType && isActive;
        });

        if (alreadyHasHub) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
          });
          return const SizedBox.shrink();
        }

        return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(stateContext).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Text('Hub Service Request', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Submit a request for device repair or service at the hub.', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
                  const SizedBox(height: 15),
                  _buildLabel('Select Item *'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField2<OrderItem>(
                    isExpanded: true,
                    decoration: AppTheme.inputDecoration('Select an item', Icons.inventory_2_outlined, const EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
                    items: (order.items ?? []).map((item) => DropdownMenuItem<OrderItem>(
                      value: item,
                      child: Text(
                        item.itemDetails?.name ?? 'Unknown Item',
                        style: GoogleFonts.outfit(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (value) => setState(() => selectedItem = value),
                    buttonStyleData: const ButtonStyleData(padding: EdgeInsets.symmetric(horizontal: 12)),
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                      iconSize: 22,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Device Serial Number *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: idController,
                    onChanged: (_) => setState(() {}),
                    decoration: AppTheme.inputDecoration('Enter serial number', Icons.confirmation_number_outlined, const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Condition Notes *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 3,
                    decoration: AppTheme.inputDecoration('Describe device condition...', Icons.note_alt_outlined, const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Photos & Videos'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMediaButton(Icons.add_a_photo, 'Add Photo', () {
                        _showMediaSourceSheet(stateContext, isVideo: false, onPicked: (file) {
                          if (file != null) setState(() => selectedImages.add(file));
                        });
                      }),
                      const SizedBox(width: 12),
                      _buildMediaButton(Icons.video_call, 'Add Video', () {
                        _showMediaSourceSheet(stateContext, isVideo: true, onPicked: (file) {
                          if (file != null) setState(() => selectedVideos.add(file));
                        });
                      }),
                    ],
                  ),
                  if (selectedImages.isNotEmpty || selectedVideos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...selectedImages.map((f) => _buildMediaPreview(f, true, () => setState(() => selectedImages.remove(f)))),
                          ...selectedVideos.map((f) => _buildMediaPreview(f, false, () => setState(() => selectedVideos.remove(f)))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isSubmitting || selectedItem == null || idController.text.trim().isEmpty || notesController.text.trim().isEmpty) ? null : () async {
                        setState(() => isSubmitting = true);
                        try {
                          print('📡 Submitting Hub Service Request for item: ${selectedItem?.id}');
                          final res = await ApiService.createHubServiceRequest(
                            orderId: order.id ?? '',
                            orderItemId: selectedItem?.id,
                            deviceSerialNumber: idController.text,
                            deviceConditionNotes: notesController.text,
                            images: selectedImages,
                            videos: selectedVideos,
                          );
                          print('📡 Hub Request Result: ${res.isSuccess}, Error: ${res.error}');
                          
                          if (stateContext.mounted) {
                            final messenger = ScaffoldMessenger.of(context);
                            if (res.isSuccess) {
                              print('✅ Success - Popping Hub Sheet');
                              Navigator.pop(sheetContext);
                              final successMsg = res.data?['message'] ?? 'Request submitted successfully';
                              messenger.showSnackBar(SnackBar(
                                content: Text(successMsg, style: const TextStyle(color: Colors.white)),
                                backgroundColor: Colors.black87,
                              ));
                              _loadFullDetails();
                            } else {
                              print('⚠️ Error detected - Popping Hub Sheet');
                              Navigator.pop(sheetContext);
                              messenger.showSnackBar(SnackBar(
                                content: Text(res.error ?? 'Unknown error', style: const TextStyle(color: Colors.black87)),
                                backgroundColor: Colors.grey.shade300,
                              ));
                            }
                          }
                        } catch (e) {
                          print('❌ Exception in Hub Request: $e');
                          if (stateContext.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          if (stateContext.mounted) setState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Submit Request', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSlotChangeRequestSheet(BuildContext context, OrderDetails? order) {
    if (order == null) return;
    DateTime selectedDate = DateTime.now();
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;
    String? selectedSlotId;
    bool isLoadingSlots = false;
    String? slotCheckError;
    List<SlotAvailability> availableSlots = [];
    final reasonController = TextEditingController();
    final reasonTypeController = TextEditingController(text: 'AGENT_UNAVAILABLE');
    bool isSubmitting = false;

    // Zone related state
    List<SlotAvailability> availableZones = [];
    bool isLoadingZones = false;
    SlotAvailability? selectedZone;
    String? zoneError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (stateContext, setState) {
          // Redundant check: if somehow opened while pending, close it
          final currentModifications = order.serviceModifications ?? [];
          final alreadyHasSlot = currentModifications.any((m) {
            final type = (m.modificationType ?? '').toUpperCase();
            final status = (m.status ?? '').toUpperCase();
            final isSlotType = type.contains('SLOT') || type.contains('TIME');
            final isActive = status == 'PENDING' || status == 'APPROVED' || status == 'APPLIED' || status == 'REQUESTED';
            return isSlotType && isActive;
          });

          if (alreadyHasSlot) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
            });
            return const SizedBox.shrink();
          }

          void fetchZones() async {
            if (order.latitude == null || order.longitude == null) {
              print('⚠️ LAT/LNG missing for Zone fetch');
              return;
            }
            setState(() {
              isLoadingZones = true;
              zoneError = null;
            });
            print('📡 Fetching slots for Lat: ${order.latitude}, Lng: ${order.longitude}');
            final res = await ApiService().getAvailableSlotsByLocation(
              lat: order.latitude!,
              lng: order.longitude!,
            );
            if (stateContext.mounted) {
              setState(() {
                isLoadingZones = false;
                if (res.isSuccess) {
                  availableZones = res.data ?? [];
                  print('✅ Found ${availableZones.length} slots');
                } else {
                  zoneError = res.error;
                  print('❌ Zone fetch error: ${res.error}');
                }
              });
            }
          }

          if (availableZones.isEmpty && !isLoadingZones && zoneError == null) {
            fetchZones();
          }

          void updateTimeFromZone(SlotAvailability? zone) {
            if (zone == null) return;
            try {
              if (zone.etaStartTime != null) {
                final parts = zone.etaStartTime!.split(':');
                selectedStartTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
              }
              if (zone.etaEndTime != null) {
                final parts = zone.etaEndTime!.split(':');
                selectedEndTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
              }
            } catch (e) {
              print('❌ Error parsing zone times: $e');
            }
          }

          Future<void> fetchSlotsBackground() async {
            if (isLoadingSlots) return;
            setState(() {
              isLoadingSlots = true;
              slotCheckError = null;
            });
            try {
              final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
              final slots = await ApiService.getAgentSlotAvailability(dateStr);
              if (context.mounted) {
                setState(() {
                  availableSlots = slots;
                  isLoadingSlots = false;

                  if (slots.isNotEmpty && selectedStartTime == null) {
                    try {
                      if (slots.first.etaStartTime != null) {
                        final parts = slots.first.etaStartTime!.split(':');
                        selectedStartTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                      }
                      if (slots.first.etaEndTime != null) {
                        final parts = slots.first.etaEndTime!.split(':');
                        selectedEndTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                      }
                    } catch (_) {}
                  }
                });
              }
            } catch (e) {
              if (context.mounted) {
                setState(() {
                  isLoadingSlots = false;
                  slotCheckError = "Failed to check availability";
                });
              }
            }
          }

          void updateSelectedSlot() {
            if (selectedStartTime == null || selectedEndTime == null || availableSlots.isEmpty) return;
            final startMinutes = selectedStartTime!.hour * 60 + selectedStartTime!.minute;
            final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;
            String? foundSlotId;
            for (var slotAvail in availableSlots) {
              try {
                final sParts = slotAvail.etaStartTime!.split(':');
                final eParts = slotAvail.etaEndTime!.split(':');
                final sMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
                final eMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
                if (startMinutes >= sMin && endMinutes <= eMin) {
                  foundSlotId = slotAvail.slot;
                  break;
                }
              } catch (_) {}
            }
            if (foundSlotId != selectedSlotId) {
              setState(() => selectedSlotId = foundSlotId);
            }
          }

          if (availableSlots.isEmpty && !isLoadingSlots && slotCheckError == null) {
            fetchSlotsBackground();
          }

          // Only auto-update slot if user hasn't manually picked a zone from the location-based list
          if (selectedZone == null) {
            updateSelectedSlot();
          }

          // Find the current matched slot object for displaying times
          SlotAvailability? matchedSlot;
          if (selectedSlotId != null) {
            // Search in both standard slots and location-based slots
            matchedSlot = availableSlots.firstWhere(
              (s) => s.slot == selectedSlotId,
              orElse: () => availableZones.firstWhere(
                (z) => z.slot == selectedSlotId,
                orElse: () => SlotAvailability(),
              ),
            );
            if (matchedSlot?.slot == null) matchedSlot = null;
          }

          String formatTimeOfDay(TimeOfDay? tod) {
            if (tod == null) return '--:--';
            final hour = tod.hour.toString().padLeft(2, '0');
            final minute = tod.minute.toString().padLeft(2, '0');
            return '$hour:$minute';
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Text('Slot Change Request', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Request a different time for this job.', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
                  const SizedBox(height: 24),
                   _buildLabel('Select Slot (Based on Location) *'),
                   const SizedBox(height: 8),
                   if (isLoadingZones)
                     const Center(child: CircularProgressIndicator())
                   else if (zoneError != null)
                     Text('Error: $zoneError', style: GoogleFonts.outfit(color: Colors.red, fontSize: 13))
                   else if (availableZones.isEmpty)
                     Text('No slots found for this location.', style: GoogleFonts.outfit(color: Colors.orange, fontSize: 13))
                   else
                     DropdownButtonFormField<SlotAvailability>(
                       isExpanded: true,
                       value: selectedZone,
                       decoration: AppTheme.inputDecoration('Choose a slot', Icons.timer_outlined),
                       items: availableZones.map((z) => DropdownMenuItem(
                         value: z,
                         child: Row(
                           children: [
                             Text('${z.zoneName ?? "Slot"} (${z.etaStartTime ?? ""} - ${z.etaEndTime ?? ""})',
                               style: GoogleFonts.outfit(
                                 fontSize: 14,
                                 color: z.isAvailable == true ? Colors.green : null,
                                 fontWeight: z.isAvailable == true ? FontWeight.bold : null,
                               )),
                             if (z.isAvailable == true) ...[
                               const SizedBox(width: 8),
                               const Icon(Icons.check_circle, color: Colors.green, size: 16),
                             ],
                           ],
                         ),
                       )).toList(),
                       onChanged: (val) {
                         print('🎯 Selected Slot: ${val?.zoneName}');
                         print('🆔 Slot ID: ${val?.slot}');
                         print('⏰ Times: ${val?.etaStartTime} - ${val?.etaEndTime}');
                         setState(() {
                           selectedZone = val;
                           selectedSlotId = val?.slot;
                           updateTimeFromZone(val);
                         });
                       },
                     ),
                   const SizedBox(height: 16),
                   _buildLabel('Requested Date *'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary)),
                    trailing: const Icon(Icons.calendar_month, color: AppTheme.textSecondary),
                    onTap: null, // Temporarily disabled
                  ),
                  /*const Divider(),*/
                  const SizedBox(height: 6),
                  /*
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Start Time'),
                            InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedStartTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedStartTime = picked);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Text(formatTimeOfDay(selectedStartTime),
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: selectedStartTime != null ? Colors.black : Colors.grey)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('End Time'),
                            InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedEndTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedEndTime = picked);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Text(formatTimeOfDay(selectedEndTime),
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: selectedEndTime != null ? Colors.black : Colors.grey)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  */
                  const SizedBox(height: 6),
                  /*if (matchedSlot != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Available in slot: ${matchedSlot.etaStartTime} - ${matchedSlot.etaEndTime}',
                            style: GoogleFonts.outfit(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else if (!isLoadingSlots && availableSlots.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Times fall outside your available slots.',
                            style: GoogleFonts.outfit(color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),*/
                   _buildLabel('Reason Type *'),
                   const SizedBox(height: 8),
                    DropdownButtonFormField2<String>(
                      isExpanded: true,
                      decoration: AppTheme.inputDecoration('Select reason type', Icons.label_important_outline, const EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
                      items: const [
                        DropdownMenuItem(value: 'AGENT_UNAVAILABLE', child: Text('Agent Unavailable')),
                        DropdownMenuItem(value: 'RUNNING_LATE', child: Text('Running Late')),
                        DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency')),
                        DropdownMenuItem(value: 'VEHICLE_ISSUE', child: Text('Vehicle Issue')),
                        DropdownMenuItem(value: 'PERSONAL_REASON', child: Text('Personal Reason')),
                        DropdownMenuItem(value: 'OVERBOOKED', child: Text('Overbooked')),
                        DropdownMenuItem(value: 'ROUTE_CONFLICT', child: Text('Route Conflict')),
                        DropdownMenuItem(value: 'SERVICE_DELAY', child: Text('Service Delay')),
                        DropdownMenuItem(value: 'PARTS_DELAY', child: Text('Parts Delay')),
                        DropdownMenuItem(value: 'RESOURCE_UNAVAILABLE', child: Text('Resource Unavailable')),
                        DropdownMenuItem(value: 'TRAFFIC_DELAY', child: Text('Traffic Delay')),
                        DropdownMenuItem(value: 'WEATHER_ISSUE', child: Text('Weather Issue')),
                        DropdownMenuItem(value: 'LOCATION_ACCESS_ISSUE', child: Text('Location Access Issue')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => reasonTypeController.text = val ?? ''),
                      buttonStyleData: const ButtonStyleData(padding: EdgeInsets.symmetric(horizontal: 12)),
                      iconStyleData: const IconStyleData(
                        icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                        iconSize: 22,
                      ),
                      dropdownStyleData: DropdownStyleData(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildLabel('Reason Description'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: AppTheme.inputDecoration('Tell us why...', Icons.description_outlined),
                  ),
                  if (selectedSlotId == null && !isLoadingSlots)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Unable to find an available slot for this date. Please try another date.',
                        style: GoogleFonts.outfit(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: 15,),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isSubmitting || selectedStartTime == null || selectedEndTime == null || selectedSlotId == null || reasonTypeController.text.isEmpty)
                          ? null
                          : () async {
                              final currentId = order.slotId;
                              final originalDateStr = order.createdAt?.split('T')[0];
                              final isSameDate = originalDateStr != null && DateFormat('yyyy-MM-dd').format(selectedDate) == originalDateStr;

                              if (isSameDate && selectedSlotId == currentId) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Please select a different slot or date to request a change.',style: TextStyle(color: Colors.white),),
                                  backgroundColor: Colors.black87,
                                ));
                                return;
                              }

                              setState(() => isSubmitting = true);
                              final startStr = formatTimeOfDay(selectedStartTime);
                              final endStr = formatTimeOfDay(selectedEndTime);

                              final res = await ApiService.createSlotChangeRequest(
                                orderId: order.id ?? '',
                                orderItemId: order.items?.isNotEmpty == true ? order.items!.first.id : null,
                                currentSlotId: order.slotId,
                                requestedSlotId: selectedSlotId,
                                requestedDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                                requestedStartTime: '$startStr:00Z',
                                requestedEndTime: '$endStr:00Z',
                                reasonType: reasonTypeController.text,
                                reasonDescription: reasonController.text,
                              );
                              if (stateContext.mounted) {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => isSubmitting = false);
                                print('✅ Slot Request Success/Fail - Popping');
                                Navigator.pop(sheetContext);
                                final successMsg = res.data?['message'] ?? 'Slot change requested';
                                messenger.showSnackBar(SnackBar(
                                  content: Text(res.isSuccess ? successMsg : 'Error: ${res.error ?? "Unknown error"}', style: const TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.black87,
                                ));
                                if (res.isSuccess) {
                                  _loadFullDetails();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isLoadingSlots ? 'Checking availability...' : 'Submit Request',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  //{
  //   "success": true,
  //   "message": "Enums fetched successfully",
  //   "data": {
  //
  //     ],

    
  //   }
  // }   agent

  void _showCancellationSheet(BuildContext context, OrderDetails? order) {
    if (order == null) return;
    final reasonController = TextEditingController();
    String? cancellationReasonType;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (stateContext, setState) {
        // Redundant check: if somehow opened while pending, close it
        final currentModifications = order.serviceModifications ?? [];
        final alreadyHasCancel = currentModifications.any((m) {
          final type = (m.modificationType ?? '').toUpperCase();
          final status = (m.status ?? '').toUpperCase();
          final isCancelType = type.contains('CANCEL') || type.contains('DELETE');
          final isActive = status == 'PENDING' || status == 'APPROVED' || status == 'APPLIED' || status == 'REQUESTED';
          return isCancelType && isActive;
        });

        if (alreadyHasCancel) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
          });
          return const SizedBox.shrink();
        }

        return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(stateContext).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Text('Cancel Job', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                const SizedBox(height: 8),
                Text('Please provide a reason for canceling this job.', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
                const SizedBox(height: 24),
                _buildLabel('Cancellation Reason Type *'),
                const SizedBox(height: 8),
                DropdownButtonFormField2<String>(
                  isExpanded: true,
                  decoration: AppTheme.inputDecoration('Select reason type', Icons.cancel_outlined, const EdgeInsets.symmetric(horizontal: 0, vertical: 12)),
                  items: const [
                    DropdownMenuItem(value: 'CUSTOMER_CHANGE_OF_MIND', child: Text('Customer Change of Mind')),
                    DropdownMenuItem(value: 'AGENT_RUNNING_LATE', child: Text('Agent Running Late')),
                    DropdownMenuItem(value: 'WRONG_BOOKING', child: Text('Wrong Booking')),
                    DropdownMenuItem(value: 'AGENT_PERSONAL_EMERGENCY', child: Text('Agent Personal Emergency')),
                    DropdownMenuItem(value: 'SERVICE_NOT_AVAILABLE', child: Text('Service Not Available')),
                    DropdownMenuItem(value: 'SERVICE_DELAY', child: Text('Service Delay')),
                    DropdownMenuItem(value: 'CUSTOMER_NOT_AVAILABLE_AT_LOCATION', child: Text('Customer Not Available at Location')),
                    DropdownMenuItem(value: 'AGENT_UNABLE_TO_CONTACT_CUSTOMER', child: Text('Unable to Contact Customer')),
                    DropdownMenuItem(value: 'TECHNICAL_ISSUE', child: Text('Technical Issue')),
                    DropdownMenuItem(value: 'CUSTOMER_NOT_RESPONDING', child: Text('Customer Not Responding')),
                    DropdownMenuItem(value: 'AGENT_VEHICLE_ISSUE', child: Text('Agent Vehicle Issue')),
                    DropdownMenuItem(value: 'AGENT_UNAVAILABLE', child: Text('Agent Unavailable')),
                    DropdownMenuItem(value: 'OUT_OF_STOCK', child: Text('Out of Stock')),
                    DropdownMenuItem(value: 'ADDRESS_NOT_SERVICEABLE', child: Text('Address Not Serviceable')),
                    DropdownMenuItem(value: 'PRICE_DISPUTE', child: Text('Price Dispute')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (val) => setState(() => cancellationReasonType = val),
                  buttonStyleData: const ButtonStyleData(padding: EdgeInsets.symmetric(horizontal: 12)),
                  iconStyleData: const IconStyleData(
                    icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                    iconSize: 22,
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Cancellation Reason Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: AppTheme.inputDecoration('Why are you canceling?', Icons.cancel_presentation_outlined),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isSubmitting || cancellationReasonType == null)
                        ? null
                        : () async {
                            setState(() => isSubmitting = true);
                            final res = await ApiService.createCancellationRequest(
                              orderId: order.id ?? '',
                              orderItemId: order.items?.isNotEmpty == true ? order.items!.first.id : null,
                              cancellationReasonType: cancellationReasonType!,
                              reasonDescription: reasonController.text,
                            );
                            if (stateContext.mounted) {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => isSubmitting = false);
                              print('✅ Cancellation Success/Fail - Popping');
                                 Navigator.pop(sheetContext);
                              
                              final successMsg = res.data?['message'] ?? 'Job cancelled';
                              messenger.showSnackBar(SnackBar(
                                content: Text(res.isSuccess ? successMsg : 'Error: ${res.error ?? "Unknown error"}', style: const TextStyle(color: Colors.white)),
                                backgroundColor: Colors.black87,
                              ));
                              if (res.isSuccess) {
                                _loadFullDetails();
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('Confirm Cancellation',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: GoogleFonts.outfit(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(File file, bool isImage, VoidCallback onRemove) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: isImage ? Image.file(file, fit: BoxFit.cover) : const Center(child: Icon(Icons.videocam, color: Colors.grey)),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaSourceSheet(BuildContext context, {required bool isVideo, required Function(File?) onPicked}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVideo ? 'Select Video Source' : 'Select Photo Source',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    context,
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(context);
                      final picker = ImagePicker();
                      if (isVideo) {
                        final video = await picker.pickVideo(source: ImageSource.camera);
                        if (video != null) onPicked(File(video.path));
                      } else {
                        final image = await picker.pickImage(source: ImageSource.camera);
                        if (image != null) onPicked(File(image.path));
                      }
                    },
                  ),
                  _buildSourceOption(
                    context,
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      final picker = ImagePicker();
                      if (isVideo) {
                        final video = await picker.pickVideo(source: ImageSource.gallery);
                        if (video != null) onPicked(File(video.path));
                      } else {
                        final image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) onPicked(File(image.path));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}


