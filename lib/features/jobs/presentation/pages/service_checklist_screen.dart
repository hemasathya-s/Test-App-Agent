import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/model/order_details.dart';
import '../../../../core/services/apiservices.dart';
import '../providers/job_provider.dart';

class ServiceChecklistScreen extends ConsumerStatefulWidget {
  final OrderDetails order;
  const ServiceChecklistScreen({super.key, required this.order});

  @override
  ConsumerState<ServiceChecklistScreen> createState() =>
      _ServiceChecklistScreenState();
}

class _ServiceChecklistScreenState
    extends ConsumerState<ServiceChecklistScreen> {
  final Map<String, bool> _tasks = {};
  bool _isLoading = false;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 🔹 PRINT FULL ORDER DETAILS ON INITIALIZATION
    debugPrint('DEBUG: FULL ORDER DETAILS JSON:');
    debugPrint(jsonEncode(widget.order.toJson()));
    
    _initializeChecklist();
  }

  void _initializeChecklist() {
    if (widget.order.items != null) {
      for (var item in widget.order.items!) {
        final taskName = item.itemDetails?.name ?? 'Unknown Service';
        _tasks[taskName] = false;
      }
    }
    // Fallback if no items
    if (_tasks.isEmpty) {
      _tasks['General Inspection'] = false;
    }
  }

  bool get _allCompleted => _tasks.values.every((v) => v);

  Future<void> _completeJob() async {
    final bool isOtpRequired = widget.order.isOtpRequired ?? false;
    debugPrint('DEBUG: Complete Job clicked. isOtpRequired: $isOtpRequired');

    if (isOtpRequired) {
      setState(() => _isLoading = true);
      // Trigger OTP generation/sending
      final success = await ApiService.updateJobStatus(widget.order.id!, 'COMPLETED');
      setState(() => _isLoading = false);

      if (success) {
        debugPrint('DEBUG: OTP triggered successfully. Showing dialog.');
        _showOtpDialog();
      } else {
        debugPrint('DEBUG: Failed to trigger OTP.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to request OTP. Please try again.'), backgroundColor: Colors.grey),
        );
      }
    } else {
      _processCompletion();
    }
  }

  void _showOtpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('OTP Required', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the 6-digit OTP provided by the customer.', style: GoogleFonts.outfit()),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: "",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_otpController.text.length == 6) {
                Navigator.pop(context);
                _processCompletion(otp: _otpController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 6-digit OTP')),
                );
              }
            },
            child: Text('Verify & Complete', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  Future<void> _processCompletion({String? otp}) async {
    setState(() => _isLoading = true);
    
    bool success;
    if (otp != null) {
      debugPrint('DEBUG: Verifying OTP: $otp');
      success = await ApiService.verifyOrderOtp(widget.order.id!, otp);
    } else {
      debugPrint('DEBUG: Completing job without OTP');
      success = await ApiService.updateJobStatus(widget.order.id!, 'COMPLETED');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        debugPrint('DEBUG: JOB COMPLETED SUCCESSFULLY');
        ref.read(jobProvider.notifier).completeJob();
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job Completed Successfully!'), backgroundColor: Colors.grey),
        );
      } else {
        if (otp != null) {
          print('otp failed'); // 🔹 Required print statement
          debugPrint('DEBUG: OTP VERIFICATION FAILED');
        } else {
          debugPrint('DEBUG: STATUS UPDATE FAILED');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete job. Check OTP or connection.'), backgroundColor: Colors.grey),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'Service Checklist',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Mark all services as done:',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._tasks.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
                    ),
                    child: CheckboxListTile(
                      value: entry.value,
                      activeColor: AppTheme.primaryColor,
                      title: Text(entry.key, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                      onChanged: (val) {
                        setState(() {
                          _tasks[entry.key] = val!;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _allCompleted ? _completeJob : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _allCompleted ? 'Complete Job' : 'Complete All Tasks',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
