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
    this.createdAt,
    this.updatedAt,
    this.orderDetails,
  });

  factory SlotAvailability.fromJson(Map<String, dynamic> json) {
    final agentData = json['agent'];
    final slotData = json['slot'];
    final zoneData = json['zone'];

    return SlotAvailability(
      id: json['id'] as String?,
      agent: agentData is Map ? agentData['id'] as String? : agentData as String?,
      agentUserName: agentData is Map ? agentData['user_name'] as String? : json['agent_user_name'] as String?,
      slot: slotData is Map ? slotData['id'] as String? : slotData as String?,
      slotName: slotData is Map ? slotData['name'] as String? : json['slot_name'] as String?,
      zone: zoneData is Map ? zoneData['id'] as String? : zoneData as String?,
      zoneName: zoneData is Map ? zoneData['name'] as String? : json['zone_name'] as String?,
      orderId: json['order_id'] as String?,
      date: json['date'] as String?,
      orderDetails: json['order_details'] != null
          ? OrderDetails.fromJson(json['order_details'])
          : null,
      etaStartTime: json['eta_start_time'] as String?,
      etaEndTime: json['eta_end_time'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
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
      'order_details': orderDetails?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
