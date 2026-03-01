import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urban_agent_app/core/services/Api%20service.dart';

import '../../../../Model/AgentRegistrationRequest.dart';
import '../../../dashboard/presentation/pages/dashboard_shell.dart';
import 'login_screen.dart';


class AgentRegistrationPage extends StatefulWidget {
  final String? mobileNumber;
  const AgentRegistrationPage({super.key, this.mobileNumber});

  @override
  State<AgentRegistrationPage> createState() => _AgentRegistrationPageState();
}

class _AgentRegistrationPageState extends State<AgentRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late final TextEditingController _mobileController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _commentsController = TextEditingController();
  final _hubIdController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiIdController = TextEditingController();
 // final _alternateNumberController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  //final _dlExpiryController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController(text: widget.mobileNumber);
  }

  // Dropdowns / selectors
  String? _agentType;
  bool? _adminPermission;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _vehicleType; // '2_WHEELER' | '4_WHEELER'
  //DateTime? _dlExpiryDate;

  // Files
  File? _profileImage;
  File? _aadharDoc;
  File? _panCard;
  File? _videoKyc;

  final _picker = ImagePicker();

  // Colors
  static const _orange = Color(0xFFFF9800);
  static const _orangeDark = Color(0xFFE65100);
  static const _orangeLight = Color(0xFFFFF3E0);
  static const _surface = Color(0xFFF7F7F8);
  static const _cardBg = Colors.white;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _commentsController.dispose();
    _hubIdController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiIdController.dispose();
   // _alternateNumberController.dispose();
    _vehicleNumberController.dispose();
   // _dlExpiryController.dispose();
    super.dispose();
  }

  // ── File Picker ───────────────────────────────────────────────────────────

  Future<void> _pickFile({
    required bool isImage,
    required void Function(File) onPicked,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Choose Source',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final XFile? picked = isImage
        ? await _picker.pickImage(source: source, imageQuality: 85)
        : await _picker.pickVideo(source: source);

    if (picked != null) onPicked(File(picked.path));
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _orangeLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: _orange, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600, color: _orangeDark)),
          ],
        ),
      ),
    );
  }

  // ── Time Picker ───────────────────────────────────────────────────────────

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startTime = picked;
        else
          _endTime = picked;
      });
    }
  }

  String _formatTime(TimeOfDay t) => t.format(context);

  String _timeToString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

