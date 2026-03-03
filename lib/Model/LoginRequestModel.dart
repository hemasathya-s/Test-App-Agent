class LoginRequestModel {
  final String loginType; // 'PASSWORD' | 'OTP'
  final String role;
  final String? username;
  final String? password;
  final int? mobileNumber;
  final String deviceType;
  final String deviceId;
  final String deviceName;
  final String ipAddress;

  const LoginRequestModel({
    required this.loginType,
    this.role = 'CUSTOMER',
    this.username,
    this.password,
    this.mobileNumber,
    this.deviceType = 'ANDROID',
    this.deviceId = 'string',
    this.deviceName = 'string',
    this.ipAddress = 'string',
  });

  factory LoginRequestModel.password({
    required String username,
    required String password,
    String role = 'CUSTOMER',
    String deviceType = 'ANDROID',
    String deviceId = 'string',
    String deviceName = 'string',
    String ipAddress = 'string',
  }) {
    return LoginRequestModel(
      loginType: 'PASSWORD',
      role: role,
      username: username,
      password: password,
      mobileNumber: 0,
      deviceType: deviceType,
      deviceId: deviceId,
      deviceName: deviceName,
      ipAddress: ipAddress,
    );
  }

  factory LoginRequestModel.otp({
    required int mobileNumber,
    String role = 'CUSTOMER',
    String deviceType = 'ANDROID',
    String deviceId = 'string',
    String deviceName = 'string',
    String ipAddress = 'string',
  }) {
    return LoginRequestModel(
      loginType: 'OTP',
      role: role,
      username: '',
      password: '',
      mobileNumber: mobileNumber,
      deviceType: deviceType,
      deviceId: deviceId,
      deviceName: deviceName,
      ipAddress: ipAddress,
    );
  }

  Map<String, dynamic> toJson() => {
    'login_type': loginType,
    'role': role,
    'username': username ?? '',
    'password': password ?? '',
    'mobile_number': mobileNumber ?? 0,
    'device_type': deviceType,
    'device_id': deviceId,
    'device_name': deviceName,
    'ip_address': ipAddress,
  };

  Map<String, String> toFormJson() {
    final Map<String, String> data = {
      'login_type': loginType,
      'role': role,
      'device_type': deviceType,
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
    };

    if (loginType == 'PASSWORD') {
      data['username'] = username ?? '';
      data['password'] = password ?? '';
    } else if (loginType == 'OTP') {
      data['mobile_number'] = (mobileNumber ?? 0).toString();
    }

    return data;
  }
}