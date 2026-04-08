class MyPossessionResponse {
  final bool success;
  final List<Possession> myPossession;
  final Pagination pagination;

  MyPossessionResponse({
    required this.success,
    required this.myPossession,
    required this.pagination,
  });

  factory MyPossessionResponse.fromJson(Map<String, dynamic> json) {
    return MyPossessionResponse(
      success: json['success'] ?? false,
      myPossession: (json['my_possession'] is List)
          ? (json['my_possession'] as List)
          .map((e) => Possession.fromJson(e as Map<String, dynamic>))
          .toList()
          : [],
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'my_possession': myPossession.map((e) => e.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }
}

class Possession {
  final PossessionProductDetails productDetails;
  final AgentDetails agentDetails;
  final HubDetails hubDetails;
  final int availableStock;
  final List<String> availableSerialNumbers;

  Possession({
    required this.productDetails,
    required this.agentDetails,
    required this.hubDetails,
    required this.availableStock,
    required this.availableSerialNumbers,
  });

  factory Possession.fromJson(Map<String, dynamic> json) {
    return Possession(
      productDetails: PossessionProductDetails.fromJson(
          json['product_details'] ?? {}),
      agentDetails: AgentDetails.fromJson(json['agent_details'] ?? {}),
      hubDetails: HubDetails.fromJson(json['hub_details'] ?? {}),
      availableStock: json['available_stock'] ?? 0,
      availableSerialNumbers: (json['available_serial_numbers'] is List)
          ? List<String>.from(json['available_serial_numbers'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_details': productDetails.toJson(),
      'agent_details': agentDetails.toJson(),
      'hub_details': hubDetails.toJson(),
      'available_stock': availableStock,
      'available_serial_numbers': availableSerialNumbers,
    };
  }
}

class PossessionProductDetails {
  final String id;
  final String name;
  final String description;
  final String brand;
  final String modelName;
  final String type;
  final String? parent;
  final String? parentName;
  final bool isOtpRequired;
  final String sku;
  final String? barcode;
  final String? hsn;
  final List<Map<String, dynamic>> specification;
  final String status;
  final List<Map<String, dynamic>> media;
  final String createdAt;
  final String createdBy;
  final String updatedAt;

  PossessionProductDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.brand,
    required this.modelName,
    required this.type,
    this.parent,
    this.parentName,
    required this.isOtpRequired,
    required this.sku,
    this.barcode,
    this.hsn,
    required this.specification,
    required this.status,
    required this.media,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
  });

  factory PossessionProductDetails.fromJson(Map<String, dynamic> json) {
    return PossessionProductDetails(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      brand: json['brand'] ?? '',
      modelName: json['model_name'] ?? '',
      type: json['type'] ?? '',
      parent: json['parent'],
      parentName: json['parent_name'],
      isOtpRequired: json['is_otp_required'] ?? false,
      sku: json['sku'] ?? '',
      barcode: json['barcode'],
      hsn: json['hsn'],
      specification: (json['specification'] is List)
          ? (json['specification'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList()
          : [],
      status: json['status'] ?? '',
      media: (json['media'] is List)
          ? (json['media'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList()
          : [],
      createdAt: json['created_at'] ?? '',
      createdBy: json['created_by'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'brand': brand,
      'model_name': modelName,
      'type': type,
      'parent': parent,
      'parent_name': parentName,
      'is_otp_required': isOtpRequired,
      'sku': sku,
      'barcode': barcode,
      'hsn': hsn,
      'specification': specification,
      'status': status,
      'media': media,
      'created_at': createdAt,
      'created_by': createdBy,
      'updated_at': updatedAt,
    };
  }
}

class AgentDetails {
  final String id;
  final String name;

  AgentDetails({required this.id, required this.name});

  factory AgentDetails.fromJson(Map<String, dynamic> json) {
    return AgentDetails(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class HubDetails {
  final String id;
  final String name;

  HubDetails({required this.id, required this.name});

  factory HubDetails.fromJson(Map<String, dynamic> json) {
    return HubDetails(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class Pagination {
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final int? previousPages;
  final String? next;

  Pagination({
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    this.previousPages,
    this.next,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      size: json['size'] ?? 10,
      totalElements: json['total_elements'] ?? 0,
      totalPages: json['total_pages'] ?? 1,
      previousPages: json['previous_pages'],
      next: json['next'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'size': size,
      'total_elements': totalElements,
      'total_pages': totalPages,
      'previous_pages': previousPages,
      'next': next,
    };
  }
}