/*
  Future<void> _pickDlExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dlExpiryDate = picked;
        _dlExpiryController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }
*/

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profileImage == null) {
      _showSnack('Please upload a profile image');
      return;
    }
    if (_vehicleType == null) {
      _showSnack('Please select a vehicle type');
      return;
    }
    if (_aadharDoc == null) {
      _showSnack('Please upload your Aadhaar document');
      return;
    }
    if (_panCard == null) {
      _showSnack('Please upload your PAN card');
      return;
    }

    setState(() => _isLoading = true);

    final request = AgentRegistrationRequest(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      // alternateNumber: _alternateNumberController.text.trim(),
      password: _passwordController.text,
      comments: _commentsController.text.trim(),
      agentType: _agentType,
      isAdminPermissionRequired: _adminPermission,
      hubId: _hubIdController.text.trim(),
      startTime: _startTime != null ? _timeToString(_startTime!) : null,
      endTime: _endTime != null ? _timeToString(_endTime!) : null,
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      ifscCode: _ifscController.text.trim(),
      upiId: _upiIdController.text.trim(),
      vehicleNumber: _vehicleNumberController.text.trim(),
      vehicleType: _vehicleType,
      // dlExpiryDate: _dlExpiryController.text.trim(),
    );

    final result = await ApiService().registerAgent(
      request: request,
      profileImage: _profileImage,
      aadharDoc: _aadharDoc,
      panCard: _panCard,
      videoKyc: _videoKyc,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      _showSuccessDialog(result.data!.user.name);
    } else {
      _showSnack(result.error ?? 'Registration failed');
    }
  }

  void _showSuccessDialog(String agentName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _orangeLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check_circle_rounded,
                  color: _orange, size: 24),
            ),
            const SizedBox(width: 12),
            Text('Welcome!',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Text(
          '"$agentName" registered successfully.',
          style: GoogleFonts.outfit(color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LoginPage(
                    initialMobileNumber: _mobileController.text.trim(),
                  ),
                ),
              );
            },
            child: Text('Continue',
                style: GoogleFonts.outfit(
                    color: _orange, fontWeight: FontWeight.w700)
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit()),
        backgroundColor: _orangeDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft01, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Agent Registration',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_orangeDark, _orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  children: [
                    // ── Profile Image (Top Circle) ──────────────────
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              color: Colors.grey[100],
                            ),
                            child: _profileImage != null
                                ? ClipOval(
                              child: Image.file(_profileImage!,
                                  fit: BoxFit.cover),
                            )
                                : Icon(Icons.person_rounded,
                                size: 60, color: Colors.grey[400]),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _pickFile(
                                isImage: true,
                                onPicked: (f) =>
                                    setState(() => _profileImage = f),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: _orange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── 1. Basic Information ────────────────────────
                    _sectionCard(
                      icon: Icons.person_rounded,
                      title: 'Basic Information',
                      color: const Color(0xFF5C6BC0),
                      children: [
                        _field(
                          controller: _nameController,
                          label: 'Full Name *',
                          icon: Icons.badge_outlined,
                          validator: (v) =>
                          v!.isEmpty ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _emailController,
                          label: 'Email Address *',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.isEmpty) return 'Email is required';
                            if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$')
                                .hasMatch(v)) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _mobileController,
                          label: 'Mobile Number *',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v!.isEmpty) return 'Mobile number is required';
                            if (v.length != 10) return 'Must be 10 digits';
                            return null;
                          },
                        ),
                       /* const SizedBox(height: 16),
                        _field(
                          controller: _alternateNumberController,
                          label: 'Alternate Number (Optional)',
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length != 10)
                              return 'Must be 10 digits';
                            return null;
                          },
                        ), */
                        const SizedBox(height: 16),
                        _field(
                          controller: _passwordController,
                          label: 'Password *',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                            onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'Password is required';
                            if (v.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password *',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                            onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'Please confirm password';
                            if (v != _passwordController.text)
                              return 'Passwords do not match';
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── 2. Vehicle Details ──────────────────────────
                    _sectionCard(
                      icon: Icons.directions_bike_rounded,
                      title: 'Vehicle Details',
                      color: Colors.orange.shade800,
                      children: [
                        _labelText('Vehicle Type *'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _typeChip(
                              label: '2 Wheeler',
                              icon: Icons.directions_bike_rounded,
                              selected: _vehicleType == '2_WHEELER',
                              onTap: () =>
                                  setState(() => _vehicleType = '2_WHEELER'),
                            ),
                            const SizedBox(width: 12),
                            _typeChip(
                              label: '4 Wheeler',
                              icon: Icons.directions_car_rounded,
                              selected: _vehicleType == '4_WHEELER',
                              onTap: () =>
                                  setState(() => _vehicleType = '4_WHEELER'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _field(
                          controller: _vehicleNumberController,
                          label: 'Vehicle Number *',
                          icon: Icons.numbers_rounded,
                          inputFormatters: [
                            _UpperCaseTextFormatter(),
                            LengthLimitingTextInputFormatter(12),
                          ],
                          validator: (v) =>
                          v!.isEmpty ? 'Vehicle number is required' : null,
                        ),
                        /* const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _pickDlExpiry,
                          child: AbsorbPointer(
                            child: _field(
                              controller: _dlExpiryController,
                              label: 'DL Expiry Date *',
                              icon: Icons.calendar_today_rounded,
                              validator: (v) =>
                              v!.isEmpty ? 'DL expiry is required' : null,
                            ),
                          ),
                        ), */
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Bank Details ─────────────────────────────
                    _sectionCard(
                      icon: Icons.account_balance_rounded,
                      title: 'Bank Details',
                      color: const Color(0xFF26A69A),
                      children: [
                        _labelText('Bank Name'),
                        const SizedBox(height: 8),
                        _field(
                          controller: _bankNameController,
                          label: 'Bank Name',
                          icon: Icons.business_rounded,
                          validator: (v) =>
                          v!.isEmpty ? 'Enter bank name' : null,
                        ),
                        const SizedBox(height: 16),
                        _labelText('Account Number'),
                        const SizedBox(height: 8),
                        _field(
                          controller: _accountNumberController,
                          label: 'Account Number',
                          icon: Icons.numbers_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) =>
                          v!.isEmpty ? 'Enter account number' : null,
                        ),
                        const SizedBox(height: 16),
                        _labelText('IFSC Code'),
                        const SizedBox(height: 8),
                        _field(
                          controller: _ifscController,
                          label: 'IFSC Code',
                          icon: Icons.code_rounded,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]')),
                            LengthLimitingTextInputFormatter(11),
                            _UpperCaseTextFormatter(),
                          ],
                          validator: (v) {
                            if (v!.isEmpty) return 'Enter IFSC code';
                            if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                                .hasMatch(v.toUpperCase())) {
                              return 'Enter a valid IFSC code (e.g. HDFC0001234)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _labelText('UPI ID'),
                        const SizedBox(height: 8),
                        _field(
                          controller: _upiIdController,
                          label: 'UPI ID (e.g. name@upi)',
                          icon: Icons.account_balance_wallet_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              if (!RegExp(r'^[\w.\-]+@[\w]+$').hasMatch(v)) {
                                return 'Enter a valid UPI ID (e.g. syed@upi)';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── 4. Documents & KYC ──────────────────────────
                    _sectionCard(
                      icon: Icons.folder_rounded,
                      title: 'Documents & KYC',
                      color: _orange,
                      children: [
                        _uploadTile(
                          label: 'Aadhaar Document *',
                          subtitle: 'JPG / PNG — Front & back',
                          icon: Icons.credit_card_rounded,
                          file: _aadharDoc,
                          isVideo: false,
                          onTap: () => _pickFile(
                            isImage: true,
                            onPicked: (f) => setState(() => _aadharDoc = f),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _uploadTile(
                          label: 'PAN Card *',
                          subtitle: 'JPG / PNG — Clear scan',
                          icon: Icons.badge_rounded,
                          file: _panCard,
                          isVideo: false,
                          onTap: () => _pickFile(
                            isImage: true,
                            onPicked: (f) => setState(() => _panCard = f),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _uploadTile(
                          label: 'Video KYC (Optional)',
                          subtitle: 'MP4 — Short selfie video',
                          icon: Icons.videocam_rounded,
                          file: _videoKyc,
                          isVideo: true,
                          onTap: () => _pickFile(
                            isImage: false,
                            onPicked: (f) => setState(() => _videoKyc = f),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Submit Button ───────────────────────────────
                    _submitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget Builders ───────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelText(String text) => Text(
    text,
    style: GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.grey[700],
      letterSpacing: 0.2,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLines: maxLines,
      validator: validator,
      cursorColor: _orange,
      style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600]),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surface,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orange, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _orange : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _orange : Colors.grey.shade300,
              width: selected ? 0 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.grey[500], size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.grey[600],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay? time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: time != null ? _orangeLight : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: time != null ? _orange : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: time != null ? _orange : Colors.grey[500]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                  Text(
                    time != null ? _formatTime(time) : 'Tap to set',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: time != null ? _orangeDark : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required File? file,
    required bool isVideo,
    required VoidCallback onTap,
  }) {
    final uploaded = file != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: uploaded ? _orangeLight : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: uploaded ? _orange : Colors.grey.shade200,
            width: uploaded ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color:
                uploaded ? _orange.withOpacity(0.15) : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: uploaded && !isVideo
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(file!, fit: BoxFit.cover),
              )
                  : Icon(
                uploaded ? Icons.check_circle_rounded : icon,
                color: uploaded ? _orange : Colors.grey[400],
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: uploaded ? _orangeDark : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    uploaded ? file!.path.split('/').last : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: uploaded ? _orange : Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(
              uploaded ? Icons.edit_rounded : Icons.upload_rounded,
              color: uploaded ? _orange : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _submitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_orangeDark, _orange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _orange.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.how_to_reg_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text('Register Agent',
                style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}