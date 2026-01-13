import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';

class JobDetailsScreen extends ConsumerWidget {
  const JobDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(jobProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
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
                      _buildDetailRow(Icons.attach_money, 'Payout', '\$85.00'),
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
              child: ElevatedButton.icon(
                onPressed: () {
                  controller.startNavigation();
                  context.push('/navigation');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                  ),
                ),
              ),
            ),
          ),
          TextButton.icon(
            key: const Key('modify_order_btn'), // For easier finding
            icon: const Icon(Icons.edit_note, color: AppTheme.primaryColor),
            label: Text(
              'Modify Order',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            onPressed: () => context.push('/modify-order'),
          ),
          const SizedBox(height: 12),
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
}
