import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_agent_app/core/model/ServiceModal.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/agent_order_response.dart';
import '../../Model/AgentRegistrationRequest.dart';
import '../../Model/AuthResponse.dart';
import '../../Model/AgentProfileResponse.dart';
import '../../Model/LoginRequestModel.dart';
import '../../Model/MovementRequest.dart';
import '../../Model/OtpUser.dart';
import '../../Model/Product.dart';
import '../../Model/ProductStock.dart';
import '../../Model/ToolStock.dart';
import '../../Model/Tool.dart';
import '../model/slot_availability.dart';
import 'package:urban_agent_app/core/model/slot_availability.dart';
import 'package:urban_agent_app/Model/AuthResponse.dart';
import 'package:urban_agent_app/Model/AgentRegistrationRequest.dart';
import 'package:urban_agent_app/Model/AgentProfileResponse.dart';
import 'package:urban_agent_app/Model/LoginRequestModel.dart';
import 'package:urban_agent_app/Model/OtpUser.dart';
import 'package:urban_agent_app/Model/AppSettings.dart';

class ApiService {
  static const String baseUrl = 'https://api.itfixer199.com';
  static const String wsBaseUrl = "wss://api.itfixer199.com";

  // static String accessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzczMTc5MTQ3LCJpYXQiOjE3NzMxMjUxNDcsImp0aSI6IjhmZWQ0YWRkZDk0OTRiODk4MzBhNzY1ZmQzOTczZGIzIiwidXNlcl9pZCI6ImUzYWM4OTQ3LTdhYzktNDYwOS05NGVlLTczZjNjYmU4ZWM1NiJ9.djd9pcmI_FapifZ7cn4OM3h_hJDCrFBFIdggVBYHRZU";
  // static String refresh = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTc3MzM3NzQ3NSwiaWF0IjoxNzcyNzcyNjc1LCJqdGkiOiI0NTU0NDdlZTJmZWI0Y2M4OWZiYTU4YWEzZjYxNzQ5NiIsInVzZXJfaWQiOiJlM2FjODk0Ny03YWM5LTQ2MDktOTRlZS03M2YzY2JlOGVjNTYifQ.hsKt1SQSqlyBHaEGi0VKu57aHwtbfFunOZxs1qwMa34";

