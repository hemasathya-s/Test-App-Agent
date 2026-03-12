// Model for service_modifications entries in the order API response
class ServiceModification {
  final String? id;
  final String? orderId;
  final String? orderItemId;
  final String? agentId;
  final String? zoneId;
  final String? modificationType;
  final String? originalServiceId;
  final String? newServiceId;
  final String? originalPrice;
  final String? newPrice;
  final String? reason;
  final String? customerConfirmation;
  final String? approvedCustomerUserId;
  final String? approvedAdminId;
  final bool? isAdminApproved;
  final String? status;
  final String? createdAt;
  final String? createdBy;

  // Nested detail objects (typed loosely to avoid dependency issues)
  final Map<String, dynamic>? orderDetails;
  final Map<String, dynamic>? orderItemDetails;
  final Map<String, dynamic>? agentDetails;
  final Map<String, dynamic>? originalServiceDetails;
  final Map<String, dynamic>? newServiceDetails;
  final Map<String, dynamic>? zoneDetails;
  final Map<String, dynamic>? approvedAdminDetails;
  final Map<String, dynamic>? approvedCustomerDetails;
  final Map<String, dynamic>? requestedBy;

  ServiceModification({
    this.id,
    this.orderId,
    this.orderItemId,
    this.agentId,
    this.zoneId,
    this.modificationType,
    this.originalServiceId,
    this.newServiceId,
    this.originalPrice,
    this.newPrice,
    this.reason,
    this.customerConfirmation,
    this.approvedCustomerUserId,
    this.approvedAdminId,
    this.isAdminApproved,
    this.status,
    this.createdAt,
    this.createdBy,
    this.orderDetails,
    this.orderItemDetails,
    this.agentDetails,
    this.originalServiceDetails,
    this.newServiceDetails,
    this.zoneDetails,
    this.approvedAdminDetails,
    this.approvedCustomerDetails,
    this.requestedBy,
  });

  factory ServiceModification.fromJson(Map<String, dynamic> json) {
    return ServiceModification(
      id: json['id'] as String?,
      orderId: json['order_id'] as String?,
      orderItemId: json['order_item_id'] as String?,
      agentId: json['agent_id'] as String?,
      zoneId: json['zone_id'] as String?,
      modificationType: json['modification_type'] as String?,
      originalServiceId: json['original_service_id'] as String?,
      newServiceId: json['new_service_id'] as String?,
      originalPrice: json['original_price'] as String?,
      newPrice: json['new_price'] as String?,
      reason: json['reason'] as String?,
      customerConfirmation: json['customer_confirmation'] as String?,
      approvedCustomerUserId: json['approved_customer_user_id'] as String?,
      approvedAdminId: json['approved_admin_id'] as String?,
      isAdminApproved: json['is_admin_approved'] as bool?,
      status: json['status'] as String?,
      createdAt: json['created_at'] as String?,
      createdBy: json['created_by'] as String?,
      orderDetails: json['order_details'] as Map<String, dynamic>?,
      orderItemDetails: json['order_item_details'] as Map<String, dynamic>?,
      agentDetails: json['agent_details'] as Map<String, dynamic>?,
      originalServiceDetails: json['original_service_details'] as Map<String, dynamic>?,
      newServiceDetails: json['new_service_details'] as Map<String, dynamic>?,
      zoneDetails: json['zone_details'] as Map<String, dynamic>?,
      approvedAdminDetails: json['approved_admin_details'] as Map<String, dynamic>?,
      approvedCustomerDetails: json['approved_customer_details'] as Map<String, dynamic>?,
      requestedBy: json['requested_by'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'order_item_id': orderItemId,
      'agent_id': agentId,
      'zone_id': zoneId,
      'modification_type': modificationType,
      'original_service_id': originalServiceId,
      'new_service_id': newServiceId,
      'original_price': originalPrice,
      'new_price': newPrice,
      'reason': reason,
      'customer_confirmation': customerConfirmation,
      'approved_customer_user_id': approvedCustomerUserId,
      'approved_admin_id': approvedAdminId,
      'is_admin_approved': isAdminApproved,
      'status': status,
      'created_at': createdAt,
      'created_by': createdBy,
      'order_details': orderDetails,
      'order_item_details': orderItemDetails,
      'agent_details': agentDetails,
      'original_service_details': originalServiceDetails,
      'new_service_details': newServiceDetails,
      'zone_details': zoneDetails,
      'approved_admin_details': approvedAdminDetails,
      'approved_customer_details': approvedCustomerDetails,
      'requested_by': requestedBy,
    };
  }

  /// Convenience getter: true if this modification is approved/applied
  bool get isApproved {
    final st = (status ?? '').toUpperCase();
    final cc = (customerConfirmation ?? '').toUpperCase();
    return st == 'APPLIED' || st == 'APPROVED' ||
        cc == 'APPLIED' || cc == 'APPROVED';
  }

  /// Convenience getter: true if this modification is rejected/declined
  bool get isRejected {
    final st = (status ?? '').toUpperCase();
    return st == 'REJECTED' || st == 'DECLINED';
  }

  /// New service name (from new_service_details)
  String? get newServiceName =>
      newServiceDetails?['name'] as String?;

  /// Original service name (from original_service_details)
  String? get originalServiceName =>
      originalServiceDetails?['name'] as String?;
}
