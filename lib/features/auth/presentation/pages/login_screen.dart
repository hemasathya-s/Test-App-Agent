import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_agent_app/features/dashboard/presentation/pages/home_screen.dart';

import '../../../../Model/LoginRequestModel.dart';
import '../../../../core/services/apiservices.dart';

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

  // ────────────────── Get OTP — calls unifiedLogin(OTP) first, then opens sheet ──
  Future<void> _handleGetOtp(BuildContext pageContext) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final phone = _mobileNumberController.text.trim();

    print('📱 [LoginPage] CONTINUE tapped — phone: $phone');

    final request = LoginRequestModel.otp(
      mobileNumber: int.tryParse(phone) ?? 0,
      role: 'AGENT',
    );

    final result = await ApiService.unifiedLogin(request);

    print('📱 [LoginPage] unifiedLogin — isSuccess: ${result.isSuccess}, error: ${result.error}');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // ✅ Account exists + OTP dispatched — open OTP sheet
      print('✅ [LoginPage] OTP dispatched, opening OTP sheet');
      _showOtpBottomSheet(pageContext);
    } else {
      final error     = result.error ?? '';
      final isNewUser = error.toLowerCase().contains('no account') ||
          error.toLowerCase().contains('not found') ||
          error.toLowerCase().contains('no account found');

      print('❌ [LoginPage] Error: "$error" | isNewUser: $isNewUser');

      if (isNewUser) {
        // ✅ Show snackbar before redirecting
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: Text('No account found for this mobile number. Please create an account.', style: GoogleFonts.lato()),
            backgroundColor: Colors.orange[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        // ✅ No account — redirect to registration using GoRouter
       // context.push('/register', extra: phone);
      } else {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: Text(error, style: GoogleFonts.lato()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showOtpBottomSheet(BuildContext pageContext) {
    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OtpBottomSheet(
        phoneNumber: _mobileNumberController.text.trim(),
        onClose: () => Navigator.of(pageContext).pop(),
        onVerified: () {
          // Use GoRouter to navigate to home, ensuring stack is cleared
          context.go('/home');
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
                    // ────────────────── Header ──────────────────────────────────────
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

                    // ────────────────── Mobile Number ───────────────────────────────
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

                    // ────────────────── Get OTP Button ──────────────────────────────
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

                    // ────────────────── Sign Up Row ─────────────────────────────────
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
                            context.push(
                              '/register',
                              extra: _mobileNumberController.text.trim(),
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
  int _resendTimer  = 30;
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
      if (!mounted) { t.cancel(); return; }
      if (_resendTimer == 0) {
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  // ────────────────── Verify OTP ───────────────────────────────────
  Future<void> _handleVerify() async {
    setState(() { _isVerifying = true; _errorMsg = null; });

    final otp = _otpController.text.trim();
    print('🔍 [OtpSheet] Verifying OTP: $otp for phone: ${widget.phoneNumber}');

    final result = await ApiService.verifyOtp(
      mobileNumber: widget.phoneNumber,
      otp:          otp,
    );

    print('🔍 [OtpSheet] verifyOtp — isSuccess: ${result.isSuccess}, error: ${result.error}');

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.isSuccess) {
      final data = result.data;
      print('✅ [OtpSheet] Verified — user: ${data?.user?.name}, role: ${data?.user?.role}');
      widget.onVerified();
    } else {
      setState(() => _errorMsg = _flattenError(result.error ?? 'Invalid OTP. Try again.'));
      print('âŒ [OtpSheet] Verification failed: $_errorMsg');
    }
  }

  // ────────────────── Resend OTP ───────────────────────────────────
  // âœ… Resend uses sendOtp directly (account already confirmed to exist)
  Future<void> _handleResend() async {
    setState(() { _isResending = true; _errorMsg = null; });

    print('📱 [OtpSheet] Resending OTP to: ${widget.phoneNumber}');

    final result = await ApiService.sendOtp(widget.phoneNumber);

    print('📱 [OtpSheet] Resend — isSuccess: ${result.isSuccess}, error: ${result.error}');

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      setState(() => _errorMsg = _flattenError(result.error ?? 'Failed to resend OTP'));
    }
  }

  String _flattenError(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      return trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final otp = _otpController.text;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ────────────────── Header Row ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                ),
              ),
              Text('Enter OTP',
                  style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 32),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'A 6-digit code was sent to ${widget.phoneNumber}',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // ────────────────── 6 OTP Boxes ─────────────────────────────────
          Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final isFocused = otp.length == index;
                  final isFilled  = otp.length > index;
                  return Container(
                    width: 48, height: 54,
                    decoration: BoxDecoration(
                      color: isFilled ? Colors.orange[50] : Colors.grey[100],
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
                            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller:   _otpController,
                    autofocus:    true,
                    keyboardType: TextInputType.number,
                    maxLength:    6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged:    (_) => setState(() => _errorMsg = null),
                    decoration:   const InputDecoration(counterText: ''),
                  ),
                ),
              ),
            ],
          ),

          // ────────────────── Error Message ───────────────────────────────
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_errorMsg!,
                      style: GoogleFonts.lato(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ────────────────── Resend Row ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't receive code? ",
                  style: GoogleFonts.lato(color: Colors.grey[600])),
              _isResending
                  ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFF9800)))
                  : GestureDetector(
                onTap: _resendTimer == 0 ? _handleResend : null,
                child: Text(
                  _resendTimer > 0
                      ? 'Resend in 00:${_resendTimer.toString().padLeft(2, '0')}'
                      : 'Resend Code',
                  style: GoogleFonts.lato(
                    color: _resendTimer > 0 ? Colors.grey[500] : Colors.orange[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ────────────────── Verify Button ───────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: otp.length == 6 && !_isVerifying ? _handleVerify : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange[400],
                disabledBackgroundColor: Colors.orange[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isVerifying
                  ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Verify OTP',
                  style: GoogleFonts.lato(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
