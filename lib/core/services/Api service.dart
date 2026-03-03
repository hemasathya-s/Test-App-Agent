import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Model/AgentRegistrationRequest.dart';
import '../../Model/AuthResponse.dart';
import '../../Model/AgentProfileResponse.dart';
import '../../Model/LoginRequestModel.dart';
import '../../Model/OtpUser.dart';

class ApiService
{
  static const String _baseUrl = 'https://api.itfixer199.com';

  Future<ApiResponse<AuthResponse>> unifiedLogin(LoginRequestModel request) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final LoginRequestModel finalRequest;

      if (request.loginType == 'PASSWORD') {
        finalRequest = LoginRequestModel.password(
          username: request.username ?? '',
          password: request.password ?? '',
          role: request.role,
          deviceType: Platform.isAndroid ? 'ANDROID' : 'IOS',
          deviceId: deviceInfo['device_id'] ?? 'unknown',
          deviceName: deviceInfo['device_name'] ?? 'unknown',
          ipAddress: '0.0.0.0',
        );
      } else {
        finalRequest = LoginRequestModel.otp(
          mobileNumber: request.mobileNumber ?? 0,
          role: request.role,
          deviceType: Platform.isAndroid ? 'ANDROID' : 'IOS',
          deviceId: deviceInfo['device_id'] ?? 'unknown',
          deviceName: deviceInfo['device_name'] ?? 'unknown',
          ipAddress: '0.0.0.0',
        );
      }

