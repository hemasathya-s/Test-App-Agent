import 'order_details.dart';

class SlotAvailability {
  final String? id;
  final String? agent;
  final String? agentUserName;
  final String? slot;
  final String? slotName;
  final String? zone;
  final String? zoneName;
  final String? orderId;
  final OrderDetails? orderDetails;
  final String? date;
  final String? etaStartTime;
  final String? etaEndTime;
  final String? status;
  final bool? isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SlotAvailability({
    this.id,
    this.agent,
    this.agentUserName,
    this.slot,
    this.slotName,
    this.zone,
    this.zoneName,
    this.orderId,
    this.date,
    this.etaStartTime,
    this.etaEndTime,
    this.status,
    this.isAvailable,
    this.createdAt,
    this.updatedAt,
    this.orderDetails,
  });

  factory SlotAvailability.fromJson(Map<String, dynamic> json) {
    // Helper to extract ID from potentially nested objects
    String? extractId(dynamic value) {
      if (value == null) return null;
      if (value is Map) return value['id']?.toString();
      return value.toString();
    }

    // Agent info
    final agentData = json['agent'];
    final agentName = (agentData is Map)
        ? agentData['user_name']?.toString()
        : json['agent_user_name']?.toString();

    // Slot info
    final slotData = json['slot'];
    final slotName = (slotData is Map)
        ? slotData['name']?.toString()
        : json['slot_name']?.toString();

    // Zone info
    final zoneData = json['zone'];
    final zoneName = (zoneData is Map)
        ? zoneData['name']?.toString()
        : ((slotData is Map)
            ? slotData['zone_name']?.toString()
            : json['zone_name']?.toString());

    return SlotAvailability(
      id: extractId(json['id']),
      agent: extractId(agentData),
      agentUserName: agentName,
      slot: extractId(slotData),
      slotName: slotName,
      zone: extractId(zoneData),
      zoneName: zoneName,
      orderId: extractId(json['order_id']),
      date: json['date']?.toString(),
      orderDetails: json['order_details'] != null
          ? OrderDetails.fromJson(json['order_details'])
          : (json['order_id'] is Map
              ? OrderDetails.fromJson(json['order_id'] as Map<String, dynamic>)
              : null),
      etaStartTime: json['eta_start_time']?.toString(),
      etaEndTime: json['eta_end_time']?.toString(),
      status: json['status']?.toString(),
      isAvailable: json['is_available'] ?? (json['status']?.toString().toUpperCase() == 'AVAILABLE'),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agent': agent,
      'agent_user_name': agentUserName,
      'slot': slot,
      'slot_name': slotName,
      'zone': zone,
      'zone_name': zoneName,
      'order_id': orderId,
      'date': date,
      'eta_start_time': etaStartTime,
      'eta_end_time': etaEndTime,
      'status': status,
      'is_available': isAvailable,
      'order_details': orderDetails,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
