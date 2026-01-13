import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum LoginPhase { phoneInput, otpInput }

class LoginState {
  final LoginPhase phase;
  final bool isLoading;
  final String? error;
  final int resendTimer;
  final String phoneNumber;

  const LoginState({
    this.phase = LoginPhase.phoneInput,
    this.isLoading = false,
    this.error,
    this.resendTimer = 30,
    this.phoneNumber = '',
  });

  LoginState copyWith({
    LoginPhase? phase,
    bool? isLoading,
    String? error,
    int? resendTimer,
    String? phoneNumber,
  }) {
    return LoginState(
      phase: phase ?? this.phase,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable update logic requires care, but for simplicity: pass null to clear
      resendTimer: resendTimer ?? this.resendTimer,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class LoginController extends StateNotifier<LoginState> {
  LoginController() : super(const LoginState());

  Timer? _timer;

  void setPhoneNumber(String number) {
    state = state.copyWith(phoneNumber: number, error: null);
  }

  Future<void> requestOtp() async {
    if (state.phoneNumber.length < 10) {
      state = state.copyWith(error: 'Please enter a valid mobile number');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    
    // Mock API call
    await Future.delayed(const Duration(seconds: 1));

    state = state.copyWith(
      isLoading: false,
      phase: LoginPhase.otpInput,
      resendTimer: 30,
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendTimer > 0) {
        state = state.copyWith(resendTimer: state.resendTimer - 1);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<bool> verifyOtp(String otp) async {
    if (otp.length != 4) {
      state = state.copyWith(error: 'Please enter a valid 4-digit OTP');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    // Mock API call
    await Future.delayed(const Duration(seconds: 1));

    if (otp == '1234') {
      state = state.copyWith(isLoading: false);
      return true; // Success
    } else {
      state = state.copyWith(isLoading: false, error: 'Invalid OTP. Try 1234');
      return false; // Failure
    }
  }
  
  void editPhoneNumber() {
     _timer?.cancel();
     state = state.copyWith(phase: LoginPhase.phoneInput, error: null);
  }

  void resendOtp() {
     state = state.copyWith(resendTimer: 30, error: null);
     _startTimer();
     // Trigger resend API
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final loginProvider = StateNotifierProvider.autoDispose<LoginController, LoginState>((ref) {
  return LoginController();
});
