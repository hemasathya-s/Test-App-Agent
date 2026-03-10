import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_agent_app/core/model/ServiceModal.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/agent_order_response.dart';
import '../model/slot_availability.dart';

class ApiService {
  static const String baseUrl = 'https://api.itfixer199.com';
  static const String wsBaseUrl = "wss://api.itfixer199.com";

  static String accessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzczMTc5MTQ3LCJpYXQiOjE3NzMxMjUxNDcsImp0aSI6IjhmZWQ0YWRkZDk0OTRiODk4MzBhNzY1ZmQzOTczZGIzIiwidXNlcl9pZCI6ImUzYWM4OTQ3LTdhYzktNDYwOS05NGVlLTczZjNjYmU4ZWM1NiJ9.djd9pcmI_FapifZ7cn4OM3h_hJDCrFBFIdggVBYHRZU";
  static String refresh = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTc3MzM3NzQ3NSwiaWF0IjoxNzcyNzcyNjc1LCJqdGkiOiI0NTU0NDdlZTJmZWI0Y2M4OWZiYTU4YWEzZjYxNzQ5NiIsInVzZXJfaWQiOiJlM2FjODk0Ny03YWM5LTQ2MDktOTRlZS03M2YzY2JlOGVjNTYifQ.hsKt1SQSqlyBHaEGi0VKu57aHwtbfFunOZxs1qwMa34";

  /// Connects once to the order WebSocket and stays connected.
  /// - Emits [true]  when service_modifications[].status == APPROVED or APPLIED
  /// - Emits [false] when service_modifications[].status == REJECTED or DECLINED
  /// - Emits nothing while status == PENDING (stream stays open)
  static Stream<bool> orderUpdatedStream(String orderId) {
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
      final wsUrl = "$wsBaseUrl/ws/order/$orderId/?token=$accessToken";
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
      final wsUrl = "$wsBaseUrl/ws/api/tracking/log/?token=$accessToken";
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
    try {
      String url = '$baseUrl/api/slots/my-slots/?date=$fetchDate';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        List<dynamic> list;
        if (decodedData is List) {
          list = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('results')) {
          list = decodedData['results'];
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          list = decodedData['data'];
        } else {
          return [];
        }
        return list.map((json) => SlotAvailability.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Error on get Agent Slot $e");
      return [];
    }
  }

  // Future<List<dynamic>> getMySlots() async {
  //   final token = accessToken;
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/api/slots/my-slots/'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     }
  //   } catch (e) {
  //     print('Error fetching slots: $e');
  //   }
  //   return [];
  // }

  static Future<List<OrderDetails>?> agentOrder() async {
    try {
      String url = "$baseUrl/api/order/agent-orders/?is_active=true";
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return AgentOrderResponse.fromJson(data).orders;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<OrderDetails>> getAgentOrderHistory() async {
    try {
      String url = "$baseUrl/api/order/agent-orders/";
      final response = await http.get(
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

  static Future<bool> agentApprovalOrder(String orderID, String status, {String? reason}) async {
    try {
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
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      print("Error on agent Approval order $e");
      return false;
    }
  }

  static Future<List<ServiceModal>> listService({String? lat, String? lng}) async {
    try {
      String url = '$baseUrl/api/services/?include_categories=true&include_media=true&include_pricing=true&include_zones=true';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> list = [];
        if (data['success'] == true && data['services'] != null) {
          list = data['services'];
        } else if (data.containsKey('results')) {
          list = data['results'];
        } else if (data.containsKey('data')) {
          list = data['data'];
        }
        return list.map((json) {
          final service = Service.fromJson(json);
          return ServiceModal.fromService(service);
        }).toList();
      }
      return [];
    } catch (e) {
      print("Error on list Service $e");
      return [];
    }
  }

  static Future<void> serviceModification(String orderId, String orderItemId, String serviceId, String? reason) async {
    try {
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
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('serviceModification failed: ${response.statusCode}');
      }
    } catch (e) {
      print("Error on service modification $e");
      rethrow;
    }
  }

  static Future<OrderDetails?> getOrderbyId(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/order/orders/$orderId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
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
}
