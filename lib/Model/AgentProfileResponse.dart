class AgentProfileResponse {
  final bool success;
  final AgentProfileData agent;

  AgentProfileResponse({
    required this.success,
    required this.agent,
  });

  factory AgentProfileResponse.fromJson(Map<String, dynamic> json) {
    return AgentProfileResponse(
      success: json['success'] ?? false,
      agent: AgentProfileData.fromJson(json['user'] ?? {}),
    );
  }
}

class AgentProfileData {
  final String id;
  final String userId;
  final String userName;
  final AgentUserDetails userDetails;
  final String? aadharDocUrl;
  final String? panCardUrl;
  final String? videoKycUrl;
  final String isPanVerified;
  final String isAadharVerified;
  final String cumulativeRating;
  final String? profileImageUrl;
  final String? startTime;
  final String? endTime;
  final String? agentType;
  final bool isAdminPermissionRequired;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? vehicleType;
  final String? vehicleNumber;

  AgentProfileData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userDetails,
    this.aadharDocUrl,
    this.panCardUrl,
    this.videoKycUrl,
    required this.isPanVerified,
    required this.isAadharVerified,
    required this.cumulativeRating,
    this.profileImageUrl,
    this.startTime,
    this.endTime,
    this.agentType,
    required this.isAdminPermissionRequired,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.vehicleType,
    this.vehicleNumber,
  });

  factory AgentProfileData.fromJson(Map<String, dynamic> json) {
    return AgentProfileData(
      id: json['id']?.toString() ?? '',
      userId: json['user']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      userDetails: AgentUserDetails.fromJson(json['user_details'] ?? {}),
      aadharDocUrl: json['aadhar_doc_url'],
      panCardUrl: json['pan_card_url'],
      videoKycUrl: json['video_kyc_url'],
      isPanVerified: json['is_pan_verified']?.toString() ?? 'PENDING',
      isAadharVerified: json['is_aadhar_verified']?.toString() ?? 'PENDING',
      cumulativeRating: json['cumulative_rating']?.toString() ?? '0.00',
      profileImageUrl: json['profile_image_url'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      agentType: json['agent_type'],
      isAdminPermissionRequired: json['is_admin_permission_required'] ?? false,
      bankName: json['bank_name'],
      accountNumber: json['account_number'],
      ifscCode: json['ifsc_code'],
      upiId: json['upi_id'],
      vehicleType: json['vehicle_type'],
      vehicleNumber: json['vehicle_number'],
    );
  }
}

class AgentUserDetails {
  final String id;
  final String agentId;
  final String name;
  final String email;
  final String mobileNumber;
  final String role;
  final bool isMobileVerified;
  final bool isEmailVerified;
  final String status;
  final bool isStaff;
  final bool isActive;
  final bool isSuperuser;

  AgentUserDetails({
    required this.id,
    required this.agentId,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.role,
    required this.isMobileVerified,
    required this.isEmailVerified,
    required this.status,
    required this.isStaff,
    required this.isActive,
    required this.isSuperuser,
  });

  factory AgentUserDetails.fromJson(Map<String, dynamic> json) {
    return AgentUserDetails(
      id: json['id']?.toString() ?? '',
      agentId: json['agent_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      role: json['role']?.toString() ?? 'AGENT',
      isMobileVerified: json['is_mobile_verified'] ?? false,
      isEmailVerified: json['is_email_verified'] ?? false,
      status: json['status']?.toString() ?? 'PENDING',
      isStaff: json['is_staff'] ?? false,
      isActive: json['is_active'] ?? false,
      isSuperuser: json['is_superuser'] ?? false,
    );
  }
}
