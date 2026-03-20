import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────── Request Model ────────────────────────────────────────────────
class AgentRegistrationRequest {
  final String name;
  final String email;
  final String mobileNumber;
  // final String? alternateNumber; // Commented out for now
  final String password;
  final String? comments;
  final String? agentType;       // 'OWN' | 'PARTNERSHIP'
  final bool? isAdminPermissionRequired;
  final String? hubId;
  final String? startTime;       // 'HH:MM:SS'
  final String? endTime;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? vehicleNumber;
  final String? vehicleType;     // '2_WHEELER' | '4_WHEELER'
  final String? rcNumber;
  final String? licenseNumber;
  // final String? dlExpiryDate;    // Commented out for now
  // Files are handled separately as multipart

  const AgentRegistrationRequest({
    required this.name,
    required this.email,
    required this.mobileNumber,
    // this.alternateNumber,
    required this.password,
    this.comments,
    this.agentType,
    this.isAdminPermissionRequired,
    this.hubId,
    this.startTime,
    this.endTime,
    this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.upiId,
    required this.vehicleNumber,
    required this.vehicleType,
    this.rcNumber,
    this.licenseNumber,
    // this.dlExpiryDate,
  });

  /// Converts to map for multipart form fields
  Map<String, String> toFormFields() {
    final map = <String, String>{
      'name': name,
      'email': email,
      'mobile_number': mobileNumber,
      'password': password,
    };
    // if (alternateNumber != null && alternateNumber!.isNotEmpty)
    //   map['alternate_number'] = alternateNumber!;
    if (comments != null && comments!.isNotEmpty)
      map['comments'] = comments!;
    if (agentType != null)
      map['agent_type'] = agentType!;
    if (isAdminPermissionRequired != null)
      map['is_admin_permission_required'] =
          isAdminPermissionRequired.toString();
    if (hubId != null && hubId!.isNotEmpty)
      map['hub_id'] = hubId!;
    if (startTime != null)
      map['start_time'] = startTime!;
    if (endTime != null)
      map['end_time'] = endTime!;
    if (bankName != null && bankName!.isNotEmpty)
      map['bank_name'] = bankName!;
    if (accountNumber != null && accountNumber!.isNotEmpty)
      map['account_number'] = accountNumber!;
    if (ifscCode != null && ifscCode!.isNotEmpty)
      map['ifsc_code'] = ifscCode!;
    if (upiId != null && upiId!.isNotEmpty)
      map['upi_id'] = upiId!;
    if (vehicleNumber != null && vehicleNumber!.isNotEmpty)
      map['vehicle_number'] = vehicleNumber!;
    if (vehicleType != null && vehicleType!.isNotEmpty)
      map['vehicle_type'] = vehicleType!;
    if (rcNumber != null && rcNumber!.isNotEmpty)
      map['rc_number'] = rcNumber!;
    if (licenseNumber != null && licenseNumber!.isNotEmpty)
      map['license_number'] = licenseNumber!;
    // if (dlExpiryDate != null && dlExpiryDate!.isNotEmpty)
    //   map['dl_expiry_date'] = dlExpiryDate!;
    return map;
  }
}

// ────────────────── Response Models ───────────────────────────────────────────────

class AgentRegistrationResponse {
  final AgentUser user;
  final AgentTokens tokens;
  final Map<String, dynamic> agent;

  const AgentRegistrationResponse({
    required this.user,
    required this.tokens,
    required this.agent,
  });

  factory AgentRegistrationResponse.fromJson(Map<String, dynamic> json) {
    // Check if the response is wrapped in a 'data' key (common in some API frameworks)
    final root = (json['data'] is Map<String, dynamic>) 
        ? json['data'] as Map<String, dynamic> 
        : json;

    final userJson = root['user'] as Map<String, dynamic>?;
    final tokensJson = root['tokens'] as Map<String, dynamic>?;

    if (userJson == null) {
      print('⚠️ API Response missing "user" key: ${root.keys}');
      throw FormatException('Response missing required "user" information');
    }

    if (tokensJson == null) {
      print('⚠️ API Response missing "tokens" key: ${root.keys}');
      // Some APIs return tokens at the root level if not nested
      final access = root['access']?.toString() ?? '';
      final refresh = root['refresh']?.toString() ?? '';
      
      return AgentRegistrationResponse(
        user: AgentUser.fromJson(userJson),
        tokens: AgentTokens(access: access, refresh: refresh),
        agent: root['agent'] as Map<String, dynamic>? ?? {},
      );
    }

    return AgentRegistrationResponse(
      user: AgentUser.fromJson(userJson),
      tokens: AgentTokens.fromJson(tokensJson),
      agent: root['agent'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Save tokens + user info to SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', tokens.access);
    await prefs.setString('refresh_token', tokens.refresh);
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_role', user.role);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_mobile', user.mobileNumber);
    print('✅ Agent registered & tokens saved for: ${user.name}');
  }
}

class AgentUser {
  final String id;
  final String agentId;
  final String name;
  final String email;
  final String mobileNumber;
  final String role;
  final bool isMobileVerified;
  final bool isEmailVerified;
  final String status;
  final String? comments;
  final bool isActive;
  final String? hub;

  const AgentUser({
    required this.id,
    required this.agentId,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.role,
    required this.isMobileVerified,
    required this.isEmailVerified,
    required this.status,
    this.comments,
    required this.isActive,
    this.hub,
  });

  factory AgentUser.fromJson(Map<String, dynamic> json) {
    return AgentUser(
      id: json['id']?.toString() ?? '',
      agentId: json['agent_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      role: json['role']?.toString() ?? 'AGENT',
      isMobileVerified: json['is_mobile_verified'] as bool? ?? false,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      status: json['status']?.toString() ?? 'ACTIVE',
      comments: json['comments']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      hub: json['hub']?.toString(),
    );
  }
}

class AgentTokens {
  final String access;
  final String refresh;

  const AgentTokens({required this.access, required this.refresh});

  factory AgentTokens.fromJson(Map<String, dynamic> json) {
    return AgentTokens(
      access: json['access']?.toString() ?? '',
      refresh: json['refresh']?.toString() ?? '',
    );
  }
}

// ────────────────── Generic API Result wrapper ────────────────────────────────────
class AgentApiResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const AgentApiResult({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory AgentApiResult.success(T data) =>
      AgentApiResult(isSuccess: true, data: data);

  factory AgentApiResult.failure(String error) =>
      AgentApiResult(isSuccess: false, error: error);
}
