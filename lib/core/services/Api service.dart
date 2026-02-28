import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../../Model/AgentRegistrationRequest.dart';
import '../../Model/AuthResponse.dart';

class ApiService
{
  static const String _baseUrl = 'https://api.itfixer199.com';

  Future<ApiResponse<String>> sendOtp(String mobileNumber) async {
    try {
      print('📲 Sending OTP to: $mobileNumber');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({'mobile_number': mobileNumber}),
      ).timeout(const Duration(seconds: 15));

      print('📲 Send OTP [${response.statusCode}]: ${response.body}');

      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          isSuccess: true,
          data: json['message']?.toString() ?? 'OTP sent successfully',
        );
      }

      final errors = json['errors'] as List<dynamic>?;
      final errorMsg = (errors?.isNotEmpty == true)
          ? errors!.first.toString()
          : json['message']?.toString() ?? 'Failed to send OTP';

      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException {
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException {
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e) {
      print('❌ sendOtp error: $e');
      return ApiResponse(isSuccess: false, error: 'Something went wrong');
    }
  }

  Future<ApiResponse<AuthResponse>> verifyOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final body = {
        'mobile_number': mobileNumber,
        'otp': otp,
        'login_type': 'PASSWORD',
        'device_type': Platform.isAndroid ? 'ANDROID' : 'IOS',
        'device_id': deviceInfo['device_id'] ?? 'unknown',
        'device_name': deviceInfo['device_name'] ?? 'unknown',
        'ip_address': '0.0.0.0',
      };

      print('📲 Verifying OTP: $body');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      print('📲 Verify OTP [${response.statusCode}]: ${response.body}');

      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // AuthResponse.fromJson parses user as OtpUser
        final authResponse = AuthResponse.fromJson(json);

        // ✅ Saves tokens + OtpUser fields to SharedPreferences
        await authResponse.saveTokens();

        print('✅ Logged in as: ${authResponse.user?.name} (${authResponse.user?.mobileNumber})');

        return ApiResponse(isSuccess: true, data: authResponse);
      }

      final errors = json['errors'] as List<dynamic>?;
      final errorMsg = (errors?.isNotEmpty == true)
          ? errors!.first.toString()
          : json['message']?.toString() ?? 'OTP verification failed';

      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException {
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException {
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e) {
      print('❌ verifyOtp error: $e');
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

// ── Helpers ───────────────────────────────────────────────────────────────────

  String _fileExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'jpeg';
    if (ext == 'png') return 'png';
    if (ext == 'pdf') return 'pdf';
    return 'jpeg'; // safe default
  }
}
