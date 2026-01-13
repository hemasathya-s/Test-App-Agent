import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/login_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
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
}
