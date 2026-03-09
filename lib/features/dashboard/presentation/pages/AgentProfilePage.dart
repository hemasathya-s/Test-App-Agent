import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:urban_agent_app/core/services/apiservices.dart';
import '../../../../Model/AgentProfileResponse.dart';
import '../../../../core/theme/app_theme.dart';
import 'EditProfilePage.dart';

class AgentProfilePage extends StatefulWidget {
  const AgentProfilePage({super.key});

  @override
  State<AgentProfilePage> createState() => _AgentProfilePageState();
}

class _AgentProfilePageState extends State<AgentProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _altPhoneController;
  late final TextEditingController _zoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _vehicleTypeController;
  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _dlExpiryController;
  late final TextEditingController _ratingController;

  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _ifscController;
  late final TextEditingController _upiController;

  bool _isLoading = true;
  String? _error;
  AgentProfileData? _agentData;

  bool _hasChanges = false;
  late Map<String, String> _initialValues;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _altPhoneController = TextEditingController();
    _zoneController = TextEditingController();
    _cityController = TextEditingController();
    _vehicleTypeController = TextEditingController();
    _vehicleNumberController = TextEditingController();
    _dlExpiryController = TextEditingController();
    _ratingController = TextEditingController();

    _bankNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _ifscController = TextEditingController();
    _upiController = TextEditingController();

    _initialValues = _getCurrentValues();

    // Add listeners to editable fields
    _phoneController.addListener(_checkForChanges);
    _altPhoneController.addListener(_checkForChanges);
    _dlExpiryController.addListener(_checkForChanges);
    _bankNameController.addListener(_checkForChanges);
    _accountNumberController.addListener(_checkForChanges);
    _ifscController.addListener(_checkForChanges);
    _upiController.addListener(_checkForChanges);

    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Guard: Check if token exists before making authorized request
    final token = await ApiService.getAccessTokenLocal();
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Session expired. Please login again.";
        });
      }
      return;
    }

    final result = await ApiService.getAgentProfile();

    if (mounted) {
      if (result.isSuccess && result.data != null) {
        final agent = result.data!.agent;
        setState(() {
          _agentData = agent;
          _isLoading = false;

          _nameController.text = agent.userDetails.name;
          _phoneController.text = agent.userDetails.mobileNumber;
          _bankNameController.text = agent.bankName ?? "";
          _accountNumberController.text = agent.accountNumber ?? "";
          _ifscController.text = agent.ifscCode ?? "";
          _upiController.text = agent.upiId ?? "";
          _vehicleTypeController.text = agent.vehicleType ?? "N/A";
          _vehicleNumberController.text = agent.vehicleNumber ?? "N/A";
          _ratingController.text = agent.cumulativeRating;

          // Re-set initial values after fetching
          _initialValues = _getCurrentValues();
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = result.error ?? "Failed to load profile";
        });
      }
    }
  }

  Map<String, String> _getCurrentValues() {
    return {
      'phone': _phoneController.text,
      'altPhone': _altPhoneController.text,
      'dlExpiry': _dlExpiryController.text,
      'bankName': _bankNameController.text,
      'accountNumber': _accountNumberController.text,
      'ifsc': _ifscController.text,
      'upi': _upiController.text,
    };
  }

  void _checkForChanges() {
    final currentValues = _getCurrentValues();
    bool changed = false;
    currentValues.forEach((key, value) {
      if (value != _initialValues[key]) {
        changed = true;
      }
    });

    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _zoneController.dispose();
    _cityController.dispose();
    _vehicleTypeController.dispose();
    _vehicleNumberController.dispose();
    _dlExpiryController.dispose();
    _ratingController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _performLogout() async {
    setState(() => _isLoading = true);

    final result = await ApiService.logoutUser();

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isSuccess) {
        // Navigate using GoRouter to Login and clear the stack
        if (mounted) context.go('/login');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged out successfully', style: GoogleFonts.outfit()),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Logout failed', style: GoogleFonts.outfit()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(
            'Logout',
            style: GoogleFonts.outfit(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
            ),
          ),
          actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _performLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft01, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Profile",
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _hasChanges
                ? () {
              // Save API call here
              setState(() {
                _initialValues = _getCurrentValues();
                _hasChanges = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated successfully')),
              );
            }
                : null,
            icon: Icon(
              Icons.check_circle_rounded,
              color: _hasChanges ? AppTheme.primaryColor : Colors.grey.shade400,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: GoogleFonts.outfit(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProfile,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: Text("Retry", style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            const SizedBox(height: 24),

            /// ðŸ”¹ Profile Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _agentData?.profileImageUrl != null
                          ? NetworkImage(_agentData!.profileImageUrl!)
                          : null,
                      child: _agentData?.profileImageUrl == null
                          ? const Icon(
                        Icons.person_rounded,
                        color: Colors.black,
                        size: 40,
                      )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 12),
            Text(
              _agentData?.userDetails.name ?? "Agent",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              "Agent ID: #${_agentData?.id.substring(0, 8).toUpperCase() ?? "N/A"}",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 32),



            /// ðŸ”¹ Personal Details (EDITABLE)
            _sectionCard(
              title: "Personal Details",
              icon: Icons.person_outline,
              trailing: GestureDetector(
                onTap: () async {
                  if (_agentData == null) return;
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfilePage(agentData: _agentData!),
                    ),
                  );
                  if (result == true) {
                    _fetchProfile(); // Refresh data after update
                  }
                },
                child: Text(
                  "Edit",
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              child: Column(
                children: [
                  _editableField("Full Name", _nameController, enabled: false),
                  _editableField("Phone Number", _phoneController, enabled: false),
                  _altPhoneController.text.isNotEmpty
                      ? _editableField("Alternate Phone", _altPhoneController, enabled: false)
                      : const SizedBox.shrink(),
                  _editableField("DL Expiry Date", _dlExpiryController, enabled: false),
                  _editableField("Agent Rating", _ratingController, enabled: false, isRating: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// ðŸ”¹ Rider Details (READ-ONLY)
            _sectionCard(

              title: "Rider Details",
              icon: Icons.delivery_dining_outlined,
              child: Column(
                children: [
                  // _editableField("Zone", _zoneController, enabled: false),
                  // _editableField("City", _cityController, enabled: false),
                  Row(
                    children: [
                      Expanded(child: _editableField("Vehicle Type", _vehicleTypeController, enabled: false)),
                      const SizedBox(width: 12),
                      Expanded(child: _editableField("Vehicle Number", _vehicleNumberController, enabled: false)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// ðŸ”¹ Bank Details (EDITABLE)
            _sectionCard(
              title: "Bank Details",
              icon: Icons.account_balance_outlined,
              child: Column(
                children: [
                  _editableField("Bank Name", _bankNameController,enabled: false),
                  _editableField("Account Number", _accountNumberController,enabled: false),
                  _editableField("IFSC Code", _ifscController,enabled: false),
                  _editableField("UPI ID", _upiController,enabled: false),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Logout Button
            Container(
              margin:const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color:   Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildMenuItem(
                icon: HugeIcons.strokeRoundedLogoutSquare01,
                title: 'Logout',
                isLogout: true,
                onTap: _showLogoutDialog,
                showDivider: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ðŸ”¹ Reusable Section Card
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  /// ðŸ”¹ Editable Field UI
  Widget _editableField(
      String label,
      TextEditingController controller, {
        bool enabled = true,
        bool isRating = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary.withOpacity(0.7),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? AppTheme.surfaceColor.withOpacity(0.5) : Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: isRating ? const Icon(Icons.star, color: Colors.amber, size: 18) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade100),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ðŸ”¹ Shimmer Loading UI
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            /// Profile Circle Shimmer
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _shimmerBlock(width: 120, height: 20),
            const SizedBox(height: 8),
            _shimmerBlock(width: 80, height: 14),
            const SizedBox(height: 40),

            /// Rider Details Shimmer
            _shimmerSection(),
            const SizedBox(height: 24),

            /// Personal Details Shimmer
            _shimmerSection(),
            const SizedBox(height: 24),

            /// Bank Details Shimmer
            _shimmerSection(),
          ],
        ),
      ),
    );
  }

  Widget _shimmerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmerBlock(width: 100, height: 18),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBlock(width: 60, height: 12),
                  const SizedBox(height: 8),
                  _shimmerBlock(width: double.infinity, height: 45, radius: 12),
                ],
              ),
            )),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBlock({required double width, required double height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
    bool showDivider = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLogout ? Colors.red : AppTheme.textPrimary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isLogout ? Colors.red : AppTheme.textPrimary,
                ),
              ),
            ),
            if (!isLogout)
              Icon(
                HugeIcons.strokeRoundedArrowRight01,
                color: Colors.grey[400],
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
