import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_agent_app/core/model/ServiceModal.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/agent_order_response.dart';
import '../model/slot_availability.dart';
class ApiService{

  static String baseUrl ='https://api.itfixer199.com';
  static String accessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzcyNDAzMDgzLCJpYXQiOjE3NzIzNDkwODMsImp0aSI6ImQ5NjI3MjIyYmRkMzQ3YjY4NDcxZTlkMTNmM2RmMjMzIiwidXNlcl9pZCI6ImUzYWM4OTQ3LTdhYzktNDYwOS05NGVlLTczZjNjYmU4ZWM1NiJ9.WoDHSjmtNolTYVF7ZN71b2oXujcjFxJflHMK4Jkrgt8';

  static Future<List<SlotAvailability>> getAgentSlotAvailability([String? date])async{
    String fetchDate = date ?? DateTime.now().toString().split(' ')[0];
   try{

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
    final token = accessToken;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/slots/my-slots/'),
        headers: {
          'Authorization': 'Bearer $token',
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
        return AgentOrderResponse.fromJson(data).orders;
      }
      return null;
    } catch (e) {
      print("Error on agent Order $e");
      return null;
    }
  }

  static Future<List<OrderDetails>> getAgentOrderHistory()async{
    try{
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

  static Future<List<ServiceModal>> listService({ String? lat,
    String? lng,})async{
    try{
      // final prefs = await SharedPreferences.getInstance();
      // final effectiveLat = lat ?? prefs.getDouble('user_latitude')?.toString();
      // final effectiveLng = lng ?? prefs.getDouble('user_longitude')?.toString();

      String url = '$baseUrl/api/services/?include_categories=true&include_media=true&include_pricing=true&include_zones=true';
      // if (effectiveLat != null && effectiveLat.isNotEmpty &&
      //     effectiveLng != null && effectiveLng.isNotEmpty) {
      //   url += '&lat=$effectiveLat&lng=$effectiveLng';
      // }

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
    }
    catch(e){
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
  static Stream<bool> orderUpdatedStream(String orderId) {
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
      final wsBase = baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final wsUrl = '$wsBase/ws/order/$orderId/?token=$accessToken';
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
                close(true);  // status changed → show Approved sheet
                return;
              }
              if (st == 'REJECTED' || st == 'DECLINED') {
                close(false); // status changed → show Rejected sheet
                return;
              }
              // PENDING → WS stays open, buffer keeps showing
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
  }

  /// Fetches a single [OrderDetails] by [orderId] and returns it.
  /// Returns null if the request fails.
  static Future<OrderDetails?> getOrderbyId(String orderId) async {
    try {
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
}
