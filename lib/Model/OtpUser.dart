// ── SEND OTP REQUEST MODEL ────────────────────────────────────────────────
class SendOtpRequest {
  final int mobileNumber;
  final String role;

  const SendOtpRequest({
    required this.mobileNumber,
    this.role = 'CUSTOMER',
  });

  Map<String, dynamic> toJson() => {
    'mobile_number': mobileNumber,
    'role': role,
  };
}


class OtpUser {
  final String id;
  final String name;
  final String email;
  final String mobileNumber;
  final String role;
  final bool isMobileVerified;
  final bool isEmailVerified;
  final String status;

  OtpUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.role,
    required this.isMobileVerified,
    required this.isEmailVerified,
    required this.status,
  });

  factory OtpUser.fromJson(Map<String, dynamic> json) {
    return OtpUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      role: json['role'] ?? '',
      isMobileVerified: json['is_mobile_verified'] ?? false,
      isEmailVerified: json['is_email_verified'] ?? false,
      status: json['status'] ?? '',
    );
  }
}

class OtpTokens {
  final String access;
  final String refresh;

  OtpTokens({required this.access, required this.refresh});

  factory OtpTokens.fromJson(Map<String, dynamic> json) {
    return OtpTokens(
      access: json['access'] ?? '',
      refresh: json['refresh'] ?? '',
    );
  }
}

class VerifyOtpResponse {
  final bool success;
  final String message;
  final List<String> errors;
  final OtpUser? user;
  final OtpTokens? tokens;

  VerifyOtpResponse({
    required this.success,
    required this.message,
    this.errors = const [],
    this.user,
    this.tokens,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    // Success response has 'user' and 'tokens'
    if (json.containsKey('user') && json.containsKey('tokens')) {
      return VerifyOtpResponse(
        success: true,
        message: 'Login successful',
        user: OtpUser.fromJson(json['user']),
        tokens: OtpTokens.fromJson(json['tokens']),
      );
    }
    // Error response
    return VerifyOtpResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      errors: List<String>.from(json['errors'] ?? []),
    );
  }
}