  /// Connects once to the order WebSocket and stays connected.
  /// - Emits [true]  when service_modifications[].status == APPROVED or APPLIED
  /// - Emits [false] when service_modifications[].status == REJECTED or DECLINED
  /// - Emits nothing while status == PENDING (stream stays open)
  static Stream<bool> orderUpdatedStream(String orderId){
    final controller = StreamController<bool>();
    WebSocketChannel? channel;
    StreamSubscription? sub;

    void close(bool? result) {
      if (controller.isClosed) return;
      sub?.cancel();
      channel?.sink.close();
      if (result != null) {
        controller.add(result);
      }
      controller.close();
    }

    try {
      final userId =  getUserId();
      final accessToken =  _getAccessToken();

      final wsUrl = "$wsBaseUrl/ws/order/$orderId/?accessToken=$accessToken";
      print("WS CONNECTING → $wsUrl");
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      sub = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            print("WS MESSAGE → $data");
            final modification = data["modification"];
            if (modification != null) {
              final status = (modification["status"] ?? "").toString().toUpperCase();
              print("WS STATUS → $status");
              if (status == "APPROVED" || status == "APPLIED") {
                close(true);
                return;
              }
              if (status == "REJECTED" || status == "DECLINED") {
                close(false);
                return;
              }
              print("WS PENDING → waiting...");
            }
          } catch (e) {
            print("WS PARSE ERROR → $e");
          }
        },
        onError: (error) {
          print("WS ERROR → $error");
          close(null);
        },
        onDone: () {
          print("WS CLOSED BY SERVER");
          close(null);
        },
      );

      controller.onCancel = () {
        sub?.cancel();
        channel?.sink.close();
      };
    } catch (e) {
      print("WS CONNECT ERROR → $e");
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    }
    return controller.stream;
  }

  /// TRACKING STREAM
  /// Receives live GPS updates from backend
  static Stream<Map<String, dynamic>> trackingStream() {
    final controller = StreamController<Map<String, dynamic>>();
    WebSocketChannel? channel;
    StreamSubscription? subscription;

    try {
      final userId =  getUserId();
      final accessToken =  _getAccessToken();

      final wsUrl = "$wsBaseUrl/ws/api/tracking/log/?accessToken=$accessToken";
      print("[TRACKING] CONNECTING → $wsUrl");
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      subscription = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            print("[TRACKING] DATA → $data");
            controller.add(data);
          } catch (e) {
            print("[TRACKING] PARSE ERROR → $e");
          }
        },
        onError: (error) {
          print("[TRACKING] WS ERROR → $error");
          controller.addError(error);
        },
        onDone: () {
          print("[TRACKING] WS CLOSED");
          controller.close();
        },
      );

      controller.onCancel = () {
        subscription?.cancel();
        channel?.sink.close();
      };
    } catch (e) {
      print("[TRACKING] CONNECT ERROR → $e");
      controller.addError(e);
      controller.close();
    }
    return controller.stream;
  }

  static Future<List<SlotAvailability>> getAgentSlotAvailability([String? date]) async {
    String fetchDate = date ?? DateTime.now().toString().split(' ')[0];
   try{
     final userId = await getUserId();
     final accessToken = await _getAccessToken();

     if (accessToken == null || userId == null || userId.isEmpty) {
       // Even if session is missing, we ensure local accessTokens are cleared
       await AuthResponse.clearTokens();
       return [];
     }
     String url = '$baseUrl/api/slots/my-slots/?date=$fetchDate';

     final response = await http.get(
       Uri.parse(url),
       headers: {
         'Content-Type': 'application/json',
         'Authorization': 'Bearer $accessToken',
       },
     );
     print("Url $url");
     print("Response Data ${response.body}");
     print("Response Code ${response.statusCode}");
     if(response.statusCode == 200){
       final dynamic decodedData = json.decode(response.body);

       List<dynamic> list;
       if (decodedData is List) {
         list = decodedData;
       } else if (decodedData is Map && decodedData.containsKey('results')) {
         list = decodedData['results'];
       } else if (decodedData is Map && decodedData.containsKey('data')) {
         list = decodedData['data'];
       } else {
         // If it's a single object map, wrap it in a list, or return empty if unknown
         print("Unexpected JSON format: $decodedData");
         return [];
       }

       return list.map((json) => SlotAvailability.fromJson(json)).toList();
     }
     return [];
   }
   catch(e){
     print("Error on get Agent Slot $e");
     return [];
   }
  }

  Future<List<dynamic>> getMySlots() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('No access accessToken');

    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return [];
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/slots/my-slots/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching slots: $e');
    }
    return [];
  }

  static Future<List<OrderDetails>?> agentOrder() async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return [];
      }

      String url = "$baseUrl/api/order/agent-orders/?is_active=true";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print("Response body agent order ${response.body}");
      print("Response status code agent order ${response.statusCode}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return AgentOrderResponse
            .fromJson(data)
            .orders;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<OrderDetails>> getAgentOrderHistory()async{
    try{
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return [];
      }
      String url = "$baseUrl/api/order/agent-orders/";

      final response  = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['orders'] != null) {
          return (data['orders'] as List)
              .map((orderJson) => OrderDetails.fromJson(orderJson))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print("Error on get Order History $e");
      return [];
    }
  }

  //Agent Approval for Order Assignment
  static Future<bool> agentApprovalOrder(String orderID, String status,
      {String? reason}) async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return false;
      }
      String url = '$baseUrl/api/order/orders/$orderID/agent-approval/';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "status": status,
          if (reason != null) "rejection_reason_description": reason,
        }),
      );

      print("Response body ${response.body}");
      print("Response status code ${response.statusCode}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      print("Error on agent Approval order $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> listService({
    int page = 1,
    int pageSize = 1,
    String? lat,
    String? lng,
  }) async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        await AuthResponse.clearTokens();
        return {'services': <ServiceModal>[], 'hasMore': false};
      }

      String url =
          '$baseUrl/api/services/?include_categories=true&include_media=true&include_pricing=true&include_zones=true&page=$page&size=$pageSize';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('listService [page=$page] status=${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> list = [];
        bool hasMore = false;

        if (data['success'] == true && data['services'] != null) {
          list = data['services'];
          // Check pagination metadata
          final pagination = data['pagination'];
          if (pagination != null) {
            hasMore = pagination['has_next'] == true ||
                pagination['next'] != null;
          } else {
            // If no pagination metadata, assume more data if we got a full page
            hasMore = list.length >= pageSize;
          }
        } else if (data.containsKey('results')) {
          list = data['results'];
          hasMore = data['next'] != null;
        } else if (data.containsKey('data')) {
          list = data['data'];
          hasMore = list.length >= pageSize;
        }

        print('listService [page=$page] count=${list.length} hasMore=$hasMore');

        final services = list.map((json) {
          final service = Service.fromJson(json);
          return ServiceModal.fromService(service);
        }).toList();

        return {'services': services, 'hasMore': hasMore};
      }
      return {'services': <ServiceModal>[], 'hasMore': false};
    } catch (e) {
      print('Error on listService: $e');
      return {'services': <ServiceModal>[], 'hasMore': false};
    }
  }

  static Future<void> serviceModification(String orderId, String orderItemId, String serviceId, String? reason) async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return ;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/order/service-modification/request/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "order_id": orderId,
          "order_item_id": orderItemId,
          "new_service_id": serviceId,
          if (reason != null && reason.isNotEmpty) "reason": reason,
        }),
      );
      print("serviceModification status: ${response.statusCode}");
      print("serviceModification body: ${response.body}");
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('serviceModification failed: ${response.statusCode}');
      }
    } catch (e) {
      print("Error on service modification $e");
      rethrow;
    }
  }

  /// Connects once to the order WebSocket and stays connected.
  /// - Emits [true]  when service_modifications[].status == APPROVED or APPLIED
  /// - Emits [false] when service_modifications[].status == REJECTED or DECLINED
  /// - Emits nothing while status == PENDING (stream stays open)
  /// - On unexpected server close: caller (ApprovalWaitingScreen) reconnects
 /* static Future<Stream<bool>> orderUpdatedStream(String orderId)async{
    final ctrl = StreamController<bool>();
    WebSocketChannel? channel;
    StreamSubscription? sub;

    void close(bool? result) {
      if (ctrl.isClosed) return;
      sub?.cancel();
      channel?.sink.close();
      if (result != null) ctrl.add(result);
      ctrl.close();
    }

    try {
      final accessToken = await _getAccessToken();

      final wsBase = baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final wsUrl = '$wsBase/ws/order/$orderId/?accessToken=$accessToken';
      print('WS connecting: $wsUrl');
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      sub = channel.stream.listen(
        (dynamic raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            print('WS message: $data');

            // WS sends: { "modification": { "status": "PENDING"/"APPROVED"/"REJECTED", ... } }
            final mod = data['modification'] as Map<String, dynamic>?;
            if (mod != null) {
              final st = (mod['status'] as String? ?? '').toUpperCase();
              print('WS: modification.status = $st');

              if (st == 'APPROVED' || st == 'APPLIED') {
                close(true);  // status changed ? show Approved sheet
                return;
              }
              if (st == 'REJECTED' || st == 'DECLINED') {
                close(false); // status changed ? show Rejected sheet
                return;
              }
              // PENDING ? WS stays open, buffer keeps showing
              print('WS: status=$st — staying connected');
              return;
            }

          } catch (e) {
            print('WS parse error: $e');
          }
        },
        onError: (e) {
          print('WS error: $e');
          close(null); // close without result; caller will reconnect
        },
        onDone: () {
          print('WS closed by server');
          close(null); // close without result; caller will reconnect
        },
      );

      ctrl.onCancel = () { sub?.cancel(); channel?.sink.close(); };
    } catch (e) {
      print('WS connect error: $e');
      if (!ctrl.isClosed) { ctrl.addError(e); ctrl.close(); }
    }

    return ctrl.stream;
  }*/

  static Future<bool> deliveryVerifyOtp(String orderId,String otp)async{
    try{
      final accessToken = await _getAccessToken();

      String url = "$baseUrl/api/order/orders/$orderId/verify-otp";

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "otp":otp
        })
      );
      if(response.statusCode == 200 || response.statusCode == 201){
        return true;
      }
      return false;
    }
    catch(e){
      print("Error on delivery verify otp $e");
      return false;
    }
  }

  /// Fetches a single [OrderDetails] by [orderId] and returns it.
  /// Returns null if the request fails.
  static Future<OrderDetails?> getOrderbyId(String orderId) async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return null;
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/order/orders/$orderId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      print('getOrderbyId status: ${response.statusCode}');
      print('getOrderbyId body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // API returns: { "success": true, "order": { ... } }
        final orderJson = data['order'] as Map<String, dynamic>? ?? data;
        return OrderDetails.fromJson(orderJson);
      }
    } catch (e) {
      print('Error getOrderbyId: $e');
    }
    return null;
  }

  static Future<bool> updateJobStatus(String orderId, String status) async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return false;
      }

      if (accessToken == null) throw Exception('No access accessToken');
      String url = '$baseUrl/api/order/orders/$orderId/update-status/';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"order_status": status}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Job $orderId status successfully updated to $status");
        return true;
      }
      return false;
    } catch (e) {
      print("Error on update job status: $e");
      return false;
    }
  }
  static Future<bool?> toggleActiveStatus() async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return false;
      }
      String url = '$baseUrl/api/user/toggle-active';

      print("Calling Toggle API: $url");

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print("Status Code: ${response.statusCode}");
      print("Raw Response: ${response.body}");


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        bool? isActive = data['data']['is_active'];

        print("Toggle Success - is_active value: $isActive");

        return isActive;
      } else {
        print("Toggle Failed with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error toggling active status: $e");
    }

    return null;
  }
  static Future<void> addFcmToken() async {
    print("🔔 [addFcmToken] Starting token registration...");
    try {
      final token = await _getAccessToken();
      if (token == null || token.isEmpty) {
        print("🔔 [addFcmToken] Access token is NULL or EMPTY. User might not be logged in.");
        return;
      }
      print("🔔 [addFcmToken] Getting FCM token...");
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        print("🔔 [addFcmToken] FCM Token received: $fcmToken");
      } catch (e) {
        print("🔔 [addFcmToken] Error getting FCM token from Firebase: $e");
        return;
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        print("🔔 [addFcmToken] FCM token is null/empty. skipping registration.");
        return;
      }

      String url = '$baseUrl/api/notifications/register-fcm/';
      print("🔔 [addFcmToken] Sending to API: $url");

      final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            "fcm_token": fcmToken,
          })
      );

      print("🔔 [addFcmToken] API Response Status: ${response.statusCode}");
      print("🔔 [addFcmToken] API Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("🔔 [addFcmToken] Successfully registered token on server.");
      } else {
        print("🔔 [addFcmToken] Server rejected token registration.");
      }
    } catch (e, stack) {
      print("🔔 [addFcmToken] EXCEPTION: $e");
      print("🔔 [addFcmToken] STACKTRACE: $stack");
    }
  }
  // static Future<List<LatLng>> getAgentZone() async {
  //   try {
  //     final url = Uri.parse("$baseUrl/api/agent-zones/agent/");
  //
  //     final response = await http.get(
  //       url,
  //       headers: {
  //         "accept": "application/json",
  //         "Authorization": "Bearer $accessToken",
  //       },
  //     );
  //
  //     print("ZONE API STATUS: ${response.statusCode}");
  //     print("ZONE API BODY: ${response.body}");
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //
  //       List zones = data["data"]["zone_details"];
  //       List<LatLng> zonePoints = [];
  //
  //       for (var zone in zones) {
  //         List coordinates = zone["coordinates"];
  //
  //         for (var point in coordinates) {
  //           zonePoints.add(
  //             LatLng(point["lat"], point["lng"]),
  //           );
  //         }
  //       }
  //
  //       return zonePoints;
  //     }
  //   } catch (e) {
  //     print("ZONE API ERROR: $e");
  //   }
  //
  //   return [];
  // }
  static Future<List<Map<String, dynamic>>> getAgentZones() async {
    try {
      final userId = await getUserId();
      final accessToken = await _getAccessToken();

      final url = Uri.parse("$baseUrl/api/agent-zones/agent/");
      final response = await http.get(
        url,
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List zones = data["data"]["zone_details"] ?? [];

        return zones.map((zone) {
          List coords = zone["coordinates"] ?? [];
          List<LatLng> points = [];

          for (var p in coords) {
            double? lat = (p["lat"] ?? p["latitude"])?.toDouble();
            double? lng = (p["lng"] ?? p["longitude"])?.toDouble();

            // Filter out 0,0 points which cause "too long lines"
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
               // Verify order in console: If lines still stretch, try swapping to LatLng(lng, lat)
               points.add(LatLng(lat, lng));
            }
          }

          return {
            "name": zone["name"] ?? "Unnamed Zone",
            "points": points,
          };
        }).toList();
      }
    } catch (e) {
      log("ZONE API ERROR: $e");
    }
    return [];
  }


