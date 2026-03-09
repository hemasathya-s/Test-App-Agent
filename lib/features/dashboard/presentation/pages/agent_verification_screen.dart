import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

class AgentVerificationScreen extends StatefulWidget {
  const AgentVerificationScreen({super.key});

  @override
  State<AgentVerificationScreen> createState() =>
      _AgentVerificationScreenState();
}

class _AgentVerificationScreenState extends State<AgentVerificationScreen> {
  bool _isCapturing = false;

  void _takePhoto() async {
    setState(() {
      _isCapturing = true;
    });

    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Simulate success and return to previous screen with true
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  Text(
                    'Agent Verification',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance for close button
                ],
              ),
            ),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Position your face within the frame. Ensure your uniform is visible.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Camera Viewport (Mock)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Mock Camera Feed
                    Center(
                      child: Icon(
                        Icons.person_outline,
                        size: 100,
                        color: Colors.white12,
                      ),
                    ),

                    // Face Frame Guide
                    Center(
                      child: Container(
                        width: 200,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    if (_isCapturing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Controls
            Container(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isCapturing ? null : _takePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.transparent,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to Verify',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
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
