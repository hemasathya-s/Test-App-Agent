import 'package:urban_agent_app/core/model/order_details.dart';

class AgentOrderResponse {
  final bool? success;
  final List<OrderDetails>? orders;

  AgentOrderResponse({this.success, this.orders});

  factory AgentOrderResponse.fromJson(Map<String, dynamic> json) {
    return AgentOrderResponse(
      success: json['success'] as bool?,
      orders: json['orders'] != null
          ? (json['orders'] as List).map((i) => OrderDetails.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'orders': orders?.map((i) => i.toJson()).toList(),
    };
  }
}
