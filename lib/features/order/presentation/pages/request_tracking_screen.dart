import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
            
            /* 
            // Sync selected date with server filters if available 
            // REMOVED: This causes the UI date to revert incorrectly when selecting a new date.
            if (data['filters'] != null && (data['filters']['date'] != null || data['filters']['start_date'] != null)) {
              final serverDateStr = data['filters']['date'] ?? data['filters']['start_date'];
              try {
                final serverDate = DateFormat('yyyy-MM-dd').parse(serverDateStr.toString());
                if (serverDate.year != _selectedDate.year || 
                    serverDate.month != _selectedDate.month || 
                    serverDate.day != _selectedDate.day) {
                  _selectedDate = serverDate;
                  debugPrint('🔄 Synchronized UI date with server: $_selectedDate');
                }
              } catch (e) {
                debugPrint('❌ Error parsing server filter date: $e');
              }
            }
            */
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
        scrolledUnderElevation:0,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
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
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[50],
              width: double.infinity,
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                          itemCount: _requests.length + (_latestRawResponse != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _requests.length) {
                              // return _buildDebugSection();
                              return null;
                            }
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

  /*Widget _buildDebugSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 40),
      child: Center(
        child: TextButton.icon(
          onPressed: () => _showRawDataSheet(),
          icon: const Icon(Icons.code, size: 16),
          label: Text('View Raw WebSocket Response', style: GoogleFonts.outfit(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
        ),
      ),
    );
  }*/

  void _showRawDataSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Raw WebSocket Data', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(_latestRawResponse),
                    style: GoogleFonts.firaCode(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
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
            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    final status = (request['status'] ?? 'PENDING').toString();
    final type = (request['request_type'] ?? request['type'] ?? 'GENERIC').toString();
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
      typeLabel = typeLabel[0].toUpperCase() + typeLabel.substring(1).toLowerCase();
    } else {
      typeLabel = 'Unknown';
    }

    String formattedUpdate = 'Recently';
    if (request['updated_at'] != null) {
      try {
        formattedUpdate = DateFormat('HH:mm').format(DateTime.parse(request['updated_at'].toString()));
      } catch (e) {
        formattedUpdate = 'Recently';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeLabel,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                _buildInfoRow(Icons.shopping_bag_outlined, 'Order ID: ${_truncateId(request['order_id']?.toString())}'),
                if (request['requested_date'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today, 'Requested: ${request['requested_date']}'),
                ],
                if (request['requested_start_time'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, 'Slot: ${request['requested_start_time']} - ${request['requested_end_time'] ?? ''}'),
                ],
                // Add Hub Service specific fields if present
                if (request['device_serial_number'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.qr_code, 'Serial: ${request['device_serial_number']}'),
                ],
                // Add Reason Description (Unified)
                if (reason != null && reason.toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reason:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          reason.toString(),
                          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
                if (request['device_condition_notes'] != null && request['device_condition_notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'Condition: ${request['device_condition_notes']}',
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.blue[800], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 0.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Updated: $formattedUpdate",
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
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
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
