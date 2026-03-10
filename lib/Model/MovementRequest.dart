import 'dart:convert';

class MovementRequest {
  final String id;
  final String agentId;
  final String agent;
  final String product;
  final String productId;
  final String hubId;
  final String hubName;
  final int stock;
  final String type;
  final String approvedStatus;

  MovementRequest({
    required this.id,
    required this.agentId,
    required this.agent,
    required this.product,
    required this.productId,
    required this.hubId,
    required this.hubName,
    required this.stock,
    required this.type,
    required this.approvedStatus,
  });

  factory MovementRequest.fromJson(Map<String, dynamic> json) {
    // Handle nested agent object
    String agentName = '';
    if (json['agent'] is Map) {
      agentName = json['agent']['user_name'] ?? '';
    } else if (json['agent'] is String) {
      agentName = json['agent'];
    }

    // Handle nested product object
    String productName = '';
    String pId = json['product_id'] ?? '';
    if (json['product'] is Map) {
      productName = json['product']['name'] ?? '';
      if (pId.isEmpty) pId = json['product']['id'] ?? '';
    } else if (json['product'] is String) {
      productName = json['product'];
    }

    return MovementRequest(
      id: json['id'] ?? '',
      agentId: json['agent_id'] ?? '',
      agent: agentName,
      product: productName,
      productId: pId,
      hubId: json['hub_id'] ?? '',
      hubName: json['hub_name'] ?? '',
      stock: json['stock'] ?? 0,
      type: json['type'] ?? 'GIVE',
      approvedStatus: json['approved_status'] ?? 'PENDING',
    );
  }
}
