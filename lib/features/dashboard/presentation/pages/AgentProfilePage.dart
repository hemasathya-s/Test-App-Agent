import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../Model/AgentProfileResponse.dart';

class AgentProfilePage extends StatefulWidget {
  const AgentProfilePage({super.key});

  @override
  State<AgentProfilePage> createState() => _AgentProfilePageState();
}

class _AgentProfilePageState extends State<AgentProfilePage> {
  bool _isLoading = true;
  String? _error;
  AgentProfileData? _agentData;
  String? termsUrl;
  String? privacyUrl;
  String? supportPhone;
  String? supportEmail;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    print("📡 AgentProfilePage: Fetching profile...");
    setState(() {
      _isLoading = true;
      _error = null;
      _agentData = null; // Clear old data while loading
    });

    final token = await ApiService.getAccessToken();
    if (token == null) {
      print("❌ AgentProfilePage: No token found. Redirecting to login...");
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    final result = await ApiService.getAgentProfile();
    final appSettings = await ApiService.getAppSettings();

    if (mounted) {
      if (result.isSuccess && result.data != null) {
        print("✅ AgentProfilePage: Profile loaded for ${result.data!.agent.userDetails.name}");
        setState(() {
          _agentData = result.data!.agent;
           privacyUrl = appSettings?['agent_partner_privacy_policy_url'] ?? '';
           termsUrl = appSettings?['agent_partner_terms_and_conditions_url'] ?? '';
           supportPhone = appSettings?['support_phone'] ?? '';
           supportEmail = appSettings?['support_email'] ?? '';
          _isLoading = false;
        });
      } else {
        print("❌ AgentProfilePage: Error loading profile: ${result.error}");
        setState(() {
          _isLoading = false;
          _error = result.error ?? "Failed to load profile";
        });
      }
    }
  }

  Future<void> _performLogout() async {
    setState(() => _isLoading = true);
    final result = await ApiService().logoutUser();
    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isSuccess) {
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Logout failed')),
        );
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildShimmerLoading(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 48, left: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.textPrimary),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 4),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFF1F1F1),
                      backgroundImage: _agentData?.profileImageUrl != null 
                          ? NetworkImage("${_agentData!.profileImageUrl!}?v=${DateTime.now().millisecondsSinceEpoch}") 
                          : null,
                      child: _agentData?.profileImageUrl == null 
                          ? const Icon(Icons.person_rounded, size: 60, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _agentData?.userDetails.name.isNotEmpty == true 
                        ? _agentData!.userDetails.name 
                        : (_agentData?.userName.isNotEmpty == true ? _agentData!.userName : "Agent"),
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    "Agent ID: #${_agentData?.id.substring(0, 8).toUpperCase() ?? "N/A"}",
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
              onTap: () async {
                if (_agentData != null) {
                  print("🚀 AgentProfilePage: Navigating to edit-profile...");
                  final result = await context.push('/edit-profile', extra: _agentData);
                  print("🚀 AgentProfilePage: Returned from edit-profile with result: $result");
                  if (result == true) {
                    print("🔄 AgentProfilePage: Refreshing profile...");
                    _fetchProfile();
                  }
                }
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.history_rounded,
              title: "Order Details",
              onTap: () => context.push('/orders'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_outlined,
              title: "Request Inventory",
              onTap: () => context.push('/request-inventory'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.description_outlined,
              title: "Terms and Condition",
              onTap: () => _launchURL(termsUrl ?? ''),
            ),
            _buildMenuItem(
              context,
              icon: Icons.headset_mic_outlined,
              title: "Support",
              onTap: () {
                _showSupportBottomSheet(context);
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
        backgroundColor: Colors.white,
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
              _performLogout();
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

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 120, height: 120,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(height: 16),
            Container(width: 150, height: 24, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: 100, height: 16, color: Colors.white),
            const SizedBox(height: 40),
            ...List.generate(5, (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(width: double.infinity, height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
            )),
          ],
        ),
      ),
    );
  }

  void _showSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Support',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSupportOption(
                    context,
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onTap: () {
                      Navigator.pop(context);
                      final phone = supportPhone?.isNotEmpty == true ? supportPhone! : '+1234567890';
                      _launchURL('tel:$phone');
                    },
                  ),
                  _buildSupportOption(
                    context,
                    icon: Icons.email_outlined,
                    label: 'Email',
                    onTap: () {
                      Navigator.pop(context);
                      final email = supportEmail?.isNotEmpty == true ? supportEmail! : 'support@example.com';
                      _launchURL('mailto:$email');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}
