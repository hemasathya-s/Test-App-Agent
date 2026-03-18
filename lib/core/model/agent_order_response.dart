import 'order_details.dart';

class AgentOrderResponse {
  final bool? success;
  final String? message;
  final List<OrderDetails>? orders;

  AgentOrderResponse({this.success, this.message, this.orders});

  factory AgentOrderResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic>? ordersList;
    if (json['orders'] != null) {
      if (json['orders'] is List) {
        ordersList = json['orders'] as List;
      } else if (json['orders'] is Map) {
        final Map ordersMap = json['orders'] as Map;
        if (ordersMap.containsKey('results') && ordersMap['results'] is List) {
          ordersList = ordersMap['results'] as List;
        } else if (!ordersMap.containsKey('results')) {
          ordersList = [ordersMap];
        }
      }
    } else if (json['results'] != null) {
      if (json['results'] is List) {
        ordersList = json['results'] as List;
      } else if (json['results'] is Map) {
        ordersList = [json['results']];
      }
    } else if (json['data'] != null) {
      if (json['data'] is List) {
        ordersList = json['data'] as List;
      } else if (json['data'] is Map) {
         if ((json['data'] as Map).containsKey('orders') && json['data']['orders'] is List) {
            ordersList = json['data']['orders'] as List;
         } else {
            ordersList = [json['data']];
         }
      }
    }

    // fallback if json itself represents an order list
    if (ordersList == null && json.containsKey('id')) {
       ordersList = [json];
    }

    return AgentOrderResponse(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      orders: ordersList != null
          ? ordersList.map((i) => OrderDetails.fromJson(i as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'orders': orders?.map((i) => i.toJson()).toList(),
    };
  }
}
