import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import 'agent_verification_screen.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final controller = ref.read(dashboardProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header & Availability
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(
                      Icons.menu,
                      size: 28,
                      color: AppTheme.textPrimary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, Udaya 👋',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Ready for new jobs?',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => GoRouter.of(context).push('/service-area'),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: state.isAvailable,
                      activeColor: AppTheme.successColor,
                      onChanged: (val) async {
                        if (val) {
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (ctx) => const AgentVerificationScreen(),
                            ),
                          );
                          if (result == true) {
                            controller.toggleAvailability(true);
                          }
                        } else {
                          // Ask for confirmation before turning off
                          final shouldTurnOff = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                'Go Offline?',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                'You won\'t receive any new job requests while offline.',
                                style: GoogleFonts.outfit(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(
                                    'Go Offline',
                                    style: GoogleFonts.outfit(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (shouldTurnOff == true) {
                            controller.toggleAvailability(false);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Earnings Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Earnings',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Target: \$200',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '\$124.50',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.work_history_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '4 Jobs Completed',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            'Upcoming Jobs',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Job Cards
          _buildJobCard(
            context,
            'Ac Repair & Service',
            'Today, 02:00 PM',
            '4521 Elm Street, Springfield',
            '\$85.00',
            true,
          ),
          _buildJobCard(
            context,
            'Washing Machine Fix',
            'Today, 04:30 PM',
            '882 Melvyn Avenue, Springfield',
            '\$65.00',
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    String title,
    String time,
    String address,
    String price,
    bool isUrgent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUrgent ? 'URGENT' : 'SCHEDULED',
                  style: GoogleFonts.outfit(
                    color: isUrgent ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                price,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: GoogleFonts.outfit(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              // Mock Navigation for flow test (In real app, trigger from notification or state)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Simulate receiving an offer by navigating to request screen
                    context.push('/job-request');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
