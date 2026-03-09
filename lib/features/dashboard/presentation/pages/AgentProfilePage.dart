import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class AgentProfilePage extends StatelessWidget {
  const AgentProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 4),
                    ),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Color(0xFFF1F1F1),
                      child: Icon(Icons.person_rounded, size: 60, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Syed",
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    "Agent ID: #UC1234",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Menu Items
            _buildMenuItem(
              context,
              icon: Icons.edit_outlined,
              title: "Edit Profile",
              onTap: () => context.push('/edit-profile'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.history_rounded,
              title: "Order Details",
              onTap: () => context.push('/orders'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.description_outlined,
              title: "Terms and Condition",
              onTap: () {
                // Show T&C
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.headset_mic_outlined,
              title: "Support",
              onTap: () {
                // Open support chat or dialer
              },
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(height: 1),
            ),
            
            _buildMenuItem(
              context,
              icon: Icons.logout_rounded,
              title: "Logout",
              isLogout: true,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLogout ? Colors.red.withOpacity(0.05) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isLogout ? Colors.red : AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isLogout ? Colors.red : AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isLogout ? Colors.red.withOpacity(0.5) : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Logout",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: Text(
              "Logout",
              style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
