import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/modification_status_sheet.dart';

class ApprovalWaitingScreen extends ConsumerStatefulWidget {
  const ApprovalWaitingScreen({super.key});

  @override
  ConsumerState<ApprovalWaitingScreen> createState() =>
      _ApprovalWaitingScreenState();
}

class _ApprovalWaitingScreenState extends ConsumerState<ApprovalWaitingScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('TEST LOG: ApprovalWaitingScreen initialized. Timer starting...');
    
    // Simulate approval delay (4 seconds)
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        debugPrint('TEST LOG: Timer finished. Triggering approval simulation.');
        _onStatusReceived(true); // Simulate Approval for demo
      }
    });
  }

  void _onStatusReceived(bool approved) {
    debugPrint('TEST LOG: Processing status receipt. Approved: $approved');
    
    // 1. Pop the waiting screen
    context.pop();

    // 2. Show the Status Bottom Sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModificationStatusSheet(
        isApproved: approved,
        message: approved
            ? "The customer has agreed to the new items and prices. You can now proceed with the service."
            : "The customer declined the changes. Please stick to the original order requirements.",
      ),
    ).then((_) {
      debugPrint('TEST LOG: Status sheet dismissed. Navigating back to Job Details.');
      // 3. After the sheet is dismissed, navigate back
      context.go('/job-details');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            debugPrint('TEST LOG: Agent manually closed waiting screen.');
            context.pop();
          },
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Waiting for Approval',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We have sent your request to Sarah.\nPlease wait while they review the changes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Do not start the additional work until approved.',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
