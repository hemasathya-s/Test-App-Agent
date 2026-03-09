import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=11',
                  ),
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Udaya Agent',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'ID: AGT-8821',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildDrawerItem(
                  context,
                  Icons.dashboard_rounded,
                  'Dashboard',
                  () {
                    context.pop(); // Close drawer
                    context.go(
                      '/home',
                    ); // Or just stick to current if likely already there
                  },
                ),
                _buildDrawerItem(
                  context,
                  Icons.list_alt_rounded,
                  'My Orders',
                  () {
                    context.pop();
                    context.push('/orders');
                  },
                ),
                _buildDrawerItem(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'Earnings',
                  () {
                    context.pop();
                    // Mock
                  },
                ),
                _buildDrawerItem(
                  context,
                  Icons.map_outlined,
                  'Service Area',
                  () {
                    context.pop();
                    context.push('/service-area');
                  },
                ),
                _buildDrawerItem(
                  context,
                  Icons.inventory_2_outlined,
                  'Inventory',
                  () {
                    context.pop();
                    // Depending on nav structure, might want to switch tab
                  },
                ),
                const Divider(height: 32),
                _buildDrawerItem(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  () {
                    context.pop();
                  },
                ),
                _buildDrawerItem(context, Icons.help_outline, 'Support', () {
                  context.pop();
                }),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: OutlinedButton.icon(
              onPressed: () {
                context.go('/'); // Logout
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
