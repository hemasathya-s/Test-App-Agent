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
    String? getStringId(dynamic value) {
      if (value is String) return value;
      if (value is Map) return value['id']?.toString();
      return value?.toString();
    }

    String? getName(dynamic value) {
      if (value is Map) return value['name']?.toString() ?? value['zone_name']?.toString();
      return null;
    }

    return SlotAvailability(
      id: json['id']?.toString(),
      agent: getStringId(json['agent']),
      agentUserName: json['agent_user_name']?.toString(),
      slot: getStringId(json['slot']) ?? json['id']?.toString(),
      slotName: json['slot_name']?.toString() ?? getName(json['slot']) ?? json['slot']?.toString(),
      zone: getStringId(json['zone']),
      zoneName: json['zone_name']?.toString() ?? getName(json['zone']) ?? json['zone']?.toString(),
      orderId: json['order_id']?.toString(),
      date: json['date']?.toString(),
      orderDetails: json['order_details'] != null
          ? OrderDetails.fromJson(json['order_details'])
          : null,
      etaStartTime: json['eta_start_time']?.toString() ?? 
                    json['start_time']?.toString() ??
                    (json['slot'] is Map ? json['slot']['start_time']?.toString() : null),
      etaEndTime: json['eta_end_time']?.toString() ?? 
                  json['end_time']?.toString() ??
                  (json['slot'] is Map ? json['slot']['end_time']?.toString() : null),
      status: json['status']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
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
