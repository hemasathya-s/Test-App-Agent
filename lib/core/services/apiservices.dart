import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:urban_agent_app/core/model/order_details.dart';
import '../model/slot_availability.dart';

class ApiService {
  static String baseUrl = 'https://api.itfixer199.com';
  static String accessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzcyMzA1NDM2LCJpYXQiOjE3NzIyNTE0MzcsImp0aSI6IjIyNDgzYTY0MjkwZDQxZTliYjE2NTc5NzYxYWZjZWM3IiwidXNlcl9pZCI6ImUzYWM4OTQ3LTdhYzktNDYwOS05NGVlLTczZjNjYmU4ZWM1NiJ9.tHshbYUT8Rje3C8lycCjPsmcOQpGyuCODJxo4p0XS74';

  static Future<List<SlotAvailability>> getAgentSlotAvailability(String date) async {
    try {
      String url = '$baseUrl/api/slots/my-slots/?date=$date';

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

  static Future<void> agentApprovalOrder(String orderID, String status) async {
    try {
      String url = '$baseUrl/api/order/orders/$orderID/agent-approval/';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Order $orderID approval status updated to $status");
      }
    } catch (e) {
      print("Error on agent Approval order $e");
    }
  }

  static Future<void> updateJobStatus(String orderId, String status) async {
    try {
      String url = '$baseUrl/api/order/orders/$orderId/update-status/';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Job $orderId status successfully updated to $status");
      }
    } catch (e) {
      print("Error on update job status: $e");
    }
  }

  static Future<bool?> toggleActiveStatus() async {
    try {
      String url = '$baseUrl/api/user/toggle-active';
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['is_active'] as bool?;
      }
    } catch (e) {
      print("Error toggling active status: $e");
    }
    return null;
  }

  Future<List<dynamic>> getMySlots() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/slots/my-slots/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);
        
        // Fix: Explicitly return a list to avoid type casting error
        if (decodedData is List) {
          return decodedData;
        } else if (decodedData is Map) {
          if (decodedData.containsKey('results') && decodedData['results'] is List) {
            return decodedData['results'];
          } else if (decodedData.containsKey('data') && decodedData['data'] is List) {
            return decodedData['data'];
          }
        }
        return [];
      }
    } catch (e) {
      print('Error fetching slots: $e');
    }
    return [];
  }
}
