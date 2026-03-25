import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/apiservices.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/sos_bottom_sheet.dart';
import '../../../../core/model/order_details.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  @override
  void initState() {
    super.initState();
    // Initial data load
    Future.microtask(() => ref.read(dashboardProvider.notifier).fetchUpcomingJobs());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final controller = ref.read(dashboardProvider.notifier);

    // Show permission dialog when missing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.showPermissionDialog) {
        controller.dismissPermissionDialog(); // CLEAR IT IMMEDIATELY
        _showPermissionDialog(context, ref);
      }
      if (state.toggleError != null) {
        _showToggleErrorDialog(context, ref, state.toggleError!);
      }
    });

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).fetchUpcomingJobs(),
        color: AppTheme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Toggle
              _buildAvailabilityToggle(state, controller, context, ref),
              // Right: SOS, Notification, Profile
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => const SosBottomSheet(),
                      );
                    },
                    child: _buildHeaderIcon(Icons.sos),
                  ),
                  const SizedBox(width: 10),
                  //_buildNotificationIcon(),
                  GestureDetector(
                    onTap: () => context.push('/request-tracking'),
                    child: _buildNotificationIcon(),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      // Corrected navigation to the Profile page
                      context.push('/profile');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person_rounded, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Order Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
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
                    Text(
                      'Today\'s Overview',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${state.upcomingOrders.length} Orders',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Upcoming Jobs',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.upcomingOrders.where((o) => o.agentApproval?.toUpperCase() == "CONFIRMED").length} Confirmed  •  ${state.upcomingOrders.where((o) => o.agentApproval?.toUpperCase() == "PENDING").length} Pending',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            'Upcoming Jobs',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Job Cards
          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(dashboardProvider.notifier).fetchUpcomingJobs(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (state.upcomingOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 95),
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    (state.noOrdersMessage != null && state.noOrdersMessage!.isNotEmpty)
                        ? state.noOrdersMessage!
                        : 'No upcoming orders for today',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...state.upcomingOrders
                .where((order) =>
                    order.agentApproval?.toUpperCase() != 'REJECTED')
                .map((order) =>
                    _buildJobCard(order, context, ref, state.isAvailable)),
        ],
      ),
    ),
    );
  }

  void _showPermissionDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(dashboardProvider);
    final controller = ref.read(dashboardProvider.notifier);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Permissions Needed',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To receive new jobs and track your location properly, please enable:',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ...state.missingPermissions.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p == 'Location'
                            ? Icons.location_on
                            : p == 'Notification'
                              ? Icons.notifications_active
                              : Icons.battery_saver,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (p == 'Battery Optimization')
                              Text(
                                'Allows the app to run smoothly when the screen is off.',
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dismissPermissionDialog();
              Navigator.pop(ctx);
            },
            child: Text(
              'Later',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.requestPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Allow Now',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showToggleErrorDialog(
      BuildContext context, WidgetRef ref, String message) {
    final controller = ref.read(dashboardProvider.notifier);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Status Update Failed',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(color: AppTheme.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              controller.clearToggleError();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black, size: 22),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        _buildHeaderIcon(Icons.notifications_none_rounded),
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            width: 8,
            height: 8,
            // decoration: const BoxDecoration(
            //   color: Colors.red,
            //   shape: BoxShape.circle,
            // ),
          ),
        ),
      ],
    );
  }

  Widget   _buildAvailabilityToggle(
    DashboardState state,
    DashboardController controller,
    BuildContext context,
    WidgetRef ref,
  ) {
    return GestureDetector(
      onTap: state.isLoading ? null : () async {
        if (!state.isAvailable) {
          // GOING ONLINE
          await controller.toggleAvailability(true);
        } else {
          // GOING OFFLINE — show confirmation dialog first
          final shouldTurnOff = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Go Offline?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'You won\'t receive any new job requests while offline.',
                style: GoogleFonts.outfit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'Go Offline',
                    style: GoogleFonts.outfit(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (shouldTurnOff == true) {
            await controller.toggleAvailability(false);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        width: 110,
        height: 42,
        decoration: BoxDecoration(
          color: state.isAvailable ? AppTheme.successColor : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: (state.isAvailable ? AppTheme.successColor : Colors.grey)
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: state.isAvailable
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: state.isAvailable ? 0 : 36,
                right: state.isAvailable ? 36 : 0,
              ),
              child: Text(
                state.isAvailable ? 'Online' : 'Offline',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(
    OrderDetails order,
    BuildContext context,
    WidgetRef ref,
    bool isAgentOnline,
  ) {
    final title = (order.items != null && order.items!.isNotEmpty)
        ? (order.items!.first.itemDetails?.name ?? 'Unnamed Order')
        : 'Unnamed Order';
    final time = order.createdAt ?? '';
    final address = order.address ?? 'No Address Provided';
    final statusLabel = order.agentApproval?.toUpperCase() ?? 'PENDING';
print("Agent Status ${order.agentApproval?.toLowerCase()}");
    String? isUrgent = order.orderStatus?.toUpperCase();
    final isPending = statusLabel == 'PENDING';
    final isRejected = statusLabel == 'REJECTED';
    final isConfirmed = statusLabel == 'CONFIRMED';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isRejected
                      ? Colors.red.withOpacity(0.1)
                      : isConfirmed
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUrgent ?? '',
                  style: GoogleFonts.outfit(
                    color: isRejected
                        ? Colors.red
                        : isConfirmed
                            ? Colors.green
                            : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              // if (isUrgent)
              //   Container(
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              //     decoration: BoxDecoration(
              //       color: Colors.red.withOpacity(0.1),
              //       borderRadius: BorderRadius.circular(6),
              //     ),
              //     child: Text(
              //       'URGENT',
              //       style: GoogleFonts.outfit(
              //         color: Colors.red,
              //         fontWeight: FontWeight.bold,
              //         fontSize: 8,
              //       ),
              //     ),
              //   ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                time,
                style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action buttons based on approval status
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isAgentOnline ? () async {
                      if (order.id != null) {
                        final success = await ref
                            .read(dashboardProvider.notifier)
                            .acceptJob(order.id!);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Job accepted successfully')),
                          );
                        }
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Accept',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: isAgentOnline ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isAgentOnline ? () {
                      if (order.id != null) {
                        _showRejectBottomSheet(context, ref, order.id!);
                      }
                    } : null,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: isAgentOnline ? Colors.grey.shade300 : Colors.grey.shade200),
                    ),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.outfit(
                          color: isAgentOnline ? AppTheme.textSecondary : Colors.grey.shade400,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ) else if (isRejected)
            Expanded(
              child: ElevatedButton(
                onPressed: isAgentOnline ? () async {
                  if (order.id != null) {
                    final success = await ref
                        .read(dashboardProvider.notifier)
                        .acceptJob(order.id!);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Job accepted successfully')),
                      );
                    }
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Accept',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: isAgentOnline ? Colors.white : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else if (isConfirmed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push('/job-details', extra: order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F1F1),
                      foregroundColor: AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      'Job Details',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // context.push(
                      //   '/agent-tracking',
                      //   extra: {
                      //     'destination': LatLng(
                      //       order.latitude??0,
                      //       order.longitude??0,
                      //     ),
                      //     'customerName': order.customerName ?? 'Customer',
                      //     'customerPhone': order.customerNumber ?? '',
                      //     'orderId': order.id ?? '',
                      //   },
                      // );
                      context.push(
                        '/agent-tracking',
                        extra: order,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.primaryColor.withOpacity(0.1),
                      foregroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Map',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showAcceptBottomSheet(
      BuildContext context, WidgetRef ref, OrderDetails order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Job Details',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailItem(
                  Icons.work_outline, 'Order ID', order.id ?? 'N/A'),
              _buildDetailItem(Icons.calendar_today_outlined, 'Created At',
                  order.createdAt ?? 'N/A'),
              _buildDetailItem(Icons.location_on_outlined, 'Address',
                  order.address ?? 'N/A'),
              const SizedBox(height: 24),
              Text(
                'Order Items',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (order.items != null && order.items!.isNotEmpty)
                ...order.items!.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.itemDetails?.name ?? "Item"} x${item.quantity}',
                            style: GoogleFonts.outfit(
                                fontSize: 15, color: AppTheme.textPrimary),
                          ),
                        ),
                        Text(
                          '₹${item.price}',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'No items found',
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (order.id != null) {
                          _showRejectBottomSheet(context, ref, order.id!);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Reject',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (order.id != null) {
                          final success = await ref
                              .read(dashboardProvider.notifier)
                              .acceptJob(order.id!);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Job accepted successfully')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Accept',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectBottomSheet(
      BuildContext context, WidgetRef ref, String orderId) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isReasonValid = ValueNotifier<bool>(false);

    controller.addListener(() {
      isReasonValid.value = controller.text.trim().length >= 20;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Reject Job',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please provide a reason (min 20 characters) for rejecting this job.',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter rejection reason...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey),
                      suffix: ValueListenableBuilder<bool>(
                        valueListenable: isReasonValid,
                        builder: (context, isValid, child) {
                          final count = controller.text.trim().length;
                          return Text(
                            '$count/20 chars',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: isValid ? Colors.green : Colors.red,
                            ),
                          );
                        },
                      ),
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
                        borderSide:
                            const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 20) {
                        return 'Reason must be at least 20 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ValueListenableBuilder<bool>(
                    valueListenable: isReasonValid,
                    builder: (context, isValid, child) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isValid
                              ? () async {
                                  if (formKey.currentState!.validate()) {
                                    Navigator.pop(context);
                                    final success = await ref
                                        .read(dashboardProvider.notifier)
                                        .rejectJob(orderId, controller.text);
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Job rejected successfully')),
                                      );
                                    }
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirm Reject',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: isValid ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
