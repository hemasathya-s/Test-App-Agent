import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  // Mock document states
  Map<String, bool> documents = {
    'Identity Proof (Aadhaar/ID)': false,
    'PAN Card / Tax ID': false,
    'Police Verification': false,
  };

  bool get _allUploaded => documents.values.every((uploaded) => uploaded);
  bool _isVerified = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'Account Verification',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 32),
              Text(
                'Required Documents',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: documents.entries.map((entry) {
                    return _buildDocumentItem(entry.key, entry.value);
                  }).toList(),
                ),
              ),
              if (_allUploaded && !_isVerified)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Verification in progress. Approx time: 24 hrs.',
                          style: GoogleFonts.outfit(
                            color: Colors.blue[800],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _allUploaded
                    ? () {
                        // Navigate to Dashboard
                        if (_isVerified) {
                           context.go('/home');
                        } else {
                           // Mock admin verify
                           setState(() {
                             _isVerified = true;
                           });
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isVerified ? AppTheme.successColor : AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(_isVerified ? 'Go to Dashboard' : _allUploaded ? 'Check Status' : 'Upload All to Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isVerified ? AppTheme.successColor : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isVerified ? Icons.check_circle_outline : Icons.pending_actions_rounded,
              size: 48,
              color: _isVerified ? Colors.white : Colors.orange[800],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isVerified ? 'Verified Agent' : 'Verification Pending',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isVerified ? Colors.white : Colors.orange[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isVerified
                ? 'You are ready to accept jobs!'
                : 'Upload documents to activate your account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: _isVerified ? Colors.white.withOpacity(0.9) : Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(String title, bool isUploaded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUploaded ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUploaded ? Icons.check : Icons.upload_file_rounded,
              color: isUploaded ? Colors.green : Colors.grey[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isUploaded ? AppTheme.textPrimary : AppTheme.textPrimary,
                decoration: isUploaded ? null : null,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                documents[title] = !documents[title]!; // Toggle for mock
              });
            },
            child: Text(
              isUploaded ? 'View' : 'Upload',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: isUploaded ? AppTheme.primaryColor : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
