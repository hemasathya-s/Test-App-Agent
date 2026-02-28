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
    return SlotAvailability(
      id: json['id'] as String?,
      agent: json['agent'] as String?,
      agentUserName: json['agent_user_name'] as String?,
      slot: json['slot'] as String?,
      slotName: json['slot_name'] as String?,
      zone: json['zone'] as String?,
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
      'order_details':orderDetails,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
