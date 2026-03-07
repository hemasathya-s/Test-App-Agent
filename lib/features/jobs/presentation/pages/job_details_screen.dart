import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:urban_agent_app/core/services/Api service.dart';
import '../../../../Model/OrderDetails.dart';
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
        scrolledUnderElevation: 0,
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            color: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            offset: const Offset(0, 50),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'Hub service request') {
                _showHubServiceRequestSheet(context);
              } else if (value == 'Slot change request') {
                _showSlotChangeRequestSheet(context);
              } else if (value == 'Cancellations') {
                _showCancellationSheet(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$value selected'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryColor,
                    margin: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Hub service request',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Hub service request',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                ),
              ),
              PopupMenuItem(
                value: 'Slot change request',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Slot change request',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                ),
              ),
              PopupMenuItem(
                value: 'Cancellations',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Cancellations',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade600)),
                ),
              ),
            ],
          ),
        ],
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

  void _showHubServiceRequestSheet(BuildContext context) {
    final TextEditingController notesController = TextEditingController();
    final TextEditingController serialController = TextEditingController();
    final ImagePicker picker = ImagePicker();
    final ApiService apiService = ApiService();
    List<File> selectedImages = [];
    List<File> selectedVideos = [];
    bool isSubmitting = false;
    bool isLoadingOrder = true;
    OrderDetails? currentOrder;

    // Fetch orders to get real IDs
    void fetchOrderDetails(Function setSheetState) async {
      try {
        final orders = await ApiService.agentOrder();
        if (orders != null && orders.isNotEmpty) {
          // For now, take the first active order as simplified context
          currentOrder = orders.first;
        }
      } catch (e) {
        print('Error fetching orders: $e');
      } finally {
        setSheetState(() => isLoadingOrder = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (isLoadingOrder && currentOrder == null) {
            fetchOrderDetails(setSheetState);
          }
          
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      /*Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.hub_outlined, color: AppTheme.primaryColor),
                      ),*/
                      Text(
                        'Hub Service Request',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 10),
                const SizedBox(height: 12),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Images Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Images (${selectedImages.length}/3)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (selectedImages.length < 3)
                            GestureDetector(
                              onTap: () async {
                                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  setSheetState(() => selectedImages.add(File(image.path)));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo, size: 18, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Add',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                        ],
                      ),
                      if (selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: FileImage(selectedImages[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: -4,
                                    child: IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                      onPressed: () => setSheetState(() => selectedImages.removeAt(index)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Video Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Video (${selectedVideos.length}/1)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (selectedVideos.length < 1)
                            GestureDetector(
                              onTap:  () async {
                                final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
                                if (video != null) {
                                  setSheetState(() => selectedVideos.add(File(video.path)));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.videocam, size: 18, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Add',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                        ],
                      ),
                      if (selectedVideos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.movie_outlined, color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedVideos[0].path.split('/').last,
                                  style: GoogleFonts.outfit(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => setSheetState(() => selectedVideos.clear()),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      
                      // Serial Number Section
                      _buildLabel('Device Serial Number'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: serialController,
                        decoration: InputDecoration(
                          hintText: 'Enter serial number...',
                          fillColor: AppTheme.surfaceColor,
                          hintStyle: GoogleFonts.outfit(fontSize: 14),
                        ),
                        style: GoogleFonts.outfit(fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Notes Section
                      _buildLabel('Device Condition Notes'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter condition notes...',
                          fillColor: AppTheme.surfaceColor,
                          hintStyle: GoogleFonts.outfit(fontSize: 14),
                        ),
                        style: GoogleFonts.outfit(fontSize: 14),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),

                // Footer Actions
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting || (isLoadingOrder && currentOrder == null) 
                        ? null 
                        : () async {
                            setSheetState(() => isSubmitting = true);
                            
                            final orderId = currentOrder?.id ?? '00000000-0000-4000-a000-000000000000'; // Fallback to valid UUID format
                            final orderItemId = currentOrder?.items?.isNotEmpty == true ? currentOrder!.items!.first.id : null;

                            final response = await apiService.createHubServiceRequest(
                              orderId: orderId,
                              orderItemId: orderItemId,
                              deviceSerialNumber: serialController.text,
                              deviceConditionNotes: notesController.text,
                              images: selectedImages,
                              videos: selectedVideos,
                            );

                            if (context.mounted) {
                              setSheetState(() => isSubmitting = false);
                              if (response.isSuccess) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('✅ Hub Service Request submitted!'),
                                    backgroundColor: AppTheme.successColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ ${response.error}'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            }
                        },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isLoadingOrder && currentOrder == null ? 'Loading Order...' : 'Submit Request',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSlotChangeRequestSheet(BuildContext context) {
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String? selectedReason;
    final TextEditingController descriptionController = TextEditingController();
    bool isSubmitting = false;

    final reasons = [
      'AGENT_UNAVAILABLE',
      'CUSTOMER_REQUEST',
      'HEAVY_TRAFFIC',
      'VEHICLE_BREAKDOWN',
      'OTHER',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      /*Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.schedule_outlined, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 16),*/
                      Text(
                        'Slot Change Request',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Date Picker
                      _buildLabel('Requested Date'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) setSheetState(() => selectedDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month, color: AppTheme.textSecondary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                selectedDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(selectedDate!),
                                style: GoogleFonts.outfit(color: selectedDate == null ? AppTheme.textSecondary : AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Time Pickers
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Start Time'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                    if (time != null) setSheetState(() => startTime = time);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, color: AppTheme.textSecondary, size: 20),
                                        const SizedBox(width: 8),
                                        Text(startTime?.format(context) ?? '00:00', style: GoogleFonts.outfit(fontSize: 13)),
                                      ],
                                    ),
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
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                    if (time != null) setSheetState(() => endTime = time);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, color: AppTheme.textSecondary, size: 20),
                                        const SizedBox(width: 8),
                                        Text(endTime?.format(context) ?? '00:00', style: GoogleFonts.outfit(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Reason Selection
                      _buildLabel('Reason Type'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedReason,
                            hint: Text('Select reason type', style: GoogleFonts.outfit(fontSize: 14)),
                            isExpanded: true,
                            items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.outfit(fontSize: 14)))).toList(),
                            onChanged: (val) => setSheetState(() => selectedReason = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      _buildLabel('Reason Description'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter more details...',
                          fillColor: AppTheme.surfaceColor,
                          hintStyle: GoogleFonts.outfit(fontSize: 14),
                        ),
                        style: GoogleFonts.outfit(fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Footer Actions
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting || selectedDate == null || startTime == null || endTime == null || selectedReason == null
                          ? null
                          : () {
                              setSheetState(() => isSubmitting = true);
                              // Mock Request Payload
                              // final payload = {
                              //   "requested_date": DateFormat('yyyy-MM-dd').format(selectedDate!),
                              //   "requested_start_time": "${startTime!.hour}:${startTime!.minute}:00Z",
                              //   "requested_end_time": "${endTime!.hour}:${endTime!.minute}:00Z",
                              //   "slot_change_reason_type": selectedReason,
                              //   "slot_change_reason_description": descriptionController.text,
                              // };
                              Future.delayed(const Duration(seconds: 2), () {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ Slot Change Request submitted!'),
                                      backgroundColor: AppTheme.successColor,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Submit Slot Change', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCancellationSheet(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cancel_outlined, color: Colors.red),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Cancel Job',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildLabel('Cancellation Reason'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tell us why you need to cancel this job...',
                          fillColor: AppTheme.surfaceColor,
                          hintStyle: GoogleFonts.outfit(fontSize: 14),
                        ),
                        style: GoogleFonts.outfit(fontSize: 14),
                        onChanged: (val) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 24),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Note: Cancellations may be subject to approval or policy terms.',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Footer Actions
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting || reasonController.text.trim().isEmpty
                          ? null
                          : () {
                              setSheetState(() => isSubmitting = true);
                              
                              Future.delayed(const Duration(seconds: 2), () {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ Cancellation request submitted'),
                                      backgroundColor: AppTheme.successColor,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: Colors.red.withOpacity(0.3),
                      ),
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Confirm Cancellation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
    );
  }
}
