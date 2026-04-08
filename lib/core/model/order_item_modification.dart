
class OrderItemModification {
  final String? id;
  final List<ModificationItem>? modificationItems;
  final String? reason;
  final String? status;
  final String? createdAt;
  final Map<String, dynamic>? orderDetails;
  final Map<String, dynamic>? agentDetails;
  final Map<String, dynamic>? zoneDetails;
  final Map<String, dynamic>? customerDetails;

  OrderItemModification({
    this.id,
    this.modificationItems,
    this.reason,
    this.status,
    this.createdAt,
    this.orderDetails,
    this.agentDetails,
    this.zoneDetails,
    this.customerDetails,
  });

  factory OrderItemModification.fromJson(Map<String, dynamic> json) {
    return OrderItemModification(
      id: json['id'],
      modificationItems: (json['modification_items'] as List?)
          ?.map((item) => ModificationItem.fromJson(item))
          .toList(),
      reason: json['reason'],
      status: json['status'],
      createdAt: json['created_at'],
      orderDetails: json['order_details'],
      agentDetails: json['agent_details'],
      zoneDetails: json['zone_details'],
      customerDetails: json['customer_details'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'modification_items': modificationItems?.map((i) => i.toJson()).toList(),
      'reason': reason,
      'status': status,
      'created_at': createdAt,
      'order_details': orderDetails,
      'agent_details': agentDetails,
      'zone_details': zoneDetails,
      'customer_details': customerDetails,
    };
  }

  bool get isApproved {
    final st = (status ?? '').toUpperCase();
    return st == 'APPLIED' || st == 'APPROVED';
  }

  bool get isPending {
    final st = (status ?? '').toUpperCase();
    return st == 'PENDING' || st == 'REQUESTED';
  }

  bool get isRejected {
    final st = (status ?? '').toUpperCase();
    return st == 'REJECTED' || st == 'DECLINED';
  }
}

class ModificationItem {
  final String? id;
  final Map<String, dynamic>? originalEntityDetails;
  final Map<String, dynamic>? newEntityDetails;
  final String? orderItemId;
  final String? modificationType;
  final String? itemType;
  final String? originalPrice;
  final String? newPrice;
  final int? quantity;

  ModificationItem({
    this.id,
    this.originalEntityDetails,
    this.newEntityDetails,
    this.orderItemId,
    this.modificationType,
    this.itemType,
    this.originalPrice,
    this.newPrice,
    this.quantity,
  });

  factory ModificationItem.fromJson(Map<String, dynamic> json) {
    return ModificationItem(
      id: json['id'],
      originalEntityDetails: json['original_entity_details'],
      newEntityDetails: json['new_entity_details'],
      orderItemId: json['order_item_id'],
      modificationType: json['modification_type'],
      itemType: json['item_type'],
      originalPrice: json['original_price'],
      newPrice: json['new_price'],
      quantity: json['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_entity_details': originalEntityDetails,
      'new_entity_details': newEntityDetails,
      'order_item_id': orderItemId,
      'modification_type': modificationType,
      'item_type': itemType,
      'original_price': originalPrice,
      'new_price': newPrice,
      'quantity': quantity,
    };
  }

  String? get originalName => originalEntityDetails?['name'];
  String? get newName => newEntityDetails?['name'];

  String? get originalImageUrl {
    final media = originalEntityDetails?['media'] as List?;
    if (media != null && media.isNotEmpty) {
      return media[0]['url'];
    }
    return null;
  }

  String? get newImageUrl {
    final media = newEntityDetails?['media'] as List?;
    if (media != null && media.isNotEmpty) {
      return media[0]['url'];
    }
    return null;
  }

  bool get isReplace => (modificationType ?? '').toUpperCase() == 'REPLACE';
  bool get isAdd => (modificationType ?? '').toUpperCase() == 'ADD';
  bool get isRemove => (modificationType ?? '').toUpperCase() == 'REMOVE' || (modificationType ?? '').toUpperCase() == 'DELETE';
}
