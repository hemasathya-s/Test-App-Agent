import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationGranted = false;
  bool _micGranted = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final location = await Permission.location.isGranted;
    final camera = await Permission.camera.isGranted;
    final notification = await Permission.notification.isGranted;
    final mic = await Permission.microphone.isGranted;

    if (mounted) {
      setState(() {
        _locationGranted = location;
        _cameraGranted = camera;
        _notificationGranted = notification;
        _micGranted = mic;
      });
    }
  }

  Future<void> _requestLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      // For background tracking in Android 10+, we also need background location
      await Permission.locationAlways.request();
      setState(() => _locationGranted = true);
    }
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) setState(() => _cameraGranted = true);
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    if (status.isGranted) setState(() => _notificationGranted = true);
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) setState(() => _micGranted = true);
  }

  bool get _allRequiredGranted => _locationGranted && _notificationGranted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Permissions',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enable Permissions',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'To give you the best experience, we need access to a few things on your device.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionCard(
                      icon: Icons.location_on_rounded,
                      title: 'Location Access',
                      description: 'Required to verify service addresses and track agent arrival.',
                      isGranted: _locationGranted,
                      onToggle: _requestLocation,
                    ),
                    _buildPermissionCard(
                      icon: Icons.camera_alt_rounded,
                      title: 'Camera Access',
                      description: 'Needed to scan documents or upload photos of service items.',
                      isGranted: _cameraGranted,
                      onToggle: _requestCamera,
                    ),
                    _buildPermissionCard(
                      icon: Icons.notifications_active_rounded,
                      title: 'Push Notifications',
                      description: 'Get real-time updates on your service request status.',
                      isGranted: _notificationGranted,
                      color: const Color(0xFFFFE0B2),
                      iconColor: Colors.orange[800]!,
                      onToggle: _requestNotification,
                    ),
                    _buildPermissionCard(
                      icon: Icons.mic_rounded,
                      title: 'Microphone',
                      description: 'Voice commands enabled.',
                      isGranted: _micGranted,
                      color: const Color(0xFFE8F5E9),
                      iconColor: Colors.green[800]!,
                      onToggle: _requestMic,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _allRequiredGranted
                    ? () => context.go('/kyc')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onToggle,
    Color? color,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color ?? AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            const Icon(Icons.check_circle, color: AppTheme.successColor, size: 28)
          else
            ElevatedButton(
              onPressed: onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Allow',
                style: TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
