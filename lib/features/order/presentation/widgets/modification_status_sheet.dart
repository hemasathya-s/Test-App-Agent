import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class ModificationStatusSheet extends StatelessWidget {
  final bool isApproved;
  final String message;

  const ModificationStatusSheet({
    super.key,
    required this.isApproved,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isApproved ? AppTheme.successColor : AppTheme.errorColor).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 48,
              color: isApproved ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isApproved ? 'Modification Approved!' : 'Modification Rejected',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproved ? AppTheme.successColor : AppTheme.textPrimary,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isApproved ? 'Continue Job' : 'Go Back',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),  // SafeArea
    );
  }
}
