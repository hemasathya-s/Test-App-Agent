import 'order_details.dart';

class AgentOrderResponse {
  final bool? success;
  final String? message;
  final List<OrderDetails>? orders;

  AgentOrderResponse({this.success, this.message, this.orders});

  factory AgentOrderResponse.fromJson(Map<String, dynamic> json) {
    return AgentOrderResponse(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      orders: json['orders'] != null
          ? (json['orders'] as List).map((i) => OrderDetails.fromJson(i)).toList()
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
