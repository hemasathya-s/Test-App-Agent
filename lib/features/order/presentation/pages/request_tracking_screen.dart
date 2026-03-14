import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';

class RequestTrackingScreen extends StatefulWidget {
  const RequestTrackingScreen({super.key});

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  StreamSubscription? _subscription;
  Map<String, dynamic>? _latestRawResponse;
  final Map<String, bool> _updatingRequests = {};

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _apiService.connectRequestWebSocket(startDate: dateStr, endDate: dateStr);

    _subscription = _apiService.requestStream.listen((data) {
      debugPrint('📩 RequestTrackingScreen received: ${jsonEncode(data)}');
      if (mounted) {
        setState(() {
          if (data['type'] == 'initial_data' || data['type'] == 'update') {
            _requests = data['data'] ?? data['requests'] ?? [];
            _isLoading = false;
            _error = null;
          } else if (data['type'] == 'error') {
            _error = data['message'] ?? 'Unknown error from server';
            _isLoading = false;
          }
          _latestRawResponse = data;
        });
      }
    }, onError: (err) {
      debugPrint('❌ RequestTrackingScreen WebSocket error: $err');
      if (mounted) {
        setState(() {
          _error = "Connection error. Retrying...";
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _apiService.disconnectRequestWebSocket();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _apiService.disconnectRequestWebSocket();
      _connectWebSocket();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Request Tracking",
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  "Showing: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}",
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[50],
              width: double.infinity,
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          _apiService.disconnectRequestWebSocket();
                          _connectWebSocket();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final request = _requests[index];
                            return _buildRequestCard(context, request);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _truncateId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    if (id.length <= 6) return id;
    return id.substring(0, 6);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No requests found for this date",
            style: GoogleFonts.outfit(
                color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    final status = (request['status'] ?? 'PENDING').toString();
    final type =
        (request['request_type'] ?? request['type'] ?? 'GENERIC').toString();
    final reason = request['cancellation_reason_description'] ??
        request['slot_change_reason_description'] ??
        request['reason_description'];

    Color statusColor;
    IconData statusIcon;

    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'COMPLETED':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
      case 'CANCELLED':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.highlight_off;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
    }

    String typeLabel = type.replaceAll('_', ' ');
    if (typeLabel.isNotEmpty) {
      typeLabel =
          typeLabel[0].toUpperCase() + typeLabel.substring(1).toLowerCase();
    } else {
      typeLabel = 'Unknown';
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
              offset: const Offset(0, 4)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "#${_truncateId(request['id']?.toString())}",
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeLabel,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.outfit(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.shopping_bag_outlined,
                    'Order ID: ${_truncateId(request['order_id']?.toString())}'),
                if (request['requested_date'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today,
                      'Requested: ${request['requested_date']}'),
                ],
                if (request['requested_start_time'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time,
                      'Slot: ${request['requested_start_time']} - ${request['requested_end_time'] ?? ''}'),
                ],
                if (request['device_serial_number'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.qr_code,
                      'Serial: ${request['device_serial_number']}'),
                ],
                if (reason != null && reason.toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reason:',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          reason.toString(),
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
                if (request['device_condition_notes'] != null &&
                    request['device_condition_notes']
                        .toString()
                        .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'Condition: ${request['device_condition_notes']}',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.blue[800],
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                if (request['device_serial_number'] != null &&
                    (status.toUpperCase() == 'APPROVED' ||
                        status.toUpperCase() == 'COMPLETED')) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Hub Status: ${request['hub_status']?.toString().replaceAll('_', ' ').toUpperCase()}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (request['device_serial_number'] != null &&
              (status.toUpperCase() == 'APPROVED' ||
                  status.toUpperCase() == 'COMPLETED')) ...[
            const Divider(height: 0.5),
            _buildHubStatusDropdown(context, request),
          ],
        ],
      ),
    );
  }

  Widget _buildHubStatusDropdown(
      BuildContext context, Map<String, dynamic> request) {
    final requestId = request['id'].toString();
    final currentHubStatus =
        request['hub_status']?.toString().toUpperCase() ?? 'PENDING';
    final isUpdating = _updatingRequests[requestId] ?? false;

    final List<String> statusOrder = [
      'PENDING',
      'COLLECTED',
      'IN_TRANSIT_TO_HUB',
      'RECEIVED_AT_HUB',
      'UNDER_INSPECTION',
      'WAITING_FOR_PARTS',
      'REPAIR_IN_PROGRESS',
      'REPAIR_COMPLETED',
      'READY_FOR_DELIVERY',
      'OUT_FOR_DELIVERY',
      'DELIVERED',
    ];

    final int currentIndex = statusOrder.indexOf(currentHubStatus);

    final statuses = {
      'PENDING': 'Pending',
      'COLLECTED': 'Collected',
      'IN_TRANSIT_TO_HUB': 'In Transit to Hub',
      'RECEIVED_AT_HUB': 'Received at Hub',
      'UNDER_INSPECTION': 'Under Inspection',
      'WAITING_FOR_PARTS': 'Waiting for Parts',
      'REPAIR_IN_PROGRESS': 'Repair in Progress',
      'REPAIR_COMPLETED': 'Repair Completed',
      'READY_FOR_DELIVERY': 'Ready for Delivery',
      'OUT_FOR_DELIVERY': 'Out for Delivery',
      'DELIVERED': 'Delivered',
    };

    return DropdownButtonFormField2<String>(
      isExpanded: true,
      value: null,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.transparent, // Changed to transparent for footer look
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        border: InputBorder.none, // Removed border for footer look
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      hint: Text(
        'Update Status',
        style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
      ),
      items: statuses.entries.map((e) {
        final int itemIndex = statusOrder.indexOf(e.key);
        // Status is enabled/selectable only if it's AFTER the current status
        // Exception: keep 'DELIVERED' selectable if that's where verify OTP leads
        final bool isEnabled = itemIndex > currentIndex;

        return DropdownMenuItem<String>(
          value: e.key,
          enabled: isEnabled,
          child: Text(
            e.value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isEnabled ? Colors.black87 : Colors.grey[400],
            ),
          ),
        );
      }).toList(),
      onChanged: isUpdating
          ? null
          : (val) {
              if (val == null || val == currentHubStatus) return;
              _performStatusUpdate(requestId, request, val);
            },
      buttonStyleData:
          const ButtonStyleData(padding: EdgeInsets.only(right: 12)),
      iconStyleData: IconStyleData(
        icon: isUpdating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor))
            : Icon(HugeIcons.strokeRoundedArrowDown01, size: 16, color: Colors.grey[400]),
        iconSize: 22,
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 250,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
        offset: const Offset(0, -4),
        scrollbarTheme: ScrollbarThemeData(
          radius: const Radius.circular(40),
          thickness: WidgetStateProperty.all(6),
          thumbVisibility: WidgetStateProperty.all(true),
        ),
      ),
      menuItemStyleData: const MenuItemStyleData(
        padding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style:
                GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Future<void> _performStatusUpdate(
      String requestId, Map<String, dynamic> request, String val) async {
    if (val == 'DELIVERED') {
      setState(() {
        _updatingRequests[requestId] = true;
      });

      final res = await ApiService.updateHubServiceStatus(requestId, val);

      if (mounted) {
        setState(() => _updatingRequests[requestId] = false);
      }

      if (res.isSuccess) {
        if (mounted) {
          _showOtpDialog(context, requestId, request, () {
            if (mounted) {
              setState(() {
                request['hub_status'] = 'DELIVERED';
                request['status'] = 'COMPLETED';
              });
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(res.error ?? 'Failed to initiate delivery')),
          );
        }
      }
      return;
    }

    setState(() {
      _updatingRequests[requestId] = true;
      request['hub_status'] = val;
    });

    final res = await ApiService.updateHubServiceStatus(requestId, val);

    if (mounted) {
      setState(() => _updatingRequests[requestId] = false);
      if (!res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Failed to update status')),
        );
      }
    }
  }

  void _showOtpDialog(BuildContext context, String requestId,
      Map<String, dynamic> request, VoidCallback onSuccess) {
    print('🛠️ [OTP DIAGNOSTICS] Delivered clicked for Request ID: $requestId');

    final List<TextEditingController> controllers =
        List.generate(6, (index) => TextEditingController());
    final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());

    String? dialogError;
    bool isVerifying = false;
    bool showFeedback = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // ── Feedback screen (success / failure) ──────────────────────
            if (showFeedback) {
              return Dialog(
                backgroundColor: const Color(0xFF121212),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSuccess
                                ? Colors.green.withOpacity(0.5)
                                : Colors.red.withOpacity(0.5),
                            width: 4,
                          ),
                        ),
                        child: Icon(
                          isSuccess ? Icons.check : Icons.close,
                          size: 40,
                          color: isSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        isSuccess ? 'Successfully' : 'Verification Failed',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isSuccess
                            ? 'You have successfully verified'
                            : 'Invalid OTP. Please try again.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ── OTP input screen ──────────────────────────────────────────
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user_outlined,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Authentication',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the code from your\nCustomer App',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    // ── 6-digit OTP fields ──
                    Row(
                      children: List.generate(6, (index) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == 5 ? 0 : 6),
                            child: TextField(
                              controller: controllers[index],
                              focusNode: focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              maxLength: 1,
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppTheme.primaryColor, width: 2),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 5) {
                                  focusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  focusNodes[index - 1].requestFocus();
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    // ── Verify button ──
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isVerifying
                            ? null
                            : () async {
                                final String otp =
                                    controllers.map((c) => c.text).join();

                                if (otp.length < 6) {
                                  setDialogState(() => dialogError =
                                      'Please enter all 6 digits');
                                  return;
                                }

                                setDialogState(() {
                                  isVerifying = true;
                                  dialogError = null;
                                });

                                print(
                                    '📡 [OTP DIAGNOSTICS] Starting verification for ID: $requestId with OTP: $otp');

                                final res = await ApiService.verifyRequestOtp(
                                    requestId, otp);

                                print(
                                    '📡 [OTP DIAGNOSTICS] Result: ${res.isSuccess} | Error: ${res.error}');

                                // Use dialogContext.mounted — NOT the outer mounted
                                if (!dialogContext.mounted) return;

                                if (res.isSuccess) {
                                  setDialogState(() {
                                    isVerifying = false;
                                    isSuccess = true;
                                    showFeedback = true;
                                  });

                                  Future.delayed(const Duration(seconds: 3),
                                      () {
                                    if (dialogContext.mounted &&
                                        Navigator.canPop(dialogContext)) {
                                      Navigator.pop(dialogContext);
                                      onSuccess();
                                    }
                                  });
                                } else {
                                  setDialogState(() {
                                    isVerifying = false;
                                    isSuccess = false;
                                    showFeedback = true;
                                  });

                                  Future.delayed(const Duration(seconds: 3),
                                      () {
                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        showFeedback = false;
                                        for (var c in controllers) {
                                          c.clear();
                                        }
                                        focusNodes[0].requestFocus();
                                      });
                                    }
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                'Verify OTP',
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style:
                            GoogleFonts.outfit(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
