import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mock_map_widget.dart';

class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MockMapWidget(
            markers: [
              // Mock Job Marker
              Positioned(
                top: 150,
                left: 150,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                         color: Colors.white,
                         shape: BoxShape.circle,
                         boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.home_repair_service, color: AppTheme.primaryColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.white,
                      child: const Text('Job #123', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              // Mock Agent Marker
               Positioned(
                bottom: 300,
                right: 120,
                child: Column(
                  children: [
                     Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                         color: AppTheme.primaryColor,
                         shape: BoxShape.circle,
                         boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                    ),
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ],
          ),
          
          // Header Status
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: AppTheme.successColor, size: 12),
                        const SizedBox(width: 8),
                        Text(
                          'Online & Tracking',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: const Icon(Icons.gps_fixed, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          
          // Bottom Sheet info
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                children: [
                   Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.near_me, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                         'Heading to Job',
                         style: GoogleFonts.outfit(
                           fontWeight: FontWeight.bold,
                           fontSize: 16,
                         ),
                      ),
                      Text(
                         '4521 Elm Street • 2.4 km',
                         style: GoogleFonts.outfit(
                           color: AppTheme.textSecondary,
                           fontSize: 14,
                         ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
