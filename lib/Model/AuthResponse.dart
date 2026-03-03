import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'OtpUser.dart';

class AuthResponse {
  final bool success;
  final String message;
  final OtpUser? user;
  final String? accessToken;
  final String? refreshToken;

  const AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.accessToken,
    this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final userJson = data['user'] ?? json['user'];
    final tokensJson = data['tokens'] ?? json['tokens'] ?? json;

    return AuthResponse(
      success: json['success'] == true ||
          data['success'] == true ||
          // ✅ OTP verify success: has user + tokens.access
          (userJson != null && tokensJson['access'] != null),
      message: json['message']?.toString() ??
          data['message']?.toString() ??
          json['detail']?.toString() ??
          '',
      // ✅ Parse using OtpUser.fromJson
      user: userJson != null
          ? OtpUser.fromJson(userJson as Map<String, dynamic>)
          : null,
      accessToken: tokensJson['access']?.toString(),
      refreshToken: tokensJson['refresh']?.toString(),
    );
  }

  Future<bool> saveTokens() async {
    if (accessToken == null || accessToken!.isEmpty) {
      debugPrint("⚠️ No valid access token to save");
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken!);
      if (refreshToken != null && refreshToken!.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken!);
      }
      print("User Have the Value $user");
      print("User Have the user id , '${user!.id}' user full value  $user");
      if (user != null) {
        await prefs.setString('user_id', user!.id);
        await prefs.setString('user_name', user!.name);
        await prefs.setString('user_email', user!.email);
        await prefs.setString('user_mobile', user!.mobileNumber);
        await prefs.setString('user_role', user!.role);
        await prefs.setBool('is_mobile_verified', user!.isMobileVerified);
        await prefs.setBool('is_email_verified', user!.isEmailVerified);
        await prefs.setString('user_status', user!.status);
      }

      if (kDebugMode) {
        final savedAccess = prefs.getString('access_token');
        final savedRefresh = prefs.getString('refresh_token');
        final savedUserId = prefs.getString('user_id');
        debugPrint('✅ Saved access_token : ${savedAccess?.substring(0, 20)}...');
        debugPrint('✅ Saved refresh_token: ${savedRefresh?.substring(0, 20)}...');
        debugPrint('✅ Saved user_id      : $savedUserId');
      }
      return true;
    } catch (e) {
      debugPrint("Failed to save tokens: $e");
      return false;
    }
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('access_token'),
      prefs.remove('refresh_token'),
      prefs.remove('user_id'),
      prefs.remove('user_name'),
      prefs.remove('user_role'),
      prefs.remove('is_logged_in'),
      prefs.remove('is_staff'),
      prefs.remove('is_superuser'),
      prefs.remove('temp_user_address'),
      prefs.remove('user_latitude'),
      prefs.remove('user_longitude'),
    ]);
    debugPrint("🗑️ Auth tokens and temporary location cleared");
  }
}


// API Response/Error Model (for handling success/errors)
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const ApiResponse({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    if (json['name'] != null) { // Success response has user fields
      return ApiResponse<T>(
        isSuccess: true,
        data: fromJson(json),
      );
    } else {
      // Error response (e.g., validation errors)
      String errorMsg = json.entries
          .map((e) => '${e.key}: ${e.value.toString()}')
          .join('\n');
      return ApiResponse<T>(
        isSuccess: false,
        error: errorMsg.isEmpty ? 'Registration failed' : errorMsg,
      );
    }
  }
}