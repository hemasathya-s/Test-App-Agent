import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SosBottomSheet extends StatelessWidget {
  const SosBottomSheet({super.key});

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
                  icon: Icons.people_outline,
                  label: 'Nearby Agents',
                  onTap: () =>
                      _handleAction(context, 'Alerting nearby agents...'),
                  color: Colors.blue,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.support_agent,
                  label: 'Support Team',
                  onTap: () =>
                      _handleAction(context, 'Calling Support Team...'),
                  color: Colors.blue,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.medical_services_outlined,
                  label: 'Ambulance',
                  onTap: () => _handleAction(context, 'Calling Ambulance...'),
                  color: Colors.red,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.local_police_outlined,
                  label: 'Police',
                  onTap: () => _handleAction(context, 'Calling Police...'),
                  color: Colors.red,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.car_crash_outlined,
                  label: 'Report Accident',
                  onTap: () =>
                      _handleAction(context, 'Opening Accident Report...'),
                  color: Colors.orange,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.warning_amber_rounded,
                  label: 'Report Theft',
                  onTap: () =>
                      _handleAction(context, 'Opening Theft Report...'),
                  color: Colors.orange,
                ),
                _buildSosOption(
                  context,
                  icon: Icons.build_outlined,
                  label: 'Bike Repair',
                  onTap: () =>
                      _handleAction(context, 'Requesting Bike Repair...'),
                  color: Colors.orange,
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

  void _handleAction(BuildContext context, String message) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