//   Future<AgentApiResult<AgentRegistrationResponse>> registerAgent({
//     required AgentRegistrationRequest request,
//     File? profileImage,
//     File? aadharDoc,
//     File? panCard,
//     File? videoKyc,
//   }) async {
//     try {
//       print('?? Registering agent: ${request.name}');
//
//       final uri = Uri.parse('$baseUrl/api/user/agent'); // ?? update endpoint if different
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
//       print('?? Fields: ${multipartRequest.fields}');
//       print('?? Files: ${multipartRequest.files.map((f) => f.field).toList()}');
//
//       final streamedResponse = await multipartRequest
//           .send()
//           .timeout(const Duration(seconds: 30));
//
//       final response = await http.Response.fromStream(streamedResponse);
//
//       print('?? Register Agent [${response.statusCode}]: ${response.body}');
//
//       final json = jsonDecode(response.body);
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final result = AgentRegistrationResponse.fromJson(json);
//         await result.saveToPrefs(); // ? saves accessTokens automatically
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
//       print('? registerAgent error: $e');
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


  /// PUT /api/user/agent/{userId}
   Future<AgentApiResult<bool>> updateAgentProfile(
      String userId,
      Map<String, dynamic> updatedData, {
        File? profileImage,
      }) async {
    try {
      print('?? Updating agent profile: $userId');
      print('?? Data: $updatedData');

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        return AgentApiResult.failure('Not authenticated. Please login again.');
      }

      final uri = Uri.parse('$baseUrl/api/user/agent/$userId');

      // We use MultipartRequest if an image is provided, otherwise a standard PUT
      if (profileImage != null) {
        final request = http.MultipartRequest('PUT', uri)
          ..headers.addAll({
            'accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
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

        print('?? Sending Multipart PUT to: $uri');
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
            'Authorization': 'Bearer $accessToken',
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
      print('? updateAgentProfile error: $e\n$stack');
      return AgentApiResult.failure('Something went wrong. Please try again.');
    }
  }

  AgentApiResult<bool> _handleUpdateResponse(http.Response response) {
    print('?? Update Profile Status: ${response.statusCode}');

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
      print('? Failed to decode response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
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

    print('? Update Error: $errorMsg');
    return AgentApiResult.failure(errorMsg);
  }



  static String _fileExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'jpeg';
    if (ext == 'png') return 'png';
    if (ext == 'pdf') return 'pdf';
    return 'jpeg'; // safe default
  }

  // -- Token Management Helpers -----------------------------------------------

  // Helper: Get access accessToken
  static Future<String?> getAccessTokenLocal() async {
    return _getAccessToken();
  }

  // Helper: Get access accessToken
  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    print('?? Getting Access Token: $accessToken');
    return accessToken;
  }

  // Helper: Get refresh accessToken
  static Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('refresh_token');
    print('?? Getting Refresh Token: $accessToken');
    return accessToken;
  }

  // Helper: Clear all accessTokens (calls AuthResponse.clearTokens())
  static Future<void> _clearTokens() async {
    await AuthResponse.clearTokens();
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await _getRefreshToken();
    print('?? Refresh Token Used: $refreshToken');

    if (refreshToken == null) {
      print('? No refresh accessToken found');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh': refreshToken,
        }),
      );

      print('?? Refresh Status: ${response.statusCode}');
      print('?? Refresh Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('access_token', jsonData['access']);
        print('? New Access Token Saved: ${jsonData['access']}');

        if (jsonData['refresh'] != null) {
          await prefs.setString('refresh_token', jsonData['refresh']);
          print('✅ New Refresh Token Saved: ${jsonData['refresh']}');
        }

        return true;
      } else {
        print('? Refresh failed. Clearing accessTokens.');
        await _clearTokens();
        return false;
      }
    } catch (e) {
      print('? Refresh Exception: $e');
      return false;
    }
  }

  /// Public wrapper around [_refreshAccessToken] for use in UI layers.
  static Future<bool> refreshToken() => _refreshAccessToken();

  static Future<http.Response> _authorizedRequest(
      Future<http.Response> Function(String accessToken) request,
      ) async {
    String? accessToken = await _getAccessToken();
    print('?? Authorized Request Using Token: $accessToken');

    if (accessToken == null) {
      throw Exception('No access accessToken');
    }

    http.Response response = await request(accessToken);
    print('?? Response Status: ${response.statusCode}');

    if (response.statusCode == 401) {
      print('?? Token expired. Trying refresh...');
      final refreshed = await _refreshAccessToken();

      if (!refreshed) {
        print('? Refresh failed. Clearing accessTokens.');
        await _clearTokens();
        throw Exception('Session expired');
      }

      accessToken = await _getAccessToken();
      print('?? Retrying with new accessToken: $accessToken');
      response = await request(accessToken!);
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

  static Future<Map<String, dynamic>> fetchVersionInfo() async {
    try {
      final uri = Uri.parse('$baseUrl/api/app-settings');
      final response = await http.get(uri);

      //print('Status code: ${response.statusCode}');
      //print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Version API failed');
      }

      final jsonData = jsonDecode(response.body);
      final appSettings = AppSettings.fromJson(jsonData);

      if (!appSettings.success) {
        throw Exception(appSettings.message);
      }

      final int serverMinBuild = appSettings.data.appVersion;
      // Use fallback if playStoreUrl is null
      final String? storeUrl = appSettings.data.playStoreUrl;

      return {
        'app_version': serverMinBuild,
        'play_store_url': storeUrl,
      };
    } catch (e) {
      //print("❌ Error fetching version info: $e");
      rethrow;
    }
  }
  /*--- hari -----*/

  // ── WebSocket ───────────────────────────────────────────────────────────────
  // ── Product WebSocket ───────────────────────────────────────────────────────
  static const String _wsUrl = 'wss://api.itfixer199.com/ws/movements/';
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _wsIsConnecting = false;
  int _wsReconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _wsController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get movementStream => _wsController.stream;

  // ── Tool WebSocket ──────────────────────────────────────────────────────────
  static const String _toolWsUrl = 'wss://api.itfixer199.com/ws/tool-movements/';
  WebSocketChannel? _toolWsChannel;
  StreamSubscription? _toolWsSubscription;
  bool _toolWsIsConnecting = false;
  int _toolWsReconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _toolWsController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get toolMovementStream =>
      _toolWsController.stream;

  bool _isDisposed = false;

  Future<void> connectMovementWebSocket() async {
    if (_wsIsConnecting) return;
    _wsIsConnecting = true;
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        print('❌ WebSocket: No access accessToken');
        _wsIsConnecting = false;
        return;
      }
      final uri = Uri.parse('$_wsUrl?token=$accessToken');
      print('📡 WS Connecting: $uri');
      _wsChannel = WebSocketChannel.connect(uri);
      _wsSubscription = _wsChannel!.stream.listen(
            (msg) {
          _wsReconnectAttempts = 0;
          _wsIsConnecting = false;
          if (_isDisposed) return;
          print('📦 WS Message: $msg');
          try {
            if (!_wsController.isClosed) {
              _wsController.add(jsonDecode(msg));
            }
          } catch (e) {
            print('❌ WS parse error: $e');
          }
        },
        onError: (e) {
          _wsIsConnecting = false;
          print('❌ WS error: $e');
          _wsReconnect();
        },
        onDone: () {
          _wsIsConnecting = false;
          print('🔌 WS closed');
          _wsReconnect();
        },
      );
    } catch (e) {
      _wsIsConnecting = false;
      print('❌ WS connect error: $e');
      _wsReconnect();
    }
  }

  void _wsReconnect() {
    if (_isDisposed) return;
    _wsReconnectAttempts++;
    final delay = Duration(seconds: (2 * _wsReconnectAttempts).clamp(5, 30));
    print('🔄 WS reconnect in ${delay
        .inSeconds}s (attempt $_wsReconnectAttempts)...');
    Future.delayed(delay, () {
      if (!_wsIsConnecting && !_isDisposed) connectMovementWebSocket();
    });
  }

  // ── Tool WebSocket Methods ──────────────────────────────────────────────────
  Future<void> connectToolMovementWebSocket() async {
    if (_toolWsIsConnecting) return;
    _toolWsIsConnecting = true;
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('❌ Tool WebSocket: No access accessToken');
        _toolWsIsConnecting = false;
        return;
      }

      final uri = Uri.parse('$_toolWsUrl?token=$accessToken');
      print('📡 Tool WS Connecting to: $uri');

      _toolWsChannel = WebSocketChannel.connect(uri);
      _toolWsSubscription = _toolWsChannel!.stream.listen(
            (msg) {
          _toolWsReconnectAttempts = 0;
          _toolWsIsConnecting = false;
          if (_isDisposed) return;
          print('📦 Tool WS Message: $msg');
          try {
            if (!_toolWsController.isClosed) {
              _toolWsController.add(jsonDecode(msg));
            }
          } catch (e) {
            print('❌ Tool WS parse error: $e');
          }
        },
        onError: (e) {
          _toolWsIsConnecting = false;
          print('❌ Tool WS error: $e');
          _toolWsReconnect();
        },
        onDone: () {
          _toolWsIsConnecting = false;
          print('🔌 Tool WS closed');
          _toolWsReconnect();
        },
      );
    } catch (e) {
      _toolWsIsConnecting = false;
      print('❌ Tool WS connect error: $e');
      _toolWsReconnect();
    }
  }

  void _toolWsReconnect() {
    if (_isDisposed) return;
    _toolWsReconnectAttempts++;
    final delay = Duration(
        seconds: (2 * _toolWsReconnectAttempts).clamp(5, 30));
    print('🔄 Tool WS reconnect in ${delay
        .inSeconds}s (attempt $_toolWsReconnectAttempts)...');
    Future.delayed(delay, () {
      if (!_toolWsIsConnecting && !_isDisposed) connectToolMovementWebSocket();
    });
  }

  void disconnectToolMovementWebSocket() {
    _toolWsSubscription?.cancel();
    _toolWsSubscription = null;
    _toolWsChannel?.sink.close();
    _toolWsChannel = null;
  }

  void disconnectMovementWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void disposeWebSocket() {
    _isDisposed = true;
    disconnectMovementWebSocket();
    disconnectToolMovementWebSocket();
    if (!_wsController.isClosed) _wsController.close();
    if (!_toolWsController.isClosed) _toolWsController.close();
  }

  Future<ApiResponse<AuthResponse>> unifiedLogin(
      LoginRequestModel request) async {
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
        Uri.parse('$baseUrl/api/unified-login'),
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
        Uri.parse('$baseUrl/api/send-otp'),
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

      final errors = json['errors'] as List<dynamic>?;
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
        'otp': otp,
        'login_type': 'OTP',
        'role': 'AGENT',
        'device_type': Platform.isAndroid ? 'ANDROID' : 'IOS',
        'device_id': deviceInfo['device_id'] ?? 'unknown',
        'device_name': deviceInfo['device_name'] ?? 'unknown',
        'ip_address': '0.0.0.0',
      };

      print('📲 [VerifyOtp] Request body : $body');

      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
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
            'access': json['access'],
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

        if (userMap == null && json.containsKey('user') &&
            json['user'] is Map) {
          userMap = Map<String, dynamic>.from(json['user'] as Map);
        }

        print('📲 [VerifyOtp] Resolved tokensMap : $tokensMap');
        print('📲 [VerifyOtp] Resolved userMap   : $userMap');

        if (tokensMap != null) {
          final tokens = OtpTokens.fromJson(tokensMap);
          final user = userMap != null ? OtpUser.fromJson(userMap) : null;

          final verifyResponse = VerifyOtpResponse(
            success: true,
            message: json['message']?.toString() ?? 'Login successful',
            user: user,
            tokens: tokens,
          );

          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', tokens.access);
          await prefs.setString('refresh_token', tokens.refresh);

          if (user != null) {
            await prefs.setString('user_id', user.id);
            await prefs.setString('user_name', user.name);
            await prefs.setString('user_email', user.email);
            await prefs.setString('user_mobile', user.mobileNumber);
            await prefs.setString('user_role', user.role);
            await prefs.setBool('is_mobile_verified', user.isMobileVerified);
            await prefs.setBool('is_email_verified', user.isEmailVerified);
            await prefs.setString('user_status', user.status);
          }

          print('✅ [VerifyOtp] Success — user: ${user?.name}, role: ${user
              ?.role}');
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
//         await result.saveToPrefs(); // ✅ saves accessTokens automatically
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

      final uri = Uri.parse('$baseUrl/api/user/agent');

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
        print('📡 File: ${file.field} (${file
            .contentType}) - Size: $length bytes');
      }

      final streamedResponse = await multipartRequest
          .send()
          .timeout(
        const Duration(seconds: 300), // Increased to 5 minutes
        onTimeout: () {
          print(
              '❌ TIMEOUT: $uri did not respond in 300s. Possible slow connection or large files.');
          throw TimeoutException(
              'Request timed out. Please check your internet connection or try with smaller files.');
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
      return AgentApiResult.failure(
          'No internet connection. Check your network.');
    } on TimeoutException catch (e) {
      print('❌ TimeoutException: $e');
      return AgentApiResult.failure('Request timed out. Please try again.');
    } catch (e, stack) {
      print('❌ registerAgent error: $e');
      print('❌ Stack: $stack');
      return AgentApiResult.failure('Something went wrong. Please try again.');
    }
  }

  static Future<ApiResponse<AgentProfileResponse>> getAgentProfile() async {
    try {
      final response = await _authorizedRequest((accessToken) =>
          http.get(
            Uri.parse('$baseUrl/api/user/my-details'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'accept': 'application/json',
            },
          ));

      print('📡 getAgentProfile status: ${response.statusCode}');
      print('📡 getAgentProfile body: ${response.body}');

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


  Future<AgentApiResult<bool>> logoutUser() async {
    try {
      final userId = await getUserId();
      final accessToken = await getAccessToken();

      if (accessToken == null || userId == null || userId.isEmpty) {
        // Even if session is missing, we ensure local accessTokens are cleared
        await AuthResponse.clearTokens();
        return AgentApiResult.success(true);
      }

      print('📡 Logging out user: $userId');

      final response = await http.post(
        Uri.parse('$baseUrl/api/logout/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 15));

      print('📡 Logout Status: ${response.statusCode}');

      // Clear accessTokens regardless of server response success
      await AuthResponse.clearTokens();

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AgentApiResult.success(true);
      } else {
        // Return success anyway because local session is cleared,
        // but maybe log the error
        print('⚠️ Server logout failed but local accessTokens cleared: ${response
            .body}');
        return AgentApiResult.success(true);
      }
    } catch (e) {
      print('❌ logoutUser error: $e');
      // Still clear accessTokens locally on error
      await AuthResponse.clearTokens();
      return AgentApiResult.failure('Network error: ${e.toString()}');
    }
  }

// ── Helpers ───────────────────────────────────────────────────────────────────



  // ── Token Management Helpers ───────────────────────────────────────────────

  // Helper: Get access accessToken
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    print('🔎 Getting Access Token: $accessToken');
    return accessToken;
  }

  // Helper: Get refresh accessToken



  Future<ApiResponse<List<Product>>> getProducts() async {
    try {
      final queryParams = {
        'include_attribute': 'true',
        'include_brand': 'true',
        'include_category': 'true',
        'include_children': 'true',
        'include_media': 'true',
        'include_pricing': 'true',
      };

      final uri = Uri.parse('$baseUrl/api/product').replace(
          queryParameters: queryParams);
      print('📡 Fetching Products from: $uri');

      final response = await _authorizedRequest((accessToken) =>
          http.get(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'accept': 'application/json',
            },
          )).timeout(const Duration(seconds: 30));

      print('📡 Get Products Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];

        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          print('📡 Products Response Keys: ${decoded.keys}');
          // Priority: data, results, products, items
          final data = decoded['data'] ??
              decoded['results'] ??
              decoded['products'] ??
              decoded['items'];

          if (data is List) {
            raw = data;
          } else if (data is Map) {
            // Check if nested inside data/results
            final inner = data['products'] ?? data['items'] ?? data['results'];
            if (inner is List) {
              raw = inner;
            } else {
              raw = [data];
            }
          }
        }

        final items = raw.map((e) => Product.fromJson(e)).toList();
        print('✅ Fetched ${items.length} products');
        return ApiResponse(isSuccess: true, data: items);
      }

      return ApiResponse(
          isSuccess: false,
          error: 'Failed to fetch products (${response.statusCode})'
      );
    } catch (e) {
      print('❌ getProducts error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── Product Movement Request ───────────────────────────────────────────────
  Future<ApiResponse<MovementRequest>> requestProductMovement({
    required String productId,
    required int stock,
    String type = 'GIVE',
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) throw Exception('No access accessToken');

      final url = Uri.parse(
          '$baseUrl/api/product-inventory/movements/request/');
      print('📡 Requesting Movement: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'product_id': productId,
          'stock': stock,
          'type': type,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 Movement Status: ${response.statusCode}');
      print('📦 Movement Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final data = json['data'];
        return ApiResponse(
            isSuccess: true, data: MovementRequest.fromJson(data));
      }

      return ApiResponse(
        isSuccess: false,
        error: 'Failed to request movement (${response.statusCode})',
      );
    } catch (e) {
      print('❌ requestProductMovement error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── Get All Tools ────────────────────────────────────────────────────────
  Future<ApiResponse<List<Tool>>> getTools() async {
    try {
      final url = Uri.parse('$baseUrl/api/tools/');
      print('📡 GET Tools Catalog: $url');

      final response = await _authorizedRequest((accessToken) =>
          http.get(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
            },
          )).timeout(const Duration(seconds: 15));

      print('📡 Tools Catalog Status: ${response.statusCode}');


      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];

        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          print('📡 Tools Response Keys: ${decoded.keys}');
          // Priority: data, results, tools, items
          final data = decoded['data'] ??
              decoded['results'] ??
              decoded['tools'] ??
              decoded['items'];

          if (data is List) {
            raw = data;
          } else if (data is Map) {
            final inner = data['tools'] ?? data['items'] ?? data['results'];
            if (inner is List) {
              raw = inner;
            } else {
              raw = [data];
            }
          }
        }

        final items = raw.map((e) => Tool.fromJson(e)).toList();
        print('✅ Fetched ${items.length} tools');
        return ApiResponse(isSuccess: true, data: items);
      }
      return ApiResponse(isSuccess: false,
          error: 'Failed to fetch tools (${response.statusCode})');
    } catch (e) {
      print('❌ getTools error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── Tool Movement Request ─────────────────────────────────────────────────
  Future<ApiResponse<MovementRequest>> requestToolMovement({
    required String toolId,
    required int stock,
    String type = 'GET',
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) throw Exception('No access accessToken');

      final url = Uri.parse('$baseUrl/api/tools/movement/request/');
      print('📡 Requesting Tool Movement: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'tools_id': toolId,
          'stock': stock,
          'type': type,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 Tool Movement Status: ${response.statusCode}');
      print('📦 Tool Movement Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        return ApiResponse(
            isSuccess: true, data: MovementRequest.fromJson(data));
      }

      return ApiResponse(
        isSuccess: false,
        error: 'Failed to request tool movement (${response.statusCode})',
      );
    } catch (e) {
      print('❌ requestToolMovement error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── My Tool Stocks ─────────────────────────────────────────────────────────
  Future<ApiResponse<List<ToolStock>>> getMyToolStocks() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) throw Exception('No access accessToken');

      final url = Uri.parse('$baseUrl/api/tools/my-stocks/');
      print('📡 GET Tool Stocks: $url');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      print('📡 Tool Stocks Status: ${response.statusCode}');
      print('📦 Tool Stocks Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          final data = decoded['data'] ?? decoded['results'];
          if (data is List) {
            raw = data;
          } else if (data is Map) {
            raw = [data];
          } else {
            raw = [decoded];
          }
        }

        final items = raw.map((e) => ToolStock.fromJson(e)).toList();
        return ApiResponse(isSuccess: true, data: items);
      }
      return ApiResponse(isSuccess: false,
          error: 'Tool stocks failed (${response.statusCode})');
    } catch (e) {
      print('❌ getMyToolStocks error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── My Product Stocks ──────────────────────────────────────────────────────
  Future<ApiResponse<List<ProductStock>>> getMyProductStocks() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) throw Exception('No access accessToken');

      final url = Uri.parse('$baseUrl/api/product-inventory/my-stocks/');
      print('📡 GET Product Stocks: $url');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      print('📡 Product Stocks Status: ${response.statusCode}');
      print('📦 Product Stocks Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          final data = decoded['data'] ?? decoded['results'];
          if (data is List) {
            raw = data;
          } else if (data is Map) {
            raw = [data];
          } else {
            raw = [decoded];
          }
        }

        final items = raw.map((e) => ProductStock.fromJson(e)).toList();
        return ApiResponse(isSuccess: true, data: items);
      }
      return ApiResponse(isSuccess: false,
          error: 'Product stocks failed (${response.statusCode})');
    } catch (e) {
      print('❌ getMyProductStocks error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }


  static Future<ApiResponse<Map<String, dynamic>>> createHubServiceRequest({
    required String orderId,
    String? orderItemId,
    String? deviceSerialNumber,
    String? deviceConditionNotes,
    List<File>? images,
    List<File>? videos,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        return ApiResponse(isSuccess: false, error: 'Not authenticated');
      }

      final uri = Uri.parse('$baseUrl/api/request/hub-service/');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        });

      // Add fields
      request.fields['order_id'] = orderId;
      if (orderItemId != null && orderItemId.isNotEmpty) {
        request.fields['order_item_id'] = orderItemId;
      }
      if (deviceSerialNumber != null && deviceSerialNumber.isNotEmpty) {
        request.fields['device_serial_number'] = deviceSerialNumber;
      }
      if (deviceConditionNotes != null && deviceConditionNotes.isNotEmpty) {
        request.fields['device_condition_notes'] = deviceConditionNotes;
      }

      // Add images
      if (images != null) {
        for (var i = 0; i < images.length; i++) {
          final file = images[i];
          final ext = _fileExtension(file.path);
          request.files.add(await http.MultipartFile.fromPath(
            'images',
            file.path,
            contentType: http.MediaType('image', ext),
          ));
        }
      }

      // Add videos
      if (videos != null) {
        for (var i = 0; i < videos.length; i++) {
          final file = videos[i];
          request.files.add(await http.MultipartFile.fromPath(
            'videos',
            file.path,
            contentType: http.MediaType('video', 'mp4'),
          ));
        }
      }

      print('📡 Creating Hub Service Request: $uri');
      print('📡 Fields: ${request.fields}');

      final streamedResponse = await request.send().timeout(
          const Duration(seconds: 300));
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Hub Service Request Status: ${response.statusCode}');
      print('📡 Hub Service Request Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return ApiResponse(isSuccess: true, data: json);
      }

      final json = jsonDecode(response.body);
      String errorMsg = 'Failed to create request';
      if (json is Map && json['message'] != null) {
        errorMsg = json['message'].toString();
      } else if (json is Map && json['errors'] != null) {
        errorMsg = json['errors'].toString();
      }

      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      print('❌ createHubServiceRequest error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> createSlotChangeRequest({
    required String orderId,
    String? orderItemId,
    String? currentSlotId,
    String? requestedSlotId,
    required String requestedDate,
    required String requestedStartTime,
    required String requestedEndTime,
    required String reasonType,
    required String reasonDescription,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null)
        return ApiResponse(isSuccess: false, error: 'Not authenticated');

      final bodyMap = {
        "order_id": orderId,
        "order_item_id": orderItemId,
        "current_slot_id": currentSlotId,
        "requested_slot_id": requestedSlotId,
        "requested_date": requestedDate,
        "requested_start_time": requestedStartTime,
        "requested_end_time": requestedEndTime,
        "slot_change_reason_type": reasonType,
        "slot_change_reason_description": reasonDescription,
      };

      print('📤 Slot Change Request Body: ${jsonEncode(bodyMap)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/request/slot-change/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(bodyMap),
      );

      print('📡 Slot Change Status: ${response.statusCode}');
      print('📡 Slot Change Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(isSuccess: true, data: jsonDecode(response.body));
      }
      return ApiResponse(isSuccess: false,
          error: 'Failed to create slot change request (${response
              .statusCode})');
    } catch (e) {
      print('❌ createSlotChangeRequest error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> createCancellationRequest({
    required String orderId,
    String? orderItemId,
    required String cancellationReasonType,
    required String reasonDescription,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null)
        return ApiResponse(isSuccess: false, error: 'Not authenticated');

      final response = await http.post(
        Uri.parse('$baseUrl/api/request/cancellation/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "order_id": orderId,
          "order_item_id": orderItemId,
          "cancellation_reason_type": cancellationReasonType,
          "cancellation_reason_description": reasonDescription,
        }),
      );

      print('📡 Cancellation Status: ${response.statusCode}');
      print('📡 Cancellation Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(isSuccess: true, data: jsonDecode(response.body));
      }
      return ApiResponse(isSuccess: false,
          error: 'Failed to create cancellation request (${response
              .statusCode})');
    } catch (e) {
      print('❌ createCancellationRequest error: $e');
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  Future<AgentApiResult<List<SlotAvailability>>> getAvailableSlotsByLocation({
    required double lat,
    required double lng,
    String? agentId,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        return AgentApiResult.failure('Not authenticated');
      }

      final uri = Uri.parse(
          '$baseUrl/api/slots/available-slots/?lat=$lat&lng=$lng${agentId != null ? "&agent_id=$agentId" : ""}');
      print('📡 Fetching Available Slots from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('📡 Get Slots Status: ${response.statusCode}');
      print('📡 Get Slots Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> list = [];

        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          if (decoded.containsKey('zone_slot') && decoded['zone_slot'] is Map) {
            final zoneData = decoded['zone_slot'] as Map<String, dynamic>;
            final zoneName = zoneData['name'] ?? zoneData['zone_name'];
            final zoneId = zoneData['id'];

            if (zoneData.containsKey('slots') && zoneData['slots'] is List) {
              final rawSlots = zoneData['slots'] as List;
              list = rawSlots.map((s) {
                if (s is Map) {
                  final sMap = Map<String, dynamic>.from(s);
                  sMap['zone_name'] = sMap['zone_name'] ?? zoneName;
                  sMap['zone'] = sMap['zone'] ?? zoneId;
                  return sMap;
                }
                return s;
              }).toList();
            }
          } else {
            final data = decoded['results'] ?? decoded['data'] ?? decoded['zones'] ?? decoded['slots'] ?? decoded['available_slots'];
            if (data is List) {
              list = data;
            } else if (data is Map) {
              list = [data];
            } else {
              list = [decoded];
            }
          }
        }

        final slots = list.map((j) => SlotAvailability.fromJson(j)).toList();
        return AgentApiResult.success(slots);
      } else {
        return AgentApiResult.failure(
            'Failed to fetch slots (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Get Slots Error: $e');
      return AgentApiResult.failure('Error: $e');
    }
  }

}
