import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_agent_app/features/dashboard/presentation/pages/home_screen.dart';
import '../../../../core/services/Api service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/presentation/pages/dashboard_shell.dart';
import '../providers/login_provider.dart';
import 'CreateAgent.dart';

/*class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final controller = ref.read(loginProvider.notifier);

    // Keep text field in sync (mostly for when switching back from OTP to Phone)
    if (state.phase == LoginPhase.phoneInput && _phoneController.text != state.phoneNumber) {
      _phoneController.text = state.phoneNumber;
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: state.phase == LoginPhase.otpInput
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                onPressed: controller.editPhoneNumber,
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Header
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.phase == LoginPhase.phoneInput
                        ? 'Please enter your mobile number to login'
                        : 'Enter the 4-digit code sent to ${_phoneController.text}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Inputs
              if (state.phase == LoginPhase.phoneInput) _buildPhoneInput(controller),
              if (state.phase == LoginPhase.otpInput) _buildOtpInput(controller, state),

              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  style: GoogleFonts.outfit(
                    color: AppTheme.errorColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),

              // Action Button
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (state.phase == LoginPhase.phoneInput) {
                          controller.setPhoneNumber(_phoneController.text);
                          controller.requestOtp();
                        } else {
                          final success = await controller.verifyOtp(_otpController.text);
                          if (success && mounted) {
                             // Navigate to Permissions (Next Step)
                             // For now we don't have permissions route, so let's navigate to home or permissions
                             // Ideally: context.go('/permissions');
                             context.go('/permissions'); 
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.phase == LoginPhase.phoneInput ? 'Get OTP' : 'Verify & Login',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput(LoginController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            '🇺🇸 +1', // Mock country code
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey[300],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Mobile Number',
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput(LoginController controller, LoginState state) {
    return Column(
      children: [
        // Simple OTP Fields Mockup - 4 boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _otpController.text.length == index
                      ? AppTheme.primaryColor
                      : const Color(0xFFE0E0E0),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _otpController.text.length > index ? _otpController.text[index] : '',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            );
          }),
        ),
        // This is a hidden text field to handle the actual input focus
        // In a real app we'd wire focus nodes properly, for now using a hacky stack or just a hidden field
        // Let's just put a standard field below for simplicity in this iteration or assume the user taps the boxes which focuses a hidden field.
        // For 'Clean Code' in this agent mode, let's just use a visible but stylized TextField to keep it simple and functional without complex focus logic packages.
        
        const SizedBox(height: 24),
        TextField(
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            style: const TextStyle(letterSpacing: 32, fontSize: 24, color: Colors.transparent), // Hide actual text
            decoration: const InputDecoration(
               counterText: "",
               border: InputBorder.none,
               enabledBorder: InputBorder.none,
               focusedBorder: InputBorder.none,
            ),
            onChanged: (val) {
               // Trigger rebuild to update boxes
               controller.setPhoneNumber(state.phoneNumber); // Dummy call to force rebuild or set local state
               // Actually we need `setState` here as text controller changes don't trigger provider updates automatically.
               setState(() {});
            },
        ),
        
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive code? ",
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
            GestureDetector(
              onTap: state.resendTimer == 0 ? controller.resendOtp : null,
              child: Text(
                state.resendTimer > 0 ? 'Resend in 00:${state.resendTimer.toString().padLeft(2, '0')}' : 'Resend Code',
                style: GoogleFonts.outfit(
                  color: state.resendTimer > 0 ? AppTheme.textSecondary : AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}*/


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  final String? initialMobileNumber;

  const LoginPage({super.key, this.initialMobileNumber});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mobileNumberController;
  final _mobileNumberFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mobileNumberController =
        TextEditingController(text: widget.initialMobileNumber);
    _mobileNumberFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mobileNumberController.dispose();
    _mobileNumberFocusNode.dispose();
    super.dispose();
  }

  // ── Send OTP & open sheet ─────────────────────────────────────────────────
  Future<void> _handleGetOtp(BuildContext pageContext) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final api = ApiService(); // 👈 replace with your singleton/provider
    final result = await api.sendOtp(_mobileNumberController.text);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.isSuccess) {
      _showOtpBottomSheet(pageContext);
    } else {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(
          content: Text(
            result.error ?? 'Failed to send OTP',
            style: GoogleFonts.lato(),
          ),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showOtpBottomSheet(BuildContext pageContext) {
    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      isDismissible: false,   // ✅ tap outside won't close
      enableDrag: false,      // ✅ swipe down won't close
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OtpBottomSheet(
        phoneNumber: _mobileNumberController.text,
        onClose: () => Navigator.of(pageContext).pop(), // ✅ only close button closes
        onVerified: () {
          Navigator.of(pageContext).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const DashboardShell(), // 👈 replace with your home
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Container(
              padding: const EdgeInsets.all(30.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────
                    Center(
                      child: Text(
                        'Login',
                        style: GoogleFonts.lato(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Welcome Back!',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── Mobile Number ────────────────────────────────
                    Text(
                      'Mobile Number',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        color: const Color.fromRGBO(0, 0, 0, 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextFormField(
                      controller: _mobileNumberController,
                      focusNode: _mobileNumberFocusNode,
                      maxLength: 10,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your mobile number';
                        if (value.length != 10)
                          return 'Mobile number must be 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // ── Get OTP Button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                        _isLoading ? null : () => _handleGetOtp(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.orange[400],
                          disabledBackgroundColor: Colors.orange[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text(
                          'Get OTP',
                          style: GoogleFonts.lato(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Sign Up Row ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Are you a new member? ',
                          style: GoogleFonts.lato(
                            color: const Color.fromRGBO(0, 0, 0, 0.6),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AgentRegistrationPage(
                                  mobileNumber:
                                  _mobileNumberController.text.trim(),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    FocusNode? focusNode,
    bool obscureText = false,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: GoogleFonts.lato(color: Colors.black),
      cursorColor: Colors.grey,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      validator: validator,
      decoration: InputDecoration(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.orange[200]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14.0,
          horizontal: 12.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _OtpBottomSheet extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onVerified;
  final VoidCallback onClose;

  const _OtpBottomSheet({
    required this.phoneNumber,
    required this.onVerified,
    required this.onClose,
  });

  @override
  State<_OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<_OtpBottomSheet> {
  final _otpController = TextEditingController();
  int _resendTimer = 30;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendTimer == 0) {
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> _handleVerify() async {
    setState(() {
      _isVerifying = true;
      _errorMsg = null;
    });

    final api = ApiService(); // 👈 replace with your singleton/provider
    final result = await api.verifyOtp(
      mobileNumber: widget.phoneNumber,
      otp: _otpController.text,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.isSuccess) {
      widget.onVerified();
    } else {
      setState(() => _errorMsg = result.error ?? 'Invalid OTP. Try again.');
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _errorMsg = null;
    });

    final api = ApiService(); // 👈 replace with your singleton/provider
    final result = await api.sendOtp(widget.phoneNumber);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (result.isSuccess) {
      _otpController.clear();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP resent successfully', style: GoogleFonts.lato()),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      setState(() => _errorMsg = result.error ?? 'Failed to resend OTP');
    }
  }

  @override
  Widget build(BuildContext context) {
    final otp = _otpController.text;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Header Row (close btn + title) ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
              ),

              // Title
              Text(
                'Enter OTP',
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Spacer to balance close button
              const SizedBox(width: 32),
            ],
          ),

          const SizedBox(height: 12),

          // ── Subtitle ──────────────────────────────────────────────
          Text(
            'A 6-digit code was sent to ${widget.phoneNumber}',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // ── 6 OTP Boxes ───────────────────────────────────────────
          Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final isFocused = otp.length == index;
                  final isFilled = otp.length > index;
                  return Container(
                    width: 48,
                    height: 54,
                    decoration: BoxDecoration(
                      color:
                      isFilled ? Colors.orange[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFocused
                            ? Colors.orange[400]!
                            : isFilled
                            ? Colors.orange[300]!
                            : Colors.grey.shade300,
                        width: isFocused ? 2 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isFilled ? otp[index] : '',
                        style: GoogleFonts.lato(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Hidden input field
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otpController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => setState(() => _errorMsg = null),
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
              ),
            ],
          ),

          // ── Error Message ─────────────────────────────────────────
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _errorMsg!,
                    style: GoogleFonts.lato(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Resend Row ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive code? ",
                style: GoogleFonts.lato(color: Colors.grey[600]),
              ),
              _isResending
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF9800),
                ),
              )
                  : GestureDetector(
                onTap: _resendTimer == 0 ? _handleResend : null,
                child: Text(
                  _resendTimer > 0
                      ? 'Resend in 00:${_resendTimer.toString().padLeft(2, '0')}'
                      : 'Resend Code',
                  style: GoogleFonts.lato(
                    color: _resendTimer > 0
                        ? Colors.grey[500]
                        : Colors.orange[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Verify Button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: otp.length == 6 && !_isVerifying
                  ? _handleVerify
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange[400],
                disabledBackgroundColor: Colors.orange[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isVerifying
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                'Verify OTP',
                style: GoogleFonts.lato(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}