      print('🔐 [UnifiedLogin] login_type : ${finalRequest.loginType}');
      print('🔐 [UnifiedLogin] role       : ${finalRequest.role}');
      print('🔐 [UnifiedLogin] Request body: ${finalRequest.toFormJson()}');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/unified-login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'accept': 'application/json',
        },
        body: finalRequest.toFormJson(),
      ).timeout(const Duration(seconds: 15));

      print('🔐 [UnifiedLogin] Status Code : ${response.statusCode}');
      print('🔐 [UnifiedLogin] Response    : ${response.body}');

      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json);
        await authResponse.saveTokens();
        print('✅ [UnifiedLogin] Success — user: ${authResponse.user?.name}');
        return ApiResponse(isSuccess: true, data: authResponse);
      }

      final errors = json['errors'] as List<dynamic>?;
      final errorMsg = (errors?.isNotEmpty == true)
          ? errors!.first.toString()
          : json['message']?.toString() ?? 'Login failed';

      print('❌ [UnifiedLogin] Failed — error: $errorMsg');
      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException catch (e) {
      print('❌ [UnifiedLogin] SocketException: $e');
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException catch (e) {
      print('❌ [UnifiedLogin] TimeoutException: $e');
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e) {
      print('❌ [UnifiedLogin] Exception: $e');
      return ApiResponse(isSuccess: false, error: 'Something went wrong');
    }
  }


  Future<ApiResponse<String>> sendOtp(String mobileNumber) async {
    try {
      final request = SendOtpRequest(
        mobileNumber: int.tryParse(mobileNumber) ?? 0,
        role: 'AGENT',
      );

      print('📲 [SendOtp] Request body  : ${jsonEncode(request.toJson())}');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 15));

      print('📲 [SendOtp] Status Code   : ${response.statusCode}');
      print('📲 [SendOtp] Response      : ${response.body}');

      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final msg = json['message']?.toString() ?? 'OTP sent successfully';
        print('✅ [SendOtp] Success — $msg');
        return ApiResponse(isSuccess: true, data: msg);
      }

      final errors   = json['errors'] as List<dynamic>?;
      final errorMsg = (errors?.isNotEmpty == true)
          ? errors!.first.toString()
          : json['message']?.toString() ?? 'Failed to send OTP';

      print('❌ [SendOtp] Failed [${response.statusCode}] — $errorMsg');
      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException catch (e) {
      print('❌ [SendOtp] SocketException: $e');
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException catch (e) {
      print('❌ [SendOtp] TimeoutException: $e');
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e) {
      print('❌ [SendOtp] Exception: $e');
      return ApiResponse(isSuccess: false, error: 'Something went wrong');
    }
  }

  // ── VERIFY OTP ────────────────────────────────────────────────────────────
  Future<ApiResponse<VerifyOtpResponse>> verifyOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final body = {
        'mobile_number': mobileNumber,
        'otp':           otp,
        'login_type':    'OTP',
        'role':          'AGENT',
        'device_type':   Platform.isAndroid ? 'ANDROID' : 'IOS',
        'device_id':     deviceInfo['device_id'] ?? 'unknown',
        'device_name':   deviceInfo['device_name'] ?? 'unknown',
        'ip_address':    '0.0.0.0',
      };

      print('📲 [VerifyOtp] Request body : $body');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'accept':       'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      print('📲 [VerifyOtp] Status Code  : ${response.statusCode}');
      print('📲 [VerifyOtp] Raw Response : ${response.body}');

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // ── Deep debug: print every top-level key and its type ──────────
        print('📲 [VerifyOtp] Top-level keys:');
        json.forEach((k, v) => print('   "$k" → ${v.runtimeType} = $v'));

        // ── Try to locate user/token data at any nesting level ───────────
        // Pattern A: { "user": {...}, "tokens": {...} }  ← direct
        // Pattern B: { "data": { "user": {...}, "tokens": {...} } }
        // Pattern C: { "access": "...", "refresh": "..." , "user": {...} }

        Map<String, dynamic>? userMap;
        Map<String, dynamic>? tokensMap;

        if (json.containsKey('tokens') && json['tokens'] is Map) {
          // Pattern A
          tokensMap = Map<String, dynamic>.from(json['tokens'] as Map);
        } else if (json.containsKey('access') && json.containsKey('refresh')) {
          // Pattern C — tokens are flat at root
          tokensMap = {
            'access':  json['access'],
            'refresh': json['refresh'],
          };
        } else if (json.containsKey('data') && json['data'] is Map) {
          // Pattern B — nested under 'data'
          final data = Map<String, dynamic>.from(json['data'] as Map);
          if (data.containsKey('tokens') && data['tokens'] is Map) {
            tokensMap = Map<String, dynamic>.from(data['tokens'] as Map);
          } else if (data.containsKey('access')) {
            tokensMap = {'access': data['access'], 'refresh': data['refresh']};
          }
          if (data.containsKey('user') && data['user'] is Map) {
            userMap = Map<String, dynamic>.from(data['user'] as Map);
          }
        }

        if (userMap == null && json.containsKey('user') && json['user'] is Map) {
          userMap = Map<String, dynamic>.from(json['user'] as Map);
        }

        print('📲 [VerifyOtp] Resolved tokensMap : $tokensMap');
        print('📲 [VerifyOtp] Resolved userMap   : $userMap');

        if (tokensMap != null) {
          final tokens = OtpTokens.fromJson(tokensMap);
          final user   = userMap != null ? OtpUser.fromJson(userMap) : null;

          final verifyResponse = VerifyOtpResponse(
            success: true,
            message: json['message']?.toString() ?? 'Login successful',
            user:    user,
            tokens:  tokens,
          );

          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token',  tokens.access);
          await prefs.setString('refresh_token', tokens.refresh);

          if (user != null) {
            await prefs.setString('user_id',     user.id);
            await prefs.setString('user_name',   user.name);
            await prefs.setString('user_email',  user.email);
            await prefs.setString('user_mobile', user.mobileNumber);
            await prefs.setString('user_role',   user.role);
            await prefs.setBool('is_mobile_verified', user.isMobileVerified);
            await prefs.setBool('is_email_verified',  user.isEmailVerified);
            await prefs.setString('user_status', user.status);
          }

          print('✅ [VerifyOtp] Success — user: ${user?.name}, role: ${user?.role}');
          print('✅ [VerifyOtp] access_token saved: ${tokens.access}');
          return ApiResponse(isSuccess: true, data: verifyResponse);
        }

        // Still null after all patterns — full dump for diagnosis
        print('⚠️ [VerifyOtp] Could not resolve tokens from 200 response.');
        print('⚠️ [VerifyOtp] Full JSON dump: $json');
        return ApiResponse(isSuccess: false, error: 'Failed to parse response');
      }

      // Non-200 — handle List or Map errors shape
      final rawErrors = json['errors'];
      String errorMsg;
      if (rawErrors is List && rawErrors.isNotEmpty) {
        errorMsg = rawErrors.first.toString();
      } else if (rawErrors is Map && rawErrors.isNotEmpty) {
        errorMsg = rawErrors.values.first.toString();
      } else {
        errorMsg = json['message']?.toString() ?? 'OTP verification failed';
      }

      print('❌ [VerifyOtp] Failed [${response.statusCode}] — $errorMsg');
      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException catch (e) {
      print('❌ [VerifyOtp] SocketException: $e');
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException catch (e) {
      print('❌ [VerifyOtp] TimeoutException: $e');
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e, stack) {
      print('❌ [VerifyOtp] Exception: $e');
      print('❌ [VerifyOtp] Stack: $stack');
      return ApiResponse(isSuccess: false, error: 'Something went wrong');
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return {
          'device_id': info.id,
          'device_name': '${info.manufacturer} ${info.model}',
        };
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return {
          'device_id': info.identifierForVendor ?? 'unknown',
          'device_name': info.name,
        };
      }
    } catch (e) {
      print('⚠️ Device info error: $e');
    }
    return {'device_id': 'unknown', 'device_name': 'unknown'};
  }

//   Future<AgentApiResult<AgentRegistrationResponse>> registerAgent({
//     required AgentRegistrationRequest request,
//     File? profileImage,
//     File? aadharDoc,
//     File? panCard,
//     File? videoKyc,
//   }) async {
//     try {
//       print('📝 Registering agent: ${request.name}');
//
//       final uri = Uri.parse('$_baseUrl/api/user/agent'); // 👈 update endpoint if different
//
//       final multipartRequest = http.MultipartRequest('POST', uri)
//         ..headers.addAll({
//           'accept': 'application/json',
//         });
//
//       // Add all text fields
//       multipartRequest.fields.addAll(request.toFormFields());
//
//       // Add files if provided
//       if (profileImage != null) {
//         multipartRequest.files.add(await http.MultipartFile.fromPath(
//           'profile_image',
//           profileImage.path,
//           contentType: http.MediaType('image', _fileExtension(profileImage.path)),
//         ));
//       }
//       if (aadharDoc != null) {
//         multipartRequest.files.add(await http.MultipartFile.fromPath(
//           'aadhar_doc',
//           aadharDoc.path,
//           contentType: http.MediaType('image', _fileExtension(aadharDoc.path)),
//         ));
//       }
//       if (panCard != null) {
//         multipartRequest.files.add(await http.MultipartFile.fromPath(
//           'pan_card',
//           panCard.path,
//           contentType: http.MediaType('image', _fileExtension(panCard.path)),
//         ));
//       }
//       if (videoKyc != null) {
//         multipartRequest.files.add(await http.MultipartFile.fromPath(
//           'video_kyc',
//           videoKyc.path,
//           contentType: http.MediaType('video', 'mp4'),
//         ));
//       }
//
//       print('📝 Fields: ${multipartRequest.fields}');
//       print('📝 Files: ${multipartRequest.files.map((f) => f.field).toList()}');
//
//       final streamedResponse = await multipartRequest
//           .send()
//           .timeout(const Duration(seconds: 30));
//
//       final response = await http.Response.fromStream(streamedResponse);
//
//       print('📝 Register Agent [${response.statusCode}]: ${response.body}');
//
//       final json = jsonDecode(response.body);
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final result = AgentRegistrationResponse.fromJson(json);
//         await result.saveToPrefs(); // ✅ saves tokens automatically
//         return AgentApiResult.success(result);
//       }
//
//       // Parse error from response
//       final errors = json['errors'] as List<dynamic>?;
//       final errorMsg = (errors?.isNotEmpty == true)
//           ? errors!.first.toString()
//           : json['message']?.toString() ??
//           json['detail']?.toString() ??
//           'Registration failed';
//
//       return AgentApiResult.failure(errorMsg);
//
//     } on SocketException {
//       return AgentApiResult.failure('No internet connection');
//     } on TimeoutException {
//       return AgentApiResult.failure('Request timed out. Please try again.');
//     } catch (e) {
//       print('❌ registerAgent error: $e');
//       return AgentApiResult.failure('Something went wrong. Please try again.');
//     }
//   }
//
// // Helper inside ApiService
//   String _fileExtension(String path) {
//     final ext = path.split('.').last.toLowerCase();
//     if (ext == 'jpg' || ext == 'jpeg') return 'jpeg';
//     if (ext == 'png') return 'png';
//     return 'jpeg'; // default
//   }



  Future<AgentApiResult<AgentRegistrationResponse>> registerAgent({
    required AgentRegistrationRequest request,
    File? profileImage,
    File? aadharDoc,
    File? panCard,
    File? videoKyc,
  }) async {
    try {
      print('📝 Registering agent: ${request.name}');

      final uri = Uri.parse('$_baseUrl/api/user/agent');

      final multipartRequest = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'accept': 'application/json',
        });

      // Add all text fields
      multipartRequest.fields.addAll(request.toFormFields());

      // Add files
      if (profileImage != null) {
        final ext = _fileExtension(profileImage.path);
        multipartRequest.files.add(await http.MultipartFile.fromPath(
          'profile_image',
          profileImage.path,
          contentType: http.MediaType('image', ext),
        ));
      }
      if (aadharDoc != null) {
        final ext = _fileExtension(aadharDoc.path);
        multipartRequest.files.add(await http.MultipartFile.fromPath(
          'aadhar_doc',
          aadharDoc.path,
          contentType: http.MediaType('image', ext),
        ));
      }
      if (panCard != null) {
        final ext = _fileExtension(panCard.path);
        multipartRequest.files.add(await http.MultipartFile.fromPath(
          'pan_card',
          panCard.path,
          contentType: http.MediaType('image', ext),
        ));
      }
      if (videoKyc != null) {
        multipartRequest.files.add(await http.MultipartFile.fromPath(
          'video_kyc',
          videoKyc.path,
          contentType: http.MediaType('video', 'mp4'),
        ));
      }

      print('📡 Sending to: $uri');
      print('📡 Fields: ${multipartRequest.fields}');
      
      // Log file sizes for debugging
      for (var file in multipartRequest.files) {
        final length = file.length;
        print('📡 File: ${file.field} (${file.contentType}) - Size: $length bytes');
      }

      final streamedResponse = await multipartRequest
          .send()
          .timeout(
        const Duration(seconds: 300), // Increased to 5 minutes
        onTimeout: () {
          print('❌ TIMEOUT: $uri did not respond in 300s. Possible slow connection or large files.');
          throw TimeoutException('Request timed out. Please check your internet connection or try with smaller files.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Status: ${response.statusCode}');
      print('📡 Body: ${response.body}');

      if (response.body.isEmpty) {
        return AgentApiResult.failure('Server returned empty response');
      }

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (json is Map) {
          print('📡 Success Body Keys: ${json.keys}');
          if (json['data'] != null && json['data'] is Map) {
             print('📡 Nested data keys: ${(json['data'] as Map).keys}');
          }
        }
        final result = AgentRegistrationResponse.fromJson(json);
        await result.saveToPrefs();
        print('✅ Agent registered: ${result.user.name}');
        return AgentApiResult.success(result);
      }

      // ✅ Parse all Django/DRF error formats
      String errorMsg = 'Registration failed (${response.statusCode})';

      if (json is Map) {
        if (json['errors'] != null) {
          final errors = json['errors'];
          if (errors is List && errors.isNotEmpty) {
            errorMsg = errors.first.toString();
          } else if (errors is Map && errors.isNotEmpty) {
            final key = errors.keys.first;
            final val = errors[key];
            errorMsg = val is List ? '$key: ${val.first}' : '$key: $val';
          }
        } else if (json['message'] != null) {
          errorMsg = json['message'].toString();
        } else if (json['detail'] != null) {
          errorMsg = json['detail'].toString();
        } else if (json.isNotEmpty) {
          // Django field-level errors e.g. {"email": ["already exists"]}
          final key = json.keys.first;
          final val = json[key];
          errorMsg = val is List ? '$key: ${val.first}' : '$key: $val';
        }
      }

      print('❌ API Error [${ response.statusCode}]: $errorMsg');
      return AgentApiResult.failure(errorMsg);

    } on SocketException catch (e) {
      print('❌ SocketException: $e');
      return AgentApiResult.failure('No internet connection. Check your network.');
    } on TimeoutException catch (e) {
      print('❌ TimeoutException: $e');
      return AgentApiResult.failure('Request timed out. Please try again.');
    } catch (e, stack) {
      print('❌ registerAgent error: $e');
      print('❌ Stack: $stack');
      return AgentApiResult.failure('Something went wrong. Please try again.');
    }
  }

  Future<ApiResponse<AgentProfileResponse>> getAgentProfile() async {
    try {
      final response = await _authorizedRequest((token) => http.get(
            Uri.parse('$_baseUrl/api/user/my-details'),
            headers: {
              'Authorization': 'Bearer $token',
              'accept': 'application/json',
            },
          ));

      print('📡 Get Profile [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResponse(
          isSuccess: true,
          data: AgentProfileResponse.fromJson(json),
        );
      }

      final json = jsonDecode(response.body);
      return ApiResponse(
        isSuccess: false,
        error: json['message']?.toString() ?? 'Failed to fetch profile',
      );
    } catch (e) {
      print('❌ getAgentProfile error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  /// PUT /api/user/agent/{userId}
  Future<AgentApiResult<bool>> updateAgentProfile(
      String userId,
      Map<String, dynamic> updatedData, {
        File? profileImage,
      }) async {
    try {
      print('✏️ Updating agent profile: $userId');
      print('✏️ Data: $updatedData');

      final token = await _getAccessToken();
      if (token == null) {
        return AgentApiResult.failure('Not authenticated. Please login again.');
      }

      final uri = Uri.parse('$_baseUrl/api/user/agent/$userId');
      
      // We use MultipartRequest if an image is provided, otherwise a standard PUT
      if (profileImage != null) {
        final request = http.MultipartRequest('PUT', uri)
          ..headers.addAll({
            'accept': 'application/json',
            'Authorization': 'Bearer $token',
          });

        // Add text fields
        updatedData.forEach((key, value) {
          request.fields[key] = value.toString();
        });

        // Add profile image
        final ext = _fileExtension(profileImage.path);
        request.files.add(await http.MultipartFile.fromPath(
          'profile_image',
          profileImage.path,
          contentType: http.MediaType('image', ext),
        ));

        print('📡 Sending Multipart PUT to: $uri');
        final streamedResponse = await request.send().timeout(const Duration(seconds: 300));
        final response = await http.Response.fromStream(streamedResponse);
        return _handleUpdateResponse(response);
      } else {
        // Standard JSON PUT
        final response = await http.put(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(updatedData),
        ).timeout(const Duration(seconds: 30));
        return _handleUpdateResponse(response);
      }
    } on SocketException {
      return AgentApiResult.failure('No internet connection');
    } on TimeoutException {
      return AgentApiResult.failure('Request timed out. Please try again.');
    } catch (e, stack) {
      print('❌ updateAgentProfile error: $e\n$stack');
      return AgentApiResult.failure('Something went wrong. Please try again.');
    }
  }

  AgentApiResult<bool> _handleUpdateResponse(http.Response response) {
    print('✏️ Update Profile Status: ${response.statusCode}');
    
    if (response.statusCode == 200 || response.statusCode == 204) {
      return AgentApiResult.success(true);
    }

    if (response.body.isEmpty) {
      return AgentApiResult.failure('Server returned status ${response.statusCode} with no body');
    }

    // Safe JSON decoding
    dynamic json;
    try {
      json = jsonDecode(response.body);
    } catch (e) {
      print('❌ Failed to decode response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      return AgentApiResult.failure('Server error (${response.statusCode}). Please contact support.');
    }

    // Parse Django/DRF error formats
    String errorMsg = 'Update failed (${response.statusCode})';
    if (json is Map) {
      if (json['message'] != null) {
        errorMsg = json['message'].toString();
      } else if (json['detail'] != null) {
        errorMsg = json['detail'].toString();
      } else if (json['errors'] != null) {
        final errors = json['errors'];
        if (errors is List && errors.isNotEmpty) {
          errorMsg = errors.first.toString();
        } else if (errors is Map && errors.isNotEmpty) {
          final key = errors.keys.first;
          final val = errors[key];
          errorMsg = val is List ? '$key: ${val.first}' : '$key: $val';
        }
      } else if (json.isNotEmpty) {
        final key = json.keys.first;
        final val = json[key];
        errorMsg = val is List ? '$key: ${val.first}' : '$key: $val';
      }
    }

    print('❌ Update Error: $errorMsg');
    return AgentApiResult.failure(errorMsg);
  }

  Future<AgentApiResult<bool>> logoutUser() async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local tokens are cleared
        await AuthResponse.clearTokens();
        return AgentApiResult.success(true);
      }

      print('📡 Logging out user: $userId');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/logout/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 15));

      print('📡 Logout Status: ${response.statusCode}');

      // Clear tokens regardless of server response success
      await AuthResponse.clearTokens();

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AgentApiResult.success(true);
      } else {
        // Return success anyway because local session is cleared, 
        // but maybe log the error
        print('⚠️ Server logout failed but local tokens cleared: ${response.body}');
        return AgentApiResult.success(true);
      }
    } catch (e) {
      print('❌ logoutUser error: $e');
      // Still clear tokens locally on error
      await AuthResponse.clearTokens();
      return AgentApiResult.failure('Network error: ${e.toString()}');
    }
  }
// ── Helpers ───────────────────────────────────────────────────────────────────

  String _fileExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'jpeg';
    if (ext == 'png') return 'png';
    if (ext == 'pdf') return 'pdf';
    return 'jpeg'; // safe default
  }

  // ── Token Management Helpers ───────────────────────────────────────────────

  // Helper: Get access token
  Future<String?> getAccessTokenLocal() async {
    return _getAccessToken();
  }

  // Helper: Get access token
  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    print('🔎 Getting Access Token: $token');
    return token;
  }

  // Helper: Get refresh token
  static Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('refresh_token');
    print('🔎 Getting Refresh Token: $token');
    return token;
  }

  // Helper: Clear all tokens (calls AuthResponse.clearTokens())
  static Future<void> _clearTokens() async {
    await AuthResponse.clearTokens();
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await _getRefreshToken();
    print('🔄 Refresh Token Used: $refreshToken');

    if (refreshToken == null) {
      print('❌ No refresh token found');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh': refreshToken,
        }),
      );

      print('🔁 Refresh Status: ${response.statusCode}');
      print('🔁 Refresh Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('access_token', jsonData['access']);
        print('✅ New Access Token Saved: ${jsonData['access']}');

        if (jsonData['refresh'] != null) {
          await prefs.setString('refresh_token', jsonData['refresh']);
          print('✅ New Refresh Token Saved: ${jsonData['refresh']}');
        }

        return true;
      } else {
        print('❌ Refresh failed. Clearing tokens.');
        await _clearTokens();
        return false;
      }
    } catch (e) {
      print('❌ Refresh Exception: $e');
      return false;
    }
  }

  static Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(String token) request,
  ) async {
    String? token = await _getAccessToken();
    print('📡 Authorized Request Using Token: $token');

    if (token == null) {
      throw Exception('No access token');
    }

    http.Response response = await request(token);
    print('📡 Response Status: ${response.statusCode}');

    if (response.statusCode == 401) {
      print('⚠️ Token expired. Trying refresh...');
      final refreshed = await _refreshAccessToken();

      if (!refreshed) {
        print('❌ Refresh failed. Clearing tokens.');
        await _clearTokens();
        throw Exception('Session expired');
      }

      token = await _getAccessToken();
      print('🔁 Retrying with new token: $token');
      response = await request(token!);
    }

    return response;
  }

  // Get user role
  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'CUSTOMER';
  }

  // Helper: Get user id from SharedPreferences
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }
}
