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
    final details = json['agent_details'] as Map<String, dynamic>? ?? {};
    
    String? profileUrl = details['profile_image_url']?.toString();
    if (profileUrl != null && profileUrl.startsWith('/')) {
      profileUrl = 'https://api.itfixer199.com$profileUrl';
    }

    return AgentProfileData(
      id: details['agent_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['id']?.toString() ?? '', 
      userName: json['name']?.toString() ?? '',
      userDetails: AgentUserDetails.fromJson(json),
      aadharDocUrl: details['aadhar_doc_url'],
      panCardUrl: details['pan_card_url'],
      videoKycUrl: details['video_kyc_url'],
      isPanVerified: details['is_pan_verified']?.toString() ?? 'PENDING',
      isAadharVerified: details['is_aadhar_verified']?.toString() ?? 'PENDING',
      cumulativeRating: details['cumulative_rating']?.toString() ?? '0.00',
      profileImageUrl: profileUrl,
      startTime: details['start_time'],
      endTime: details['end_time'],
      agentType: details['agent_type'],
      isAdminPermissionRequired: details['is_admin_permission_required'] ?? false,
      bankName: details['bank_name'],
      accountNumber: details['account_number'],
      ifscCode: details['ifsc_code'],
      upiId: details['upi_id'],
      vehicleType: details['vehicle_type'],
      vehicleNumber: details['vehicle_number'],
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
    final details = json['agent_details'] as Map<String, dynamic>? ?? {};
    
    return AgentUserDetails(
      id: json['id']?.toString() ?? '',
      agentId: details['agent_id']?.toString() ?? '',
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
