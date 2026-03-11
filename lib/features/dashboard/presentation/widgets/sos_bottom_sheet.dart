import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/apiservices.dart';

class SosBottomSheet extends StatefulWidget {
  const SosBottomSheet({super.key});

  @override
  State<SosBottomSheet> createState() => _SosBottomSheetState();
}

class _SosBottomSheetState extends State<SosBottomSheet> {
  Map<String, dynamic>? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ApiService.getAppSettings();
    
    // 🔹 PRINT THE RESPONSE FROM THE API
    debugPrint('DEBUG: APP SETTINGS RESPONSE:');
    if (settings != null) {
      debugPrint(jsonEncode(settings));
    } else {
      debugPrint('DEBUG: APP SETTINGS RESPONSE IS NULL');
    }

    if (mounted) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Emergency Assistance',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Who do you want to contact?',
            style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSosOption(
                  context,
                  icon: Icons.support_agent,
                  label: 'Support Call',
                  onTap: () => _makeCall(_settings?['support_phone']),
                  color: Colors.blue,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.contact_emergency,
                  label: 'Ambulance',
                  onTap: () => _makeCall(_settings?['contact_ambulance'] ?? '108'),
                  color: Colors.red,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.local_police_outlined,
                  label: 'Police',
                  onTap: () => _makeCall(_settings?['contact_police'] ?? '100'),
                  color: Colors.red,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.warning_amber_rounded,
                  label: 'Report Theft',
                  onTap: () => _makeCall(_settings?['contact_police'] ?? '100'),
                  color: Colors.orange,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.build_outlined,
                  label: 'Bike Repair',
                  onTap: () =>
                      _makeCall(_settings?['support_phone']),
                  color: Colors.orange,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.mail,
                  label: 'Support Mail',
                  onTap: () => _sendEmail(_settings?['support_email']),
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSosOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    final Uri url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
