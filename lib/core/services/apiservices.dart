import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:urban_agent_app/core/model/order_details.dart';
import '../model/slot_availability.dart';
class ApiService{

  static String baseUrl ='https://api.itfixer199.com';
  static String accessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzcyMzA1NDM2LCJpYXQiOjE3NzIyNTE0MzcsImp0aSI6IjIyNDgzYTY0MjkwZDQxZTliYjE2NTc5NzYxYWZjZWM3IiwidXNlcl9pZCI6ImUzYWM4OTQ3LTdhYzktNDYwOS05NGVlLTczZjNjYmU4ZWM1NiJ9.tHshbYUT8Rje3C8lycCjPsmcOQpGyuCODJxo4p0XS74';


  static Future<List<SlotAvailability>> getAgentSlotAvailability(String date)async{
   try{

     String url = '$baseUrl/api/slots/my-slots/?date=$date';

     final response = await http.get(
       Uri.parse(url),
       headers: {
         'Content-Type': 'application/json',
         'Authorization': 'Bearer $accessToken',
       },
     );
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
  static Future<void> agentApprovalOrder(String orderID,String status)async{
    try{
      String url = '$baseUrl/api/order/orders/$orderID/agent-approval/';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "status":status
        })
      );

      if(response.statusCode == 200 || response.statusCode == 201){
        
      }
    }
    catch(e){
      print("Error on agent Approval order $e");
    }
  }
}