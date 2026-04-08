import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:urban_agent_app/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_agent_app/core/model/ServiceModal.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/agent_order_response.dart';
import 'package:urban_agent_app/core/model/product_model.dart';
import '../../Model/AgentRegistrationRequest.dart';
import '../../Model/AuthResponse.dart';
import '../../Model/AgentProfileResponse.dart';
import '../../Model/LoginRequestModel.dart';
import '../../Model/MovementRequest.dart';
import '../../Model/OtpUser.dart';
import '../../Model/Product.dart' hide PaginatedProductResponse;
import '../../Model/ProductStock.dart';
import '../../Model/ToolStock.dart';
import '../../Model/Tool.dart';
import '../model/slot_availability.dart';
import '../model/category.dart' as cat;
import '../../config/router.dart' as app_router;
import '../../Model/PaginatedProductResponse.dart';
import 'package:http_parser/http_parser.dart' as http;
// To avoid errors with MediaType

class ApiService {
  // static const String baseUrl = 'https://api-test.itfixer199.com';
  static const String baseUrl = 'https://api.itfixer199.com';
  static const String wsBaseUrl = "wss://api.itfixer199.com";

  /// Fetch global app settings like app version, play store urls, company details.
  static Future<Map<String, dynamic>?> getAppSettings() async {
    try {
      final response = await _authorizedRequest(
        (accessToken) => http.get(
          Uri.parse('$baseUrl/api/app-settings'),
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      log("Error fetching app settings: $e");
      return null;
    }
  }

  /// Connects once to the order WebSocket and stays connected.
  /// - Emits [true]  when service_modifications[].status == APPROVED or APPLIED
  /// - Emits [false] when service_modifications[].status == REJECTED or DECLINED
  /// - Emits nothing while status == PENDING (stream stays open)
  static Future<Stream<bool>> orderUpdatedStream(String orderId)async{
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
      final accessToken =  await getAccessToken();

      final wsUrl = "$wsBaseUrl/ws/order/$orderId/?token=$accessToken";
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      sub = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            final modification = data["modification"];
            if (modification != null) {
              final status = (modification["status"] ?? "").toString().toUpperCase();
              if (status == "APPROVED" || status == "APPLIED") {
                close(true);
                return;
              }
              if (status == "REJECTED" || status == "DECLINED") {
                close(false);
                return;
              }
            }
          } catch (e) {
          }
        },
        onError: (error) {
          close(null);
        },
        onDone: () {
          close(null);
        },
      );

      controller.onCancel = () {
        sub?.cancel();
        channel?.sink.close();
      };
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    }
    return controller.stream;
  }

  /// Bulk modify order items – add, replace, or delete services/products.
  ///
  /// [orderId] – the order UUID
  /// [reason]  – optional note from the agent
  /// [items]   – list of modification objects, each containing:
  ///   { "order_item_id", "modification_type", "item_type", "new_entity_id", "quantity" }
  static Future<bool> serviceAndProductModification(
    String orderId,
    String? reason,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final String url = '$baseUrl/api/order/order-item-modification/request/';
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'items': items,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      };


      final response = await _authorizedRequest(
        (accessToken) => http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body),
        ),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      String errorMsg = 'Request failed (${response.statusCode})';
      try {
        final errBody = jsonDecode(response.body);
        errorMsg = errBody['message'] ?? errBody['detail'] ?? errBody['error'] ?? errorMsg;
      } catch (_) {}
      throw Exception(errorMsg);
    } catch (e) {
      rethrow;
    }
  }

  /// TRACKING STREAM
  /// Receives live GPS updates from backend
  static Stream<Map<String, dynamic>> trackingStream() {
    final controller = StreamController<Map<String, dynamic>>();
    WebSocketChannel? channel;
    StreamSubscription? subscription;

    try {
      final userId =  getUserId();
      final accessToken =  getAccessToken();

      final wsUrl = "$wsBaseUrl/ws/api/tracking/log/?token=$accessToken";
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      subscription = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            controller.add(data);
          } catch (e) {
          }
        },
        onError: (error) {
          controller.addError(error);
        },
        onDone: () {
          controller.close();
        },
      );

      controller.onCancel = () {
        subscription?.cancel();
        channel?.sink.close();
      };
    } catch (e) {
      controller.addError(e);
      controller.close();
    }
    return controller.stream;
  }

  static Future<List<SlotAvailability>> getAgentSlotAvailability([String? date]) async {
    String fetchDate = date ?? DateTime.now().toString().split(' ')[0];
   try{
     final response = await _authorizedRequest(
        (accessToken) => http.get(
          Uri.parse('$baseUrl/api/slots/my-slots/?date=$fetchDate'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
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
         return [];
       }

       return list.map((json) => SlotAvailability.fromJson(json)).toList();
     }
     return [];
   }
   catch(e){
     return [];
   }
  }

  Future<List<dynamic>> getMySlots() async {
    try {
      final response = await _authorizedRequest(
        (accessToken) => http.get(
          Uri.parse('$baseUrl/api/slots/my-slots/'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<AgentOrderResponse?> agentOrder() async {
    try {
      String url = "$baseUrl/api/order/agent-orders/?is_active=true";

      final response = await _authorizedRequest(
        (accessToken) => http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return AgentOrderResponse.fromJson(data);
      } else {
        try {
          final data = jsonDecode(response.body);
          return AgentOrderResponse.fromJson(data);
        } catch (_) {
          return AgentOrderResponse(
            success: false,
            message: 'Failed to load orders (${response.statusCode})',
            orders: [],
          );
        }
      }
    } catch (e) {
      return null;
    }
  }

  static Future<List<OrderDetails>> getAgentOrderHistory({String? startDate}) async {
    try {
      String url = "$baseUrl/api/order/agent-orders/";
      if (startDate != null && startDate.isNotEmpty) {
        url += "?start_date=$startDate";
      }


      final response = await _authorizedRequest(
        (accessToken) => http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['orders'] != null) {
          List<dynamic> ordersData = [];
          if (data['orders'] is List) {
            ordersData = data['orders'] as List;
          } else if (data['orders'] is Map) {
            final Map ordersMap = data['orders'] as Map;
            if (ordersMap.containsKey('results') && ordersMap['results'] is List) {
              ordersData = ordersMap['results'] as List;
            } else if (!ordersMap.containsKey('results')) {
              ordersData = [ordersMap];
            }
          }
          return ordersData.map((json) => OrderDetails.fromJson(json as Map<String, dynamic>)).toList();
        } else if (data['results'] != null && data['results'] is List) {
          final List<dynamic> ordersData = data['results'] as List;
          return ordersData.map((json) => OrderDetails.fromJson(json as Map<String, dynamic>)).toList();
        }
      }

      String errorMsg = 'Failed to load orders (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
      } catch (_) {}
      throw Exception(errorMsg);
    } catch (e) {
      rethrow;
    }
  }

  static Future<ApiResponse<List<cat.Category>>> listServiceCategories({
    String? lat,
    String? lng,
  }) async {
    try {

      final prefs = await SharedPreferences.getInstance();
      final effectiveLat = lat ?? prefs.getDouble('user_latitude')?.toString();
      final effectiveLng = lng ?? prefs.getDouble('user_longitude')?.toString();

      String url = '$baseUrl/api/category';
      if (effectiveLat != null && effectiveLat.isNotEmpty &&
          effectiveLng != null && effectiveLng.isNotEmpty) {
        url += '?lat=$effectiveLat&lng=$effectiveLng';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> dataList = jsonData['data'] is List ? jsonData['data'] : [];
        final categories = dataList
            .map((item) => cat.Category.fromJson(item))
            .toList();
        return ApiResponse(isSuccess: true, data: categories);
      } else {
        return ApiResponse(isSuccess: false, error: _extractError(response, 'Status ${response.statusCode}'));
      }
    } on SocketException {
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException {
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e) {
      return ApiResponse(isSuccess: false, error: 'Unexpected error: $e');
    }
  }

  static String _extractError(http.Response response, String defaultMsg) {
    try {
      final jsonData = jsonDecode(response.body);
      return jsonData['message'] ?? jsonData['detail'] ?? jsonData['error'] ?? (jsonData['msg'] ?? defaultMsg);
    } catch (_) {
      return defaultMsg;
    }
  }
  //Agent Approval for Order Assignment
  static Future<bool> agentApprovalOrder(String orderID, String status,
      {String? reason}) async {
    try {
      String url = '$baseUrl/api/order/orders/$orderID/agent-approval/';
      final response = await _authorizedRequest(
        (accessToken) => http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            "status": status,
            if (reason != null) "rejection_reason_description": reason,
          }),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> listService({
    int? page,
    int? size,
    String? lat,
    String? lng,
    String? categoryId,
  }) async {
    try {
      final queryParams = {
        'include_categories': 'true',
        'include_media': 'true',
        'include_pricing': 'true',
        'include_zones': 'true',
        if (page != null) 'page': page.toString(),
        if (size != null) 'size': size.toString(),
        if (lat != null && lat.isNotEmpty) 'lat': lat,
        if (lng != null && lng.isNotEmpty) 'lng': lng,
        if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
      };

      final uri = Uri.parse('$baseUrl/api/services/').replace(queryParameters: queryParams);
      final response = await _authorizedRequest(
        (accessToken) => http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> list = [];
        bool hasMore = false;
        final currentSize = size ?? 10;
        if (data['success'] == true && data['services'] != null) {
          list = data['services'];
          // Check pagination metadata
          final pagination = data['pagination'];
          if (pagination != null) {
            hasMore = pagination['has_next'] == true ||
                pagination['next'] != null;
          } else {
            // If no pagination metadata, assume more data if we got a full page
            hasMore = list.length >= currentSize;
          }
        } else if (data.containsKey('results')) {
          list = data['results'];
          hasMore = data['next'] != null;
        } else if (data.containsKey('data')) {
          list = data['data'];
          hasMore = list.length >= currentSize;
        }


        final services = list.map((json) {
          final service = Service.fromJson(json);
          return ServiceModal.fromService(service);
        }).toList();

        return {'services': services, 'hasMore': hasMore};
      }
      return {'services': <ServiceModal>[], 'hasMore': false};
    } catch (e) {
      return {'services': <ServiceModal>[], 'hasMore': false};
    }
  }

  static Future<void> serviceModification(String orderId, String orderItemId, String serviceId, String? reason, {int? quantity}) async {
    try {
      final response = await _authorizedRequest(
        (accessToken) => http.post(
          Uri.parse('$baseUrl/api/order/service-modification/request/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            "order_id": orderId,
            "order_item_id": orderItemId,
            "new_service_id": serviceId,
            if (quantity != null) "quantity": quantity,
            if (reason != null && reason.isNotEmpty) "reason": reason,
          }),
        ),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        String errorMsg = 'Request failed (${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          errorMsg = errBody['message'] ?? errBody['detail'] ?? errBody['error'] ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<OrderDetails?> getOrderbyId(String orderId) async {
    try {
      final response = await _authorizedRequest(
        (accessToken) => http.get(
          Uri.parse('$baseUrl/api/order/orders/$orderId/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // API returns: { "success": true, "order": { ... } }
        final orderJson = data['order'] as Map<String, dynamic>? ?? data;
        return OrderDetails.fromJson(orderJson);
      }
    } catch (e) {
    }
    return null;
  }

  static Future<bool> verifyOrderOtp(String orderId, String otp) async {
    try {
      String url = '$baseUrl/api/order/orders/$orderId/verify-otp/';

      final response = await _authorizedRequest(
        (accessToken) => http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({"otp": otp}),
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<ApiResponse<bool>> updateJobStatus(String orderId, String status, {String? otp, List<Map<String, dynamic>>? inventory}) async {
    try {
      String url = '$baseUrl/api/order/orders/$orderId/update-status/';

      final response = await _authorizedRequest(
        (accessToken) => http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            "order_status": status,
            if (otp != null) "otp": otp,
            if (inventory != null) "serial_numbers": inventory,
          }),
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          return const ApiResponse(isSuccess: true, data: true);
        }
        
        // Return failure response with message from data
        final String errorMessage = data['message'] ?? data['error'] ?? 'Update failed';
        return ApiResponse(isSuccess: false, data: false, error: errorMessage);
      } else {
        // Handle non-200 status codes
        String errorMessage = "Failed to update status (${response.statusCode})";
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          errorMessage = data['message'] ?? data['error'] ?? errorMessage;
        } catch (_) {}
        
        return ApiResponse(isSuccess: false, data: false, error: errorMessage);
      }
    } catch (e) {
      return ApiResponse(isSuccess: false, data: false, error: "Error: ${e.toString()}");
    }
  }

  static Future<ApiResponse<bool?>> toggleActiveStatus() async {
    try {
      String url = '$baseUrl/api/user/toggle-active';

      final response = await _authorizedRequest(
        (accessToken) => http.patch(
          Uri.parse(url),
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool? isActive = data['data']['is_active'];
        return ApiResponse(isSuccess: true, data: isActive);
      } else {
        String message = 'Failed to toggle status';
        try {
          final data = jsonDecode(response.body);
          message = data['message'] ?? data['detail'] ?? message;
        } catch (_) {}
        return ApiResponse(isSuccess: false, error: message);
      }
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }
  static Future<void> addFcmToken() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return;
      }
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        return;
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        return;
      }

      String url = '$baseUrl/api/notifications/register-fcm/';


      final response = await _authorizedRequest(
        (accessToken) => http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            "fcm_token": fcmToken,
          }),
        ),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
      } else {
      }
    } catch (e, stack) {
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
  
  static Future<ApiResponse<MyPossessionResponse>> getProductDetails(String productId, {int page = 1, int size = 10}) async {
    try {
      final url = Uri.parse("$baseUrl/api/product-serial/my-possession/").replace(queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
       if(productId.isNotEmpty) "product_ids": productId,
      });
      final response = await _authorizedRequest(
        (accessToken) => http.get(
          url,
          headers: {
            "accept": "application/json",
            "Authorization": "Bearer $accessToken",
          },
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResponse(isSuccess: true, data: MyPossessionResponse.fromJson(data));
      } else {
        String errorMsg = 'Failed to load possessions (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
        } catch (_) {}
        return ApiResponse(isSuccess: false, error: errorMsg);
      }
    } catch (e) {
      log("Error on get Product Details $e");
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }
  static Future<ApiResponse<List<Map<String, dynamic>>>> getAgentZones() async {
    try {
      final url = Uri.parse("$baseUrl/api/agent-zones/agent/");

      final response = await _authorizedRequest(
        (accessToken) => http.get(
          url,
          headers: {
            "accept": "application/json",
            "Authorization": "Bearer $accessToken",
          },
        ),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List zones = data["data"]["zone_details"] ?? [];


        final items = zones.map((zone) {
          List coords = zone["coordinates"] ?? [];
          List<LatLng> points = [];

          for (var p in coords) {
            double? lat = (p["lat"] ?? p["latitude"])?.toDouble();
            double? lng = (p["lng"] ?? p["longitude"])?.toDouble();

            // Filter out 0,0 points which cause "too long lines"
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
               points.add(LatLng(lat, lng));
            }
          }

          return {
            "name": zone["name"] ?? "Unnamed Zone",
            "points": points,
          };
        }).toList();
        return ApiResponse(isSuccess: true, data: items);
      }

      String errorMsg = 'Failed to load zones (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
      } catch (_) {}
      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      log("ZONE API ERROR: $e");
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }


static Future<Map<String,dynamic>> getRequestDates()async{
    try{
      String url = "$baseUrl/api/tools/movement/requested-dates/";

      final response = await _authorizedRequest(
        (accessToken) => http.get(
          Uri.parse(url),
          headers: {
            "accept": "application/json",
            "Authorization": "Bearer $accessToken",
          },
        )
      );

      if(response.statusCode == 200 || response.statusCode == 201){
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return jsonData['data'];
      }
      return {};
    }
    catch(e){
      rethrow;
    }
}

  static Future<ApiResponse<PaginatedProductResponse>> listProduct({
    String? lat,
    String? lng,
    String? categoryId,
    int page = 1,
    int size = 12,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveLat = lat ?? prefs.getDouble('user_latitude')?.toString();
      final effectiveLng = lng ?? prefs.getDouble('user_longitude')?.toString();

      String url = "$baseUrl/api/product?include_attribute=true&include_brand=true&include_category=true&include_media=true&include_pricing=true&page=$page&size=$size";
      if (effectiveLat != null && effectiveLng != null) {
        url += "&lat=$effectiveLat&lng=$effectiveLng";
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        url += "&category_id=$categoryId";
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);

        // Handle various possible keys for product list
        final List<dynamic> dataList = jsonData['products'] ?? jsonData['data'] ?? jsonData['results'] ?? [];
        final List<Map<String, dynamic>> products = dataList
            .whereType<Map<String, dynamic>>()
            .toList();

        final pagination = jsonData['pagination'] ?? jsonData['meta'];

        final total = pagination != null ? (pagination['total_elements'] ?? pagination['total'] ?? products.length) : products.length;
        final totalPages = pagination != null ? (pagination['total_pages'] ?? pagination['last_page'] ?? 1) : 1;
        final currentPageNum = pagination != null ? (pagination['page'] ?? pagination['current_page'] ?? page) : page;

        // Robust hasMore check
        bool hasMore = false;
        if (pagination != null) {
          hasMore = pagination['next'] != null ||
                    pagination['has_next'] == true ||
                    (pagination['total_pages'] != null && (pagination['page'] ?? page) < pagination['total_pages']);
        } else {
          hasMore = products.length >= size;
        }


        return ApiResponse(
          isSuccess: true,
          data:PaginatedProductResponse(
            products: products,
            total: total is int ? total : int.tryParse(total.toString()) ?? products.length,
            totalPages: totalPages is int ? totalPages : int.tryParse(totalPages.toString()) ?? 1,
            currentPage: currentPageNum is int ? currentPageNum : int.tryParse(currentPageNum.toString()) ?? page,
            hasMore: hasMore,
          ),
        );
      } else {
        return ApiResponse(isSuccess: false, error: 'Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse(isSuccess: false, error: 'Network error: $e');
    }
  }

  // static Future<ApiResponse<List<ServiceCategory>>> listServiceCategories({
  //   String? lat,
  //   String? lng,
  // }) async {
  //   try {
  //
  //     final prefs = await SharedPreferences.getInstance();
  //     final effectiveLat = lat ?? prefs.getDouble('user_latitude')?.toString();
  //     final effectiveLng = lng ?? prefs.getDouble('user_longitude')?.toString();
  //
  //     String url = '$baseUrl/api/category';
  //     if (effectiveLat != null && effectiveLat.isNotEmpty &&
  //         effectiveLng != null && effectiveLng.isNotEmpty) {
  //       url += '?lat=$effectiveLat&lng=$effectiveLng';
  //     }
  //
  //     print("📦 Category List Url: $url");
  //     final response = await http.get(
  //       Uri.parse(url),
  //       headers: {
  //         'Content-Type': 'application/json',
  //       },
  //     ).timeout(const Duration(seconds: 10));
  //
  //     if (response.statusCode == 200) {
  //       final jsonData = jsonDecode(response.body);
  //       final List<dynamic> dataList = jsonData['data'] is List ? jsonData['data'] : [];
  //       final categories = dataList
  //           .map((item) => ServiceCategory.fromJson(item))
  //           .toList();
  //       return ApiResponse(isSuccess: true, data: categories);
  //     } else {
  //       return ApiResponse(isSuccess: false, error: 'Status ${response.statusCode}');
  //     }
  //   } on SocketException {
  //     return ApiResponse(isSuccess: false, error: 'No internet connection');
  //   } on TimeoutException {
  //     return ApiResponse(isSuccess: false, error: 'Request timed out');
  //   } catch (e) {
  //     return ApiResponse(isSuccess: false, error: 'Unexpected error: $e');
  //   }
  // }

  /// PUT /api/user/agent/{userId}
   Future<AgentApiResult<bool>> updateAgentProfile(
      String userId,
      Map<String, dynamic> updatedData, {
        File? profileImage,
        File? rcDocument,
        File? licenseDocument,
        File? aadharDoc,
        File? panCard,
        File? videoKyc,
      }) async {
    try {

      final accessToken = await getAccessToken();
      if (accessToken == null) {
        return AgentApiResult.failure('Not authenticated. Please login again.');
      }

      final uri = Uri.parse('$baseUrl/api/user/agent/$userId');

      // We use MultipartRequest if an image or document is provided, otherwise a standard PUT
      final hasFiles = profileImage != null || rcDocument != null || licenseDocument != null || aadharDoc != null || panCard != null || videoKyc != null;

      if (hasFiles) {
        final request = http.MultipartRequest('PUT', uri)
          ..headers.addAll({
            'accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          });

        // Add text fields
        updatedData.forEach((key, value) {
          request.fields[key] = value.toString();
        });

        if (profileImage != null) {
          final ext = _fileExtension(profileImage.path);
          request.files.add(await http.MultipartFile.fromPath(
            'profile_image',
            profileImage.path,
            contentType: http.MediaType('image', ext),
          ));
        }

        if (rcDocument != null) {
          final ext = _fileExtension(rcDocument.path);
          request.files.add(await http.MultipartFile.fromPath(
            'rc_doc',
            rcDocument.path,
            contentType: http.MediaType(ext == 'pdf' ? 'application' : 'image', ext),
          ));
        }

        if (licenseDocument != null) {
          final ext = _fileExtension(licenseDocument.path);
          request.files.add(await http.MultipartFile.fromPath(
            'license_doc',
            licenseDocument.path,
            contentType: http.MediaType(ext == 'pdf' ? 'application' : 'image', ext),
          ));
        }

        if (aadharDoc != null) {
          final ext = _fileExtension(aadharDoc.path);
          request.files.add(await http.MultipartFile.fromPath(
            'aadhar_doc',
            aadharDoc.path,
            contentType: http.MediaType(ext == 'pdf' ? 'application' : 'image', ext),
          ));
        }

        if (panCard != null) {
          final ext = _fileExtension(panCard.path);
          request.files.add(await http.MultipartFile.fromPath(
            'pan_card',
            panCard.path,
            contentType: http.MediaType('image', ext),
          ));
        }

        if (videoKyc != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'video_kyc',
            videoKyc.path,
            contentType: http.MediaType('video', 'mp4'),
          ));
        }

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
      _showError('No internet connection');
      return AgentApiResult.failure('No internet connection');
    } on TimeoutException {
      _showError('Request timed out. Please try again.');
      return AgentApiResult.failure('Request timed out. Please try again.');
    } catch (e, stack) {
      _showError('Something went wrong. Please try again.');
      return AgentApiResult.failure('Something went wrong. Please try again.');
    }
  }

  AgentApiResult<bool> _handleUpdateResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 204) {
      return AgentApiResult.success(true);
    }

    dynamic json;
    try {
      json = jsonDecode(response.body);
    } catch (e) {
      _showError('Server error (${response.statusCode}). Please contact support.');
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
          errorMsg = errors.values.first.toString();
        }
      }
    }

    _showError(errorMsg);
    // 🔹 Intercept confusing backend errors (e.g. from file pickling/size) and translate to user-friendly messages
    if (errorMsg.toString().toLowerCase().contains('pickle') ||
        errorMsg.toString().toLowerCase().contains('bufferedrandom')) {
      errorMsg = 'Video size exceeded limit';
    }

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
    return getAccessToken();
  }

  // Helper: Get access accessToken
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    return accessToken;
  }

  // Helper: Get refresh accessToken
  static Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('refresh_token');
    return accessToken;
  }

  // Helper: Clear all accessTokens (calls AuthResponse.clearTokens())
  static Future<void> _clearTokens() async {
    await AuthResponse.clearTokens();
  }

  static void _showError(String message) {
    if (message.isEmpty) return;
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.lato(color: Colors.white),
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static Future<void> _handleSessionExpiry() async {
    _showError('Session expired. Please login again.');
    await _clearTokens();
    // Use the global router to navigate to login
    app_router.router.go('/login');
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await _getRefreshToken();

    if (refreshToken == null) {
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


      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('access_token', jsonData['access']);

        if (jsonData['refresh'] != null) {
          await prefs.setString('refresh_token', jsonData['refresh']);
        }

        return true;
      } else {
        await _clearTokens();
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Public wrapper around [_refreshAccessToken] for use in UI layers.
  static Future<bool> refreshToken() => _refreshAccessToken();

  static Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(String accessToken) request,
  ) async {
    try {
      String? accessToken = await getAccessToken();

      // If no token, try to refresh immediately
      if (accessToken == null || accessToken.isEmpty) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          await _handleSessionExpiry();
          throw Exception('Session expired');
        }
        accessToken = await getAccessToken();
      }

      if (accessToken == null) {
        await _handleSessionExpiry();
        throw Exception('No access accessToken');
      }

      http.Response response = await request(accessToken);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();

        if (!refreshed) {
          await _handleSessionExpiry();
          throw Exception('Session expired');
        }

        accessToken = await getAccessToken();
        if (accessToken == null) {
          await _handleSessionExpiry();
          throw Exception('Session expired');
        }
        response = await request(accessToken);
      }

      // Handle non-success status codes
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMsg = 'Unsupported error (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
        } catch (_) {}
        _showError(errorMsg);
      }

      return response;
    } catch (e) {
      if (e is SocketException) {
        _showError('No internet connection');
      } else if (e is TimeoutException) {
        _showError('Request timed out');
      } else if (!e.toString().contains('Session expired')) {
        _showError(e.toString());
      }
      rethrow;
    }
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
        _showError('Failed to fetch version info');
        throw Exception('Version API failed');
      }

      final jsonData = jsonDecode(response.body);

      if (jsonData['success'] != true) {
        final msg = jsonData['message']?.toString() ?? 'Version API failed';
        _showError(msg);
        throw Exception(msg);
      }

      final data = jsonData['data'] ?? {};
      final rawVersion = data['partner_app_version'];
      final int serverMinBuild = int.tryParse(rawVersion?.toString() ?? '0') ?? 0;
      final String? storeUrl = data['partner_app_play_store_url'];

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
  static const String _productwsUrl = 'wss://api.itfixer199.com/ws/movements/';
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _wsIsConnecting = false;
  int _wsReconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _wsController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get   movementStream => _wsController.stream;

  // Last used filters for reconnection
  String? _lastProdWsStartDate, _lastProdWsEndDate;
  int? _lastProdWsPage, _lastProdWsSize;

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

  // Last used filters for tool reconnection
  String? _lastToolWsStartDate, _lastToolWsEndDate;
  int? _lastToolWsPage, _lastToolWsSize;

  // ── Request WebSocket ───────────────────────────────────────────────────────
  WebSocketChannel? _requestWsChannel;
  StreamSubscription? _requestWsSubscription;
  bool _requestWsIsConnecting = false;
  bool _requestWsManualDisconnect = false;
  int _requestWsReconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _requestWsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get requestStream => _requestWsController.stream;

  bool _isDisposed = false;

  Future<void> connectMovementWebSocket({
    String? startDate,
    String? endDate,
    int? page,
    int? size,
  }) async {
    if (_wsIsConnecting) return;
    _wsIsConnecting = true;

    // Persist filters for reconnection
    _lastProdWsStartDate = startDate ?? _lastProdWsStartDate;
    _lastProdWsEndDate = endDate ?? _lastProdWsEndDate;
    _lastProdWsPage = page ?? _lastProdWsPage;
    _lastProdWsSize = size ?? _lastProdWsSize;

    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        _wsIsConnecting = false;
        return;
      }

      final queryParams = <String, String>{
        'token': accessToken,
        if (_lastProdWsStartDate != null) 'start_date': _lastProdWsStartDate!,
        if (_lastProdWsEndDate != null) 'end_date': _lastProdWsEndDate!,
        if (_lastProdWsPage != null) 'page': '$_lastProdWsPage',
        if (_lastProdWsSize != null) 'size': '$_lastProdWsSize',
      };

      final uri = Uri.parse(_productwsUrl).replace(queryParameters: queryParams);
      _wsChannel = WebSocketChannel.connect(uri);
      _wsSubscription = _wsChannel!.stream.listen(
            (msg) {
          _wsReconnectAttempts = 0;
          _wsIsConnecting = false;
          if (_isDisposed) return;
          try {
            if (!_wsController.isClosed) {
              _wsController.add(jsonDecode(msg));
            }
          } catch (e) {
          }
        },
        onError: (e) {
          _wsIsConnecting = false;
          _wsReconnect();
        },
        onDone: () {
          _wsIsConnecting = false;
          _wsReconnect();
        },
      );
    } catch (e) {
      _wsIsConnecting = false;
      _wsReconnect();
    }
  }

  void _wsReconnect() {
    if (_isDisposed) return;
    _wsReconnectAttempts++;
    final delay = Duration(seconds: (2 * _wsReconnectAttempts).clamp(5, 30));
    Future.delayed(delay, () {
      if (!_wsIsConnecting && !_isDisposed) {
        connectMovementWebSocket(
          startDate: _lastProdWsStartDate,
          endDate: _lastProdWsEndDate,
          page: _lastProdWsPage,
          size: _lastProdWsSize,
        );
      }
    });
  }

  // ── Tool WebSocket Methods ──────────────────────────────────────────────────
  Future<void> connectToolMovementWebSocket({
    String? startDate,
    String? endDate,
    int? page,
    int? size,
  }) async {
    if (_toolWsIsConnecting) return;
    _toolWsIsConnecting = true;

    // Persist filters for reconnection
    _lastToolWsStartDate = startDate ?? _lastToolWsStartDate;
    _lastToolWsEndDate = endDate ?? _lastToolWsEndDate;
    _lastToolWsPage = page ?? _lastToolWsPage;
    _lastToolWsSize = size ?? _lastToolWsSize;

    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        _toolWsIsConnecting = false;
        return;
      }

      final queryParams = <String, String>{
        'token': accessToken,
        if (_lastToolWsStartDate != null) 'start_date': _lastToolWsStartDate!,
        if (_lastToolWsEndDate != null) 'end_date': _lastToolWsEndDate!,
        if (_lastToolWsPage != null) 'page': '$_lastToolWsPage',
        if (_lastToolWsSize != null) 'size': '$_lastToolWsSize',
      };

      final uri = Uri.parse(_toolWsUrl).replace(queryParameters: queryParams);

      _toolWsChannel = WebSocketChannel.connect(uri);
      _toolWsSubscription = _toolWsChannel!.stream.listen(
            (msg) {
          _toolWsReconnectAttempts = 0;
          _toolWsIsConnecting = false;
          if (_isDisposed) return;
          try {
            if (!_toolWsController.isClosed) {
              _toolWsController.add(jsonDecode(msg));
            }
          } catch (e) {
          }
        },
        onError: (e) {
          _toolWsIsConnecting = false;
          _toolWsReconnect();
        },
        onDone: () {
          _toolWsIsConnecting = false;
          _toolWsReconnect();
        },
      );
    } catch (e) {
      _toolWsIsConnecting = false;
      _toolWsReconnect();
    }
  }

  void _toolWsReconnect() {
    if (_isDisposed) return;
    _toolWsReconnectAttempts++;
    final delay = Duration(
        seconds: (2 * _toolWsReconnectAttempts).clamp(5, 30));
    Future.delayed(delay, () {
      if (!_toolWsIsConnecting && !_isDisposed) {
        connectToolMovementWebSocket(
          startDate: _lastToolWsStartDate,
          endDate: _lastToolWsEndDate,
          page: _lastToolWsPage,
          size: _lastToolWsSize,
        );
      }
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

      final ipAddress = await _getPublicIp();

      final LoginRequestModel finalRequest;

      if (request.loginType == 'PASSWORD') {
        finalRequest = LoginRequestModel.password(
          username: request.username ?? '',
          password: request.password ?? '',
          role: request.role,
          deviceType: Platform.isAndroid ? 'ANDROID' : 'IOS',
          deviceId: deviceInfo['device_id'] ?? 'unknown',
          deviceName: deviceInfo['device_name'] ?? 'unknown',
          ipAddress: ipAddress,
        );
      } else {
        finalRequest = LoginRequestModel.otp(
          mobileNumber: request.mobileNumber ?? 0,
          role: request.role,
          deviceType: Platform.isAndroid ? 'ANDROID' : 'IOS',
          deviceId: deviceInfo['device_id'] ?? 'unknown',
          deviceName: deviceInfo['device_name'] ?? 'unknown',
          ipAddress: ipAddress,
        );
      }


      final response = await http.post(
        Uri.parse('$baseUrl/api/unified-login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'accept': 'application/json',
        },
        body: finalRequest.toFormJson(),
      ).timeout(const Duration(seconds: 15));


      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json);
        await authResponse.saveTokens();
        return ApiResponse(isSuccess: true, data: authResponse, otp: authResponse.otp);
      }

      final errors = json['errors'] as List<dynamic>?;
      final errorMsg = (errors?.isNotEmpty == true)
          ? errors!.first.toString()
          : json['message']?.toString() ?? 'Login failed';

      _showError(errorMsg);
      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException catch (e) {
      _showError('No internet connection');
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException catch (e) {
      _showError('Request timed out');
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e) {
      _showError('Something went wrong');
      return ApiResponse(isSuccess: false, error: 'Something went wrong');
    }
  }


  Future<ApiResponse<String>> sendOtp(String mobileNumber) async {
    try {
      final request = SendOtpRequest(
        mobileNumber: int.tryParse(mobileNumber) ?? 0,
        role: 'AGENT',
      );


      final response = await http.post(
        Uri.parse('$baseUrl/api/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 15));


      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final msg = json['message']?.toString() ?? 'OTP sent successfully';
        final receivedOtp = (json['data']?['otp'] ?? json['otp'])?.toString(); // Capture OTP
        return ApiResponse(isSuccess: true, data: msg, otp: receivedOtp);
      }

      final errors = json['errors'] as List<dynamic>?;
      final errorMsg = (errors?.isNotEmpty == true)
          ? errors!.first.toString()
          : json['message']?.toString() ?? 'Failed to send OTP';

      _showError(errorMsg);
      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException catch (e) {
      _showError('No internet connection');
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException catch (e) {
      _showError('Request timed out');
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e) {
      _showError('Something went wrong');
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
      final ipAddress = await _getPublicIp();

      final body = {
        'mobile_number': mobileNumber,
        'otp': otp,
        'login_type': 'OTP',
        'role': 'AGENT',
        'device_type': Platform.isAndroid ? 'ANDROID' : 'IOS',
        'device_id': deviceInfo['device_id'] ?? 'unknown',
        'device_name': deviceInfo['device_name'] ?? 'unknown',
        'ip_address': ipAddress,
      };


      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));


      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // ── Deep debug: print every top-level key and its type ──────────

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

          return ApiResponse(isSuccess: true, data: verifyResponse);
        }

        // Still null after all patterns — full dump for diagnosis
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

      _showError(errorMsg);
      return ApiResponse(isSuccess: false, error: errorMsg);
    } on SocketException catch (e) {
      _showError('No internet connection');
      return ApiResponse(isSuccess: false, error: 'No internet connection');
    } on TimeoutException catch (e) {
      _showError('Request timed out');
      return ApiResponse(isSuccess: false, error: 'Request timed out');
    } catch (e, stack) {
      _showError('Something went wrong');
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
    }
      return {'device_id': 'unknown', 'device_name': 'unknown'};
  }

  Future<String> _getPublicIp() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/third-party/get-ip/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final ip = jsonData['data']['ip']?.toString() ?? '0.0.0.0';
          return ip;
        }
      }
      return '0.0.0.0';
    } catch (e) {
    }
    return '0.0.0.0';
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
    File? rcDocument,
    File? licenseDocument,
  }) async {
    try {

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
      if (rcDocument != null) {
        final ext = _fileExtension(rcDocument.path);
        multipartRequest.files.add(await http.MultipartFile.fromPath(
          'rc_doc',
          rcDocument.path,
          contentType: http.MediaType(ext == 'pdf' ? 'application' : 'image', ext),
        ));
      }
      if (licenseDocument != null) {
        final ext = _fileExtension(licenseDocument.path);
        multipartRequest.files.add(await http.MultipartFile.fromPath(
          'license_doc',
          licenseDocument.path,
          contentType: http.MediaType(ext == 'pdf' ? 'application' : 'image', ext),
        ));
      }


      // Log file sizes for debugging
      for (var file in multipartRequest.files) {
        final length = file.length;
      }

      final streamedResponse = await multipartRequest
          .send()
          .timeout(
        const Duration(seconds: 300), // Increased to 5 minutes
        onTimeout: () {
          throw TimeoutException(
              'Request timed out. Please check your internet connection or try with smaller files.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);


      if (response.body.isEmpty) {
        return AgentApiResult.failure('Server returned empty response');
      }

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (json is Map) {
          if (json['data'] != null && json['data'] is Map) {
          }
        }
        final result = AgentRegistrationResponse.fromJson(json);
        await result.saveToPrefs();
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

      return AgentApiResult.failure(errorMsg);
    } on SocketException catch (e) {
      return AgentApiResult.failure(
          'No internet connection. Check your network.');
    } on TimeoutException catch (e) {
      return AgentApiResult.failure('Request timed out. Please try again.');
    } catch (e, stack) {
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


      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        final user = jsonResponse['user'];
        if (user != null && user['agent_details'] != null) {
          final details = user['agent_details'];
        }

        return ApiResponse(
          isSuccess: true,
          data: AgentProfileResponse.fromJson(jsonResponse),
        );
      }

      final json = jsonDecode(response.body);
      return ApiResponse(
        isSuccess: false,
        error: json['message']?.toString() ?? 'Failed to fetch profile',
      );
    } catch (e) {
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


      final response = await http.post(
        Uri.parse('$baseUrl/api/logout/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 15));


      // Clear accessTokens regardless of server response success
      await AuthResponse.clearTokens();

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AgentApiResult.success(true);
      } else {
        // Return success anyway because local session is cleared,
        // but maybe log the error
        return AgentApiResult.success(true);
      }
    } catch (e) {
      // Still clear accessTokens locally on error
      await AuthResponse.clearTokens();
      return AgentApiResult.failure('Network error: ${e.toString()}');
    }
  }

// ── Helpers ───────────────────────────────────────────────────────────────────



  // ── Token Management Helpers ───────────────────────────────────────────────




  Future<ApiResponse<List<Product>>> getProducts({
    int? page,
    int? size,
    String? lat,
    String? lng,
    String? categoryId,
  }) async {
    try {
      final queryParams = {
        'include_attribute': 'true',
        'include_brand': 'true',
        'include_category': 'true',
        'include_children': 'true',
        'include_media': 'true',
        'include_pricing': 'true',
        if (page != null) 'page': '$page',
        if (size != null) 'size': '$size',
        if (lat != null && lat.isNotEmpty) 'lat': lat,
        if (lng != null && lng.isNotEmpty) 'lng': lng,
        if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
      };

      final uri = Uri.parse('$baseUrl/api/product').replace(
          queryParameters: queryParams);

      final response = await _authorizedRequest((accessToken) =>
          http.get(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'accept': 'application/json',
            },
          )).timeout(const Duration(seconds: 30));


      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];

        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
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
        return ApiResponse(isSuccess: true, data: items);
      }

      return ApiResponse(
          isSuccess: false,
          error: 'Failed to fetch products (${response.statusCode})'
      );
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  Future<ApiResponse<MovementRequest>> requestProductMovement({
    required String productId,
    required int stock,
    String type = 'GIVE',
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/product-inventory/movements/request/');

      final response = await _authorizedRequest(
        (accessToken) => http.post(
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
        ),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResponse(isSuccess: true, data: MovementRequest.fromJson(data));
      }
      String errorMsg = 'Failed to request movement (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (response.statusCode == 422 || data['errors'] != null) {
          final errors = data['errors'];
          if (data['errors'] != null) {
            errorMsg = data['errors'];
          } else {
            errorMsg = data['message'] ?? errorMsg;
          }
        } else {
          errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
        }
      } catch (_) {}
      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── Get All Tools ────────────────────────────────────────────────────────
  static Future<ApiResponse<List<Tool>>> listTools({
    String? search,
    String? categoryId,
    int page = 1,
    int size = 50,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': '$page',
        'size': '$size',
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
        if (status != null && status.isNotEmpty) 'status': status,
      };

      final url = Uri.parse('$baseUrl/api/tools/').replace(queryParameters: queryParams);

      final accessToken = await getAccessToken();
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));


      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];

        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          final data = decoded['data'];
          if (data is List) {
            raw = data;
          } else if (data is Map) {
            final inner = data['tools'] ?? data['items'] ?? data['results'];
            if (inner is List) raw = inner;
          } else {
            raw = decoded['tools'] ?? decoded['results'] ?? decoded['items'] ?? [];
          }
        }
        final items = raw.map((e) => Tool.fromJson(e)).toList();
        return ApiResponse(isSuccess: true, data: items);
      }

      return ApiResponse(isSuccess: false, error: 'Failed to fetch tools (${response.statusCode})');
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  Future<ApiResponse<List<Tool>>> getTools({
    int? page,
    int? size,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': '${page ?? 1}',
        'size': '${size ?? 10}',
      };

      final url = Uri.parse('$baseUrl/api/tools/').replace(queryParameters: queryParams);

      final response = await _authorizedRequest((accessToken) =>
          http.get(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
            },
          )).timeout(const Duration(seconds: 15));



      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];

        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
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
        return ApiResponse(isSuccess: true, data: items);
      }
      return ApiResponse(isSuccess: false,
          error: 'Failed to fetch tools (${response.statusCode})');
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  Future<ApiResponse<MovementRequest>> requestToolMovement({
    required String toolId,
    required int stock,
    String type = 'GET',
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/tools/movement/request/');

      final response = await _authorizedRequest(
        (accessToken) => http.post(
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
        ),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResponse(isSuccess: true, data: MovementRequest.fromJson(data));
      }

      String errorMsg = 'Failed to request tool movement (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (response.statusCode == 422 && data['errors'] != null) {
          final errors = data['errors'];

          if (errors['tools_id'] != null) {
            // Ensure it's a list and join messages
            if (errors['tools_id'] is List) {
              errorMsg = (errors['tools_id'] as List).join('\n');
            } else {
              errorMsg = errors['tools_id'].toString();
            }
          } else {
            errorMsg = data['message'] ?? errorMsg;
          }
        } else {
          errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
        }
      } catch (_) {}
      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── My Tool Stocks ─────────────────────────────────────────────────────────
  Future<ApiResponse<List<ToolStock>>> getMyToolStocks({
    int? page,
    int? size,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': '${page ?? 1}',
        'size': '${size ?? 10}',
      };

      final url = Uri.parse('$baseUrl/api/tools/my-stocks/').replace(queryParameters: queryParams);

      final response = await _authorizedRequest(
        (accessToken) => http.get(
          url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );


      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          // If the top level is a Map, look for 'data' or 'results' etc.
          var data = decoded['data'] ?? decoded['results'] ?? decoded['items'] ??
                       decoded['tool_stocks'] ?? decoded['stocks'];

          if (data is List) {
            raw = data;
          } else if (data is Map) {
            // If the unwrapped data is a Map, it might contain the actual list (e.g. data['stocks'] in your log)
            final innerList = data['results'] ?? data['stocks'] ?? data['items'] ?? data['tool_stocks'] ?? data['data'];
            if (innerList is List) {
              raw = innerList;
            } else {
              // Fallback: treat the map as a single item if it looks like one, or use decoded root
              raw = [data];
            }
          } else {
            // If none of the keys found a list/map, maybe the root itself is the map (older APIs)
            raw = [decoded];
          }
        }

        final items = raw.map((e) => ToolStock.fromJson(e)).toList();
        return ApiResponse(isSuccess: true, data: items);
      }
      String errorMsg = 'Tool stocks failed (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
      } catch (_) {}
      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  // ── My Product Stocks ──────────────────────────────────────────────────────
  Future<ApiResponse<List<ProductStock>>> getMyProductStocks() async {
    try {
      final url = Uri.parse('$baseUrl/api/product-inventory/my-stocks/');

      final response = await _authorizedRequest(
        (accessToken) => http.get(
          url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );


      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          var data = decoded['data'] ?? decoded['results'] ?? decoded['items'] ??
                       decoded['product_stocks'] ?? decoded['stocks'];

          if (data is List) {
            raw = data;
          } else if (data is Map) {
            final innerList = data['results'] ?? data['product_stocks'] ?? data['stocks'] ?? data['items'] ?? data['data'];
            if (innerList is List) {
              raw = innerList;
            } else {
              raw = [data];
            }
          } else {
            raw = [decoded];
          }
        }

        final items = raw.map((e) => ProductStock.fromJson(e)).toList();
        return ApiResponse(isSuccess: true, data: items);
      }
      String errorMsg = 'Product stocks failed (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
      } catch (_) {}
      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
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
      final accessToken = await getAccessToken();
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


      final streamedResponse = await request.send().timeout(
          const Duration(seconds: 300));
      final response = await http.Response.fromStream(streamedResponse);


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
      final accessToken = await getAccessToken();
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


      final response = await http.post(
        Uri.parse('$baseUrl/api/request/slot-change/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(bodyMap),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(isSuccess: true, data: jsonDecode(response.body));
      }
      
      final json = jsonDecode(response.body);
      String errorMsg = 'Failed to create slot change request';
      if (json is Map && json['message'] != null) {
        errorMsg = json['message'].toString();
      } else if (json is Map && json['errors'] != null) {
        errorMsg = json['errors'].toString();
      }
      
      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> verifyRequestOtp(String requestId, String otp) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        return ApiResponse(isSuccess: false, error: 'Not authenticated');
      }

      final url = Uri.parse('$baseUrl/api/request/delivery/verify-otp/$requestId/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"otp": otp}),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(isSuccess: true, data: jsonDecode(response.body));
      }

      final json = jsonDecode(response.body);
      String errorMsg = 'Failed to verify OTP';
      if (json is Map && json['message'] != null) {
        errorMsg = json['message'].toString();
      } else if (json is Map && json['errors'] != null) {
        errorMsg = json['errors'].toString();
      }

      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateHubServiceStatus(
    String requestId,
    String status, {
    String? notes,
    bool visibleToCustomer = true,
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        return ApiResponse(isSuccess: false, error:  'Not authenticated');
      }

      final url = Uri.parse('$baseUrl/api/request/tracking/$requestId/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "hub_status": status,
          if (notes != null) "notes": notes,
          "visible_to_customer": visibleToCustomer,
        }),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(isSuccess: true, data: jsonDecode(response.body));
      }

      final json = jsonDecode(response.body);
      String errorMsg = 'Failed to update status';
      if (json is Map && json['message'] != null) {
        errorMsg = json['message'].toString();
      } else if (json is Map && json['errors'] != null) {
        errorMsg = json['errors'].toString();
      }

      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
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
      final accessToken = await getAccessToken();
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


      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(isSuccess: true, data: jsonDecode(response.body));
      }
      
      final json = jsonDecode(response.body);
      String errorMsg = 'Failed to create cancellation request';
      if (json is Map && json['message'] != null) {
        errorMsg = json['message'].toString();
      } else if (json is Map && json['errors'] != null) {
        errorMsg = json['errors'].toString();
      }
      
      return ApiResponse(isSuccess: false, error: errorMsg);
    } catch (e) {
      return ApiResponse(isSuccess: false, error: e.toString());
    }
  }

  Future<AgentApiResult<List<SlotAvailability>>> getAvailableSlotsByLocation({
    required double lat,
    required double lng,
    String? agentId,
  }) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        return AgentApiResult.failure('Not authenticated');
      }

      final uri = Uri.parse(
          '$baseUrl/api/slots/available-slots/?lat=$lat&lng=$lng${agentId != null ? "&agent_id=$agentId" : ""}');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));


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
      return AgentApiResult.failure('Error: $e');
    }
  }

  Future<void> connectRequestWebSocket({
    String? startDate,
    String? endDate,
    int? page,
    int? size,
  }) async {
    if (_requestWsIsConnecting) return;
    _requestWsIsConnecting = true;
    _requestWsManualDisconnect = false;

    try {
      final token = await ApiService.getAccessToken();
      if (token == null) {
        _requestWsIsConnecting = false;
        return;
      }

      final wsBase = baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final queryParams = <String, String>{
        'token': token,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (page != null) 'page': page.toString(),
        if (size != null) 'size': size.toString(),
      };

      final uri = Uri.parse('$wsBase/ws/requests/').replace(queryParameters: queryParams);

      _requestWsChannel = WebSocketChannel.connect(uri);
      _requestWsSubscription = _requestWsChannel!.stream.listen(
        (msg) {
          _requestWsReconnectAttempts = 0;
          _requestWsIsConnecting = false;
          if (_isDisposed) return;
          try {
            if (!_requestWsController.isClosed) {
              _requestWsController.add(jsonDecode(msg));
            }
          } catch (e) {
          }
        },
        onError: (e) {
          _requestWsIsConnecting = false;
          if (!_requestWsManualDisconnect) {
            _requestWsReconnect(startDate: startDate, endDate: endDate, page: page, size: size);
          }
        },
        onDone: () {
          _requestWsIsConnecting = false;
          if (!_requestWsManualDisconnect) {
            _requestWsReconnect(startDate: startDate, endDate: endDate, page: page, size: size);
          }
        },
      );
    } catch (e) {
      _requestWsIsConnecting = false;
      if (!_requestWsManualDisconnect) {
        _requestWsReconnect(startDate: startDate, endDate: endDate, page: page, size: size);
      }
    }
  }

  void _requestWsReconnect({
    String? startDate,
    String? endDate,
    int? page,
    int? size,
  }) {
    if (_isDisposed || _requestWsManualDisconnect) return;
    _requestWsReconnectAttempts++;
    final delay = Duration(seconds: (2 * _requestWsReconnectAttempts).clamp(5, 30));
    Future.delayed(delay, () {
      if (!_requestWsIsConnecting && !_isDisposed && !_requestWsManualDisconnect) {
        connectRequestWebSocket(
          startDate: startDate,
          endDate: endDate,
          page: page,
          size: size,
        );
      }
    });
  }

  void updateRequestFilters({
    String? startDate,
    String? endDate,
    int? page,
    int? size,
  }) {
    if (_requestWsChannel == null) return;

    final filterMessage = {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (page != null) 'page': page,
      if (size != null) 'size': size,
    };

    _requestWsChannel!.sink.add(jsonEncode(filterMessage));
  }

  void disconnectRequestWebSocket() {
    _requestWsManualDisconnect = true;
    _requestWsSubscription?.cancel();
    _requestWsSubscription = null;
    _requestWsChannel?.sink.close();
    _requestWsChannel = null;
  }
}