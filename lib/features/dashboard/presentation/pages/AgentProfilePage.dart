import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

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

  bool _hasChanges = false;
  late Map<String, String> _initialValues;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: "Syed");
    _phoneController = TextEditingController(text: "9876543321");
    _altPhoneController = TextEditingController(text: "");
    _zoneController = TextEditingController(text: "Thiruvallur");
    _cityController = TextEditingController(text: "Thiruvallur");
    _vehicleTypeController = TextEditingController(text: "Bike");
    _vehicleNumberController = TextEditingController(text: "TN 12 AB 1234");
    _dlExpiryController = TextEditingController(text: "12/12/2030");
    _ratingController = TextEditingController(text: "5.0");

    _bankNameController = TextEditingController(text: "HDFC Bank");
    _accountNumberController = TextEditingController(text: "52100123456789");
    _ifscController = TextEditingController(text: "IDFC0001234");
    _upiController = TextEditingController(text: "syed@upi");

    _initialValues = _getCurrentValues();

    // Add listeners to editable fields
    _phoneController.addListener(_checkForChanges);
    _altPhoneController.addListener(_checkForChanges);
    _dlExpiryController.addListener(_checkForChanges);
    _bankNameController.addListener(_checkForChanges);
    _accountNumberController.addListener(_checkForChanges);
    _ifscController.addListener(_checkForChanges);
    _upiController.addListener(_checkForChanges);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
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
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.black,
                        size: 40,
                      ),
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
              "syed",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              "Agent ID: #UC1234",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 32),

            /// 🔹 Rider Details (READ-ONLY)
            _sectionCard(
              title: "Rider Details",
              icon: Icons.delivery_dining_outlined,
              child: Column(
                children: [
                  _editableField("Full Name", _nameController, enabled: false),
                  _editableField("Zone", _zoneController, enabled: false),
                  _editableField("City", _cityController, enabled: false),
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

            /// 🔹 Personal Details (EDITABLE)
            _sectionCard(
              title: "Personal Details",
              icon: Icons.person_outline,
              child: Column(
                children: [
                  _editableField("Phone Number", _phoneController),
                  _editableField("Alternate Phone", _altPhoneController),
                  _editableField("DL Expiry Date", _dlExpiryController),
                  _editableField("Agent Rating", _ratingController, enabled: false, isRating: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// 🔹 Bank Details (EDITABLE)
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
          ],
        ),
      ),
    );
  }

  /// 🔹 Reusable Section Card
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
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
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
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

  /// 🔹 Editable Field UI
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
}
