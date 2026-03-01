import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/Api service.dart';
import '../../../../Model/AgentProfileResponse.dart';

class EditProfilePage extends StatefulWidget {
  final AgentProfileData agentData;

  const EditProfilePage({super.key, required this.agentData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  // late final TextEditingController _altPhoneController;
  // late final TextEditingController _zoneController;
  // late final TextEditingController _cityController;
  late final TextEditingController _vehicleTypeController;
  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _ifscController;
  late final TextEditingController _upiController;

  bool _isLoading = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final agent = widget.agentData;
    _nameController = TextEditingController(text: agent.userDetails.name);
    _emailController = TextEditingController(text: agent.userDetails.email);
    // _altPhoneController = TextEditingController(text: ""); 
    // _zoneController = TextEditingController(text: ""); 
    // _cityController = TextEditingController(text: ""); 
    _vehicleTypeController = TextEditingController(text: agent.vehicleType ?? "");
    _vehicleNumberController = TextEditingController(text: agent.vehicleNumber ?? "");
    _bankNameController = TextEditingController(text: agent.bankName ?? "");
    _accountNumberController = TextEditingController(text: agent.accountNumber ?? "");
    _ifscController = TextEditingController(text: agent.ifscCode ?? "");
    _upiController = TextEditingController(text: agent.upiId ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    // _altPhoneController.dispose();
    // _zoneController.dispose();
    // _cityController.dispose();
    _vehicleTypeController.dispose();
    _vehicleNumberController.dispose();
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
    if (_bankNameController.text.trim().isNotEmpty) {
      updatedData['bank_name'] = _bankNameController.text.trim();
    }
    if (_accountNumberController.text.trim().isNotEmpty)
      updatedData['account_number'] = _accountNumberController.text.trim();
    if (_ifscController.text.trim().isNotEmpty)
      updatedData['ifsc_code'] = _ifscController.text.trim();
    if (_upiController.text.trim().isNotEmpty) {
      updatedData['upi_id'] = _upiController.text.trim();
    }
    // if (_altPhoneController.text.trim().isNotEmpty) {
    //   updatedData['alternate_number'] = _altPhoneController.text.trim();
    // }
    // if (_zoneController.text.trim().isNotEmpty) {
    //   updatedData['zone'] = _zoneController.text.trim();
    // }
    // if (_cityController.text.trim().isNotEmpty) {
    //   updatedData['city'] = _cityController.text.trim();
    // }
    
    if (_vehicleTypeController.text.trim().isNotEmpty)
      updatedData['vehicle_type'] = _vehicleTypeController.text.trim();
    if (_vehicleNumberController.text.trim().isNotEmpty)
      updatedData['vehicle_number'] = _vehicleNumberController.text.trim();
    
    print('✏️ Sending update for user ID: ${widget.agentData.userId}');
    print('✏️ Payload: $updatedData');

    final result = await ApiService().updateAgentProfile(
      widget.agentData.userId,
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
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true); // ✅ returns true → caller can refresh
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
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
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
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                "Save",
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _profileImage != null
                            ? Image.file(_profileImage!, fit: BoxFit.cover)
                            : widget.agentData.profileImageUrl != null
                                ? Image.network(widget.agentData.profileImageUrl!, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.person, size: 50, color: Colors.grey),
                                  ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _sectionTitle("Basic Information"),
              const SizedBox(height: 16),
              _buildTextField("Full Name", _nameController),
              _buildTextField("Email", _emailController, enabled: false),
              // _buildTextField("Alternate Phone", _altPhoneController),
              
              const SizedBox(height: 32),
              _sectionTitle("Rider Details"),
              const SizedBox(height: 16),
              // _buildTextField("Zone", _zoneController),
              // _buildTextField("City", _cityController),
              _buildTextField("Vehicle Type", _vehicleTypeController),
              _buildTextField("Vehicle Number", _vehicleNumberController),

              const SizedBox(height: 32),
              _sectionTitle("Bank Details"),
              const SizedBox(height: 16),
              _buildTextField("Bank Name", _bankNameController),
              _buildTextField("Account Number", _accountNumberController),
              _buildTextField("IFSC Code", _ifscController),
              _buildTextField("UPI ID", _upiController),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary.withOpacity(0.6),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
           /* validator: (value) {
              if (enabled && (value == null || value.isEmpty) && label != "Alternate Phone") {
                return 'Please enter $label';
              }
              return null;
            },*/
          ),
        ],
      ),
    );
  }
}
