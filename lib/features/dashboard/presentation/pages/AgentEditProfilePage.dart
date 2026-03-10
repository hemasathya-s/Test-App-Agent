import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../Model/AgentProfileResponse.dart';
import 'package:hugeicons/hugeicons.dart';

class AgentEditProfilePage extends StatefulWidget {
  final AgentProfileData agentData;

  const AgentEditProfilePage({super.key, required this.agentData});

  @override
  State<AgentEditProfilePage> createState() => _AgentEditProfilePageState();
}

class _AgentEditProfilePageState extends State<AgentEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _vehicleTypeController;
  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _ifscController;
  late final TextEditingController _upiController;

  bool _isLoading = true; // Start with loading for fetch
  AgentProfileData? _agentData;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _agentData = widget.agentData;
    _initControllers(_agentData!);
    _fetchProfile(); // Fetch fresh data
  }

  void _initControllers(AgentProfileData agent) {
    String name = agent.userDetails.name;
    if (name.isEmpty && agent.userName.isNotEmpty) {
      name = agent.userName;
    }
    _nameController = TextEditingController(text: name);
    _emailController = TextEditingController(text: agent.userDetails.email);
    _phoneController = TextEditingController(text: agent.userDetails.mobileNumber);
    _vehicleTypeController = TextEditingController(text: agent.vehicleType ?? "");
    _vehicleNumberController = TextEditingController(text: agent.vehicleNumber ?? "");
    _bankNameController = TextEditingController(text: agent.bankName ?? "");
    _accountNumberController = TextEditingController(text: agent.accountNumber ?? "");
    _ifscController = TextEditingController(text: agent.ifscCode ?? "");
    _upiController = TextEditingController(text: agent.upiId ?? "");
  }

  Future<void> _fetchProfile() async {
    print("📡 Fetching fresh profile data...");
    final result = await ApiService.getAgentProfile();
    if (result.isSuccess && result.data != null) {
      if (mounted) {
        setState(() {
          _agentData = result.data!.agent;
          print("✅ Fresh Profile Parsed: UserId='${_agentData?.userId}', Name='${_agentData?.userDetails.name}'");
          _updateControllers(_agentData!);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        print("❌ Failed to fetch fresh profile: ${result.error}");
        
        if (result.error?.toLowerCase().contains('authenticated') == true || 
            result.error?.toLowerCase().contains('login') == true) {
          context.go('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error fetching profile: ${result.error ?? 'Unknown error'}")),
          );
        }
      }
    }
  }

  void _updateControllers(AgentProfileData agent) {
    String name = agent.userDetails.name;
    if (name.isEmpty && agent.userName.isNotEmpty) {
      name = agent.userName;
    }
    print("✏️ Profile Update -> Name: $name, Vehicle: ${agent.vehicleType}/${agent.vehicleNumber}, Bank: ${agent.bankName}/${agent.accountNumber}");
    
    _nameController.text = name;
    _emailController.text = agent.userDetails.email;
    _phoneController.text = agent.userDetails.mobileNumber;
    _vehicleTypeController.text = agent.vehicleType ?? "";
    _vehicleNumberController.text = agent.vehicleNumber ?? "";
    _bankNameController.text = agent.bankName ?? "";
    _accountNumberController.text = agent.accountNumber ?? "";
    _ifscController.text = agent.ifscCode ?? "";
    _upiController.text = agent.upiId ?? "";
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final updatedData = <String, dynamic>{};

    if (_nameController.text.trim().isNotEmpty) {
      updatedData['name'] = _nameController.text.trim();
    }
    if (_emailController.text.trim().isNotEmpty) {
      updatedData['email'] = _emailController.text.trim();
    }
    
    // Bank Details (Flat as per registration)
    if (_bankNameController.text.trim().isNotEmpty) {
      updatedData['bank_name'] = _bankNameController.text.trim();
    }
    if (_accountNumberController.text.trim().isNotEmpty) {
      updatedData['account_number'] = _accountNumberController.text.trim();
    }
    if (_ifscController.text.trim().isNotEmpty) {
      updatedData['ifsc_code'] = _ifscController.text.trim();
    }
    if (_upiController.text.trim().isNotEmpty) {
      updatedData['upi_id'] = _upiController.text.trim();
    }
    
    // Vehicle Details (Flat as per registration)
    if (_vehicleTypeController.text.trim().isNotEmpty) {
      updatedData['vehicle_type'] = _vehicleTypeController.text.trim();
    }
    if (_vehicleNumberController.text.trim().isNotEmpty) {
      updatedData['vehicle_number'] = _vehicleNumberController.text.trim();
    }

    print('✏️ Sending update for User ID: ${_agentData?.userId}');
    print('✏️ Payload: $updatedData');

    final result = await ApiService().updateAgentProfile(
      _agentData?.userId ?? widget.agentData.userId,
      updatedData,
      profileImage: _profileImage,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully',
              style: GoogleFonts.outfit()),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.pop(true); 
    } else {
      if (result.error?.toLowerCase().contains('authenticated') == true || 
          result.error?.toLowerCase().contains('login') == true) {
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Update failed',
                style: GoogleFonts.outfit()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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
          "Edit Profile",
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _saveProfile,
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 24),
              
              /// 🔹 Profile Avatar
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
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (_agentData?.profileImageUrl != null
                                ? NetworkImage("${_agentData!.profileImageUrl!}?v=${DateTime.now().millisecondsSinceEpoch}")
                                : null) as ImageProvider?,
                        child: (_profileImage == null && _agentData?.profileImageUrl == null)
                            ? const Icon(Icons.person_rounded, color: Colors.black, size: 40)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 32,
                          width: 32,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                (_agentData?.userDetails.name.isNotEmpty == true)
                    ? _agentData!.userDetails.name
                    : (_agentData?.userName.isNotEmpty == true ? _agentData!.userName : "Agent"),
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              Text(
                "Agent ID: #${(_agentData?.id ?? "N/A").substring(0, (_agentData?.id ?? "").length > 8 ? 8 : (_agentData?.id ?? "").length).toUpperCase()}",
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 32),

              _sectionCard(
                title: "Personal Details",
                icon: Icons.person_outline,
                child: Column(
                  children: [
                    _editableField("Full Name", _nameController),
                    _editableField("Phone Number", _phoneController, enabled: false),
                    _editableField("Email Address", _emailController, enabled: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// 🔹 Rider Details
              _sectionCard(
                title: "Rider Details",
                icon: Icons.delivery_dining_outlined,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _editableField("Vehicle Type", _vehicleTypeController)),
                        const SizedBox(width: 12),
                        Expanded(child: _editableField("Vehicle Number", _vehicleNumberController)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// 🔹 Bank Details
              _sectionCard(
                title: "Bank Details",
                icon: Icons.account_balance_outlined,
                child: Column(
                  children: [
                    _editableField("Bank Name", _bankNameController),
                    _editableField("Account Number", _accountNumberController),
                    _editableField("IFSC Code", _ifscController),
                    _editableField("UPI ID", _upiController),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              /// 🔹 Submit Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          "Submit Changes",
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child, Widget? trailing}) {
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
                Expanded(child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary))),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _editableField(String label, TextEditingController controller, {bool enabled = true, bool isRating = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}
