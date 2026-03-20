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
  final String? rcDocumentUrl;
  final String? licenseDocumentUrl;
  final String? profileImageUrl;

  final String? rcNumber;
  final String? licenseNumber;

  final String isPanVerified;
  final String isAadharVerified;
  final String isVideoKycVerified;
  final String isRcVerified;
  final String isLicenseVerified;

  final String cumulativeRating;
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

  // Raw model IDs — useful if you need to reference them later
  final String? aadharDocModelId;
  final String? panCardModelId;
  final String? videoKycModelId;
  final String? rcDocModelId;
  final String? licenseDocModelId;

  AgentProfileData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userDetails,
    this.aadharDocUrl,
    this.panCardUrl,
    this.videoKycUrl,
    this.rcDocumentUrl,
    this.licenseDocumentUrl,
    this.profileImageUrl,
    this.rcNumber,
    this.licenseNumber,
    required this.isPanVerified,
    required this.isAadharVerified,
    required this.isVideoKycVerified,
    required this.isRcVerified,
    required this.isLicenseVerified,
    required this.cumulativeRating,
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
    this.aadharDocModelId,
    this.panCardModelId,
    this.videoKycModelId,
    this.rcDocModelId,
    this.licenseDocModelId,
  });

  static String? _ensureAbsoluteUrl(dynamic url) {
    if (url == null) return null;
    final urlStr = url.toString().trim();
    if (urlStr.isEmpty || urlStr == 'null') return null;
    if (urlStr.startsWith('http')) return urlStr;
    const baseUrl = 'https://api.itfixer199.com';
    return urlStr.startsWith('/') ? '$baseUrl$urlStr' : '$baseUrl/$urlStr';
  }

  factory AgentProfileData.fromJson(Map<String, dynamic> json) {
    // Safely extract agent_details — default to empty map if missing
    final agentDetails = (json['agent_details'] is Map)
        ? json['agent_details'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AgentProfileData(
      id: json['id']?.toString() ?? '',
      userId: json['id']?.toString() ?? '',
      userName: json['name']?.toString() ?? '',
      userDetails: AgentUserDetails.fromJson(json),

      // ── Document URLs ──────────────────────────────────────────────
      // API uses: aadhar_doc_url, pan_card_url, video_kyc_url,
      //           rc_doc_url, license_doc_url
      aadharDocUrl: _ensureAbsoluteUrl(agentDetails['aadhar_doc_url']),
      panCardUrl: _ensureAbsoluteUrl(agentDetails['pan_card_url']),
      videoKycUrl: _ensureAbsoluteUrl(agentDetails['video_kyc_url']),

      // rc and license — API sends rc_doc_url / license_doc_url
      // fallback keys kept for safety
      rcDocumentUrl: _ensureAbsoluteUrl(
        agentDetails['rc_doc_url'] ??
            agentDetails['rc_document_url'] ??
            agentDetails['rc_doc'] ??
            json['rc_doc_url'] ??
            json['rc_document_url'] ??
            json['rc_doc'],
      ),
      licenseDocumentUrl: _ensureAbsoluteUrl(
        agentDetails['license_doc_url'] ??
            agentDetails['license_document_url'] ??
            agentDetails['license_doc'] ??
            json['license_doc_url'] ??
            json['license_document_url'] ??
            json['license_doc'],
      ),

      // Profile image can be at top level or inside agent_details
      profileImageUrl: _ensureAbsoluteUrl(
        json['profile_image_url'] ??
            agentDetails['profile_image_url'],
      ),

      // ── Document model IDs ─────────────────────────────────────────
      aadharDocModelId: agentDetails['aadhar_doc_url_model_id']?.toString(),
      panCardModelId: agentDetails['pan_card_url_model_id']?.toString(),
      videoKycModelId: agentDetails['video_kyc_url_model_id']?.toString(),
      rcDocModelId: agentDetails['rc_doc_url_model_id']?.toString(),
      licenseDocModelId: agentDetails['license_doc_url_model_id']?.toString(),

      // ── Numbers ────────────────────────────────────────────────────
      rcNumber: agentDetails['rc_number']?.toString(),
      licenseNumber: agentDetails['license_number']?.toString(),

      // ── Verification statuses ──────────────────────────────────────
      isPanVerified:
      agentDetails['is_pan_verified']?.toString() ?? 'PENDING',
      isAadharVerified:
      agentDetails['is_aadhar_verified']?.toString() ?? 'PENDING',
      isVideoKycVerified:
      agentDetails['is_video_kyc_verified']?.toString() ?? 'PENDING',
      isRcVerified: agentDetails['is_rc_verified']?.toString() ?? 'PENDING',
      isLicenseVerified: agentDetails['is_license_verified']?.toString() ?? 'PENDING',

      // ── Other agent details ────────────────────────────────────────
      cumulativeRating:
      agentDetails['cumulative_rating']?.toString() ?? '0.00',
      startTime: agentDetails['start_time']?.toString(),
      endTime: agentDetails['end_time']?.toString(),
      agentType: agentDetails['agent_type']?.toString(),
      isAdminPermissionRequired:
      agentDetails['is_admin_permission_required'] == true,
      bankName: agentDetails['bank_name']?.toString(),
      accountNumber: agentDetails['account_number']?.toString(),
      ifscCode: agentDetails['ifsc_code']?.toString(),
      upiId: agentDetails['upi_id']?.toString(),
      vehicleType: agentDetails['vehicle_type']?.toString(),
      vehicleNumber: agentDetails['vehicle_number']?.toString(),
    );
  }
}

class AgentUserDetails {
  final String id;
  final String name;
  final String email;
  final String mobileNumber;
  final String role;
  final bool isMobileVerified;
  final bool isEmailVerified;
  final String status;
  final String? comments;
  final bool isStaff;
  final bool isActive;
  final bool isSuperuser;
  final String? dateJoined;
  final String? hubId;

  AgentUserDetails({
    required this.id,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.role,
    required this.isMobileVerified,
    required this.isEmailVerified,
    required this.status,
    this.comments,
    required this.isStaff,
    required this.isActive,
    required this.isSuperuser,
    this.dateJoined,
    this.hubId,
  });

  factory AgentUserDetails.fromJson(Map<String, dynamic> json) {
    return AgentUserDetails(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      role: json['role']?.toString() ?? 'AGENT',
      isMobileVerified: json['is_mobile_verified'] == true,
      isEmailVerified: json['is_email_verified'] == true,
      status: json['status']?.toString() ?? 'PENDING',
      comments: json['comments']?.toString(),
      isStaff: json['is_staff'] == true,
      isActive: json['is_active'] == true,
      isSuperuser: json['is_superuser'] == true,
      dateJoined: json['date_joined']?.toString(),
      hubId: json['hub_id']?.toString(),
    );
  }
}
