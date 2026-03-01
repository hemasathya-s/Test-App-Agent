import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_agent_app/core/model/ServiceModal.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/agent_order_response.dart';
import '../model/slot_availability.dart';
class ApiService{

  static String baseUrl ='https://api.itfixer199.com';
  static String accessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzcyNDQ4OTYzLCJpYXQiOjE3NzIzOTQ5NjMsImp0aSI6IjliYzM0Yzg2OTQyOTRiMDY5N2EyNGE2MTE5OWIwMzNmIiwidXNlcl9pZCI6ImUzYWM4OTQ3LTdhYzktNDYwOS05NGVlLTczZjNjYmU4ZWM1NiJ9.EbXaprpW-_D7LBfYB_-6ZqPJeBYsCU83bSM1HEtdw-Y";
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
      final prefs = await SharedPreferences.getInstance();
      final effectiveLat = lat ?? prefs.getDouble('user_latitude')?.toString();
      final effectiveLng = lng ?? prefs.getDouble('user_longitude')?.toString();

      String url = '$baseUrl/api/services/?include_categories=true&include_media=true&include_pricing=true&include_zones=true';
      if (effectiveLat != null && effectiveLat.isNotEmpty &&
          effectiveLng != null && effectiveLng.isNotEmpty) {
        url += '&lat=$effectiveLat&lng=$effectiveLng';
      }

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



  static Future<bool> updateJobStatus(String orderId, String status) async {
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



}