import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

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
    // Simulate approval delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Show success and pop back to job/home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes approved by customer!')),
        );
        context.go('/job-details'); // Back to valid flow
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const SizedBox(), // Disable back button to lock state
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

            // Disclaimer/Info
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
