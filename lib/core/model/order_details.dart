import 'service_modification.dart';
import 'order_item_modification.dart';

List<dynamic>? _safeList(dynamic value) {
  if (value == null) return null;
  if (value is List) return value;
  if (value is Map) {
    if (value.containsKey('results') && value['results'] is List) {
      return value['results'] as List;
    } else if (value.containsKey('data') && value['data'] is List) {
      return value['data'] as List;
    } else if (value.containsKey('items') && value['items'] is List) {
      return value['items'] as List;
    }
    return [];
  }
  return [];
}

class OrderDetails {
  final String? id;
  final List<OrderItem>? items;
  final List<dynamic>? agentHistory;
  final UserDetails? userDetails;
  final AgentDetails? agentDetails;
  final ZoneDetail? zoneDetails;
  final String? createdAt;
  final bool? isOtpRequired;
  final bool? isOtpVerified;
  final String? userId;
  final String? orderStatus;
  final String? agentApproval;
  final String? paymentStatus;
  final String? totalPrice;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? googleAddress;
  final String? customerName;
  final String? customerNumber;
  final String? customerEmail;
  final String? slotId;
  final dynamic slotTime;
  final String? assignedAgentId;
  final dynamic startingAgentCoordinates;
  final String? zoneId;
  final List<ServiceModification>? serviceModifications;
  final List<OrderItemModification>? orderItemModifications;
  final bool? isActive;
  final bool? isInstantSlot;



  OrderDetails({
    this.id,
    this.items,
    this.agentHistory,
    this.userDetails,
    this.agentDetails,
    this.zoneDetails,
    this.createdAt,
    this.isOtpRequired,
    this.isOtpVerified,
    this.userId,
    this.orderStatus,
    this.agentApproval,
    this.paymentStatus,
    this.totalPrice,
    this.latitude,
    this.longitude,
    this.address,
    this.googleAddress,
    this.customerName,
    this.customerNumber,
    this.slotId,
    this.slotTime,
    this.assignedAgentId,
    this.startingAgentCoordinates,
    this.zoneId,
    this.serviceModifications,
    this.orderItemModifications,
    this.isActive,
    this.isInstantSlot, this.customerEmail,
  });

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    return OrderDetails(
      id: json['id'],
      customerEmail: json[''],
      items: _safeList(json['items'])
          ?.map((i) => OrderItem.fromJson(i))
          .toList(),
      agentHistory: _safeList(json['agent_history']),
      userDetails: json['user_details'] != null
          ? UserDetails.fromJson(json['user_details'])
          : null,
      agentDetails: json['agent_details'] != null
          ? AgentDetails.fromJson(json['agent_details'])
          : null,
      zoneDetails: json['zone_details'] != null
          ? ZoneDetail.fromJson(json['zone_details'])
          : null,
      createdAt: json['created_at'],
      isOtpRequired: json['is_otp_required'],
      isOtpVerified: json['is_otp_verified'],
      userId: json['user_id'],
      orderStatus: json['order_status'],
      agentApproval: json['agent_approval'],
      paymentStatus: json['payment_status'],
      totalPrice: json['total_price'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'],
      googleAddress: json['google_address'],
      customerName: json['customer_name'],
      customerNumber: json['customer_number'],
      slotId: json['slot_id'],
      slotTime: json['slot_time'],
      assignedAgentId: json['assigned_agent_id'],
      startingAgentCoordinates: json['starting_agent_coordinates'],
      zoneId: json['zone_id'],
      serviceModifications: _safeList(json['service_modifications'])
          ?.map((m) => ServiceModification.fromJson(m as Map<String, dynamic>))
          .toList(),
      orderItemModifications: _safeList(json['order_item_modifications'])
          ?.map((m) => OrderItemModification.fromJson(m as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'],
      isInstantSlot: json['is_instant_slot'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items?.map((i) => i.toJson()).toList(),
      'agent_history': agentHistory,
      'user_details': userDetails?.toJson(),
      'agent_details': agentDetails?.toJson(),
      'zone_details': zoneDetails?.toJson(),
      'created_at': createdAt,
      'is_otp_required': isOtpRequired,
      'is_otp_verified': isOtpVerified,
      'user_id': userId,
      'order_status': orderStatus,
      'agent_approval': agentApproval,
      'payment_status': paymentStatus,
      'total_price': totalPrice,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'google_address': googleAddress,
      'customer_name': customerName,
      'customer_number': customerNumber,
      'slot_id': slotId,
      'slot_time': slotTime,
      'assigned_agent_id': assignedAgentId,
      'starting_agent_coordinates': startingAgentCoordinates,
      'zone_id': zoneId,
      'service_modifications': serviceModifications?.map((m) => m.toJson()).toList(),
      'order_item_modifications': orderItemModifications?.map((m) => m.toJson()).toList(),
      'is_active': isActive,
      'is_instant_slot': isInstantSlot,
    };
  }

  @override
  String toString() {
    return 'OrderDetails{id: $id, items: $items, agentHistory: $agentHistory, userDetails: $userDetails, agentDetails: $agentDetails, zoneDetails: $zoneDetails, createdAt: $createdAt, isOtpRequired: $isOtpRequired, isOtpVerified: $isOtpVerified, userId: $userId, orderStatus: $orderStatus, agentApproval: $agentApproval, paymentStatus: $paymentStatus, totalPrice: $totalPrice, latitude: $latitude, longitude: $longitude, address: $address, googleAddress: $googleAddress, customerName: $customerName, customerNumber: $customerNumber, slotId: $slotId, slotTime: $slotTime, assignedAgentId: $assignedAgentId, startingAgentCoordinates: $startingAgentCoordinates, zoneId: $zoneId, serviceModifications: $serviceModifications, isActive: $isActive, isInstantSlot: $isInstantSlot}';
  }

}

class OrderItem {
  final String? id;
  final List<ItemMedia>? media;
  final ItemDetails? itemDetails;
  final dynamic attributes;
  final String? createdAt;
  final String? type;
  final String? productId;
  final String? serviceId;
  final dynamic orderProductSuggestionId;
  final dynamic serviceModificationId;
  final int? quantity;
  final String? price;
  final String? agentId;
  final String? serialNumber;
  final String? status;
  final String? customerConfirmation;
  final String? comment;
  final String? deviceId;
  final String? brand;
  final String? issueDescriptionText;
  final String? order;

  OrderItem({
    this.id,
    this.media,
    this.itemDetails,
    this.attributes,
    this.createdAt,
    this.type,
    this.productId,
    this.serviceId,
    this.orderProductSuggestionId,
    this.serviceModificationId,
    this.quantity,
    this.price,
    this.agentId,
    this.serialNumber,
    this.status,
    this.customerConfirmation,
    this.comment,
    this.deviceId,
    this.brand,
    this.issueDescriptionText,
    this.order,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      media: _safeList(json['media'])
          ?.map((m) => ItemMedia.fromJson(m))
          .toList(),
      itemDetails: json['item_details'] != null
          ? ItemDetails.fromJson(json['item_details'])
          : null,
      attributes: json['attributes'],
      createdAt: json['created_at'],
      type: json['type'],
      productId: json['product_id'],
      serviceId: json['service_id'],
      orderProductSuggestionId: json['order_product_suggestion_id'],
      serviceModificationId: json['service_modification_id'],
      quantity: (json['quantity'] as num?)?.toInt(),
      price: json['price'],
      agentId: json['agent_id'],
      serialNumber: json['serial_number'],
      status: json['status'],
      customerConfirmation: json['customer_confirmation'],
      comment: json['comment'],
      deviceId: json['device_id'],
      brand: json['brand'],
      issueDescriptionText: json['issue_description_text'],
      order: json['order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media': media?.map((m) => m.toJson()).toList(),
      'item_details': itemDetails?.toJson(),
      'attributes': attributes,
      'created_at': createdAt,
      'type': type,
      'product_id': productId,
      'service_id': serviceId,
      'order_product_suggestion_id': orderProductSuggestionId,
      'service_modification_id': serviceModificationId,
      'quantity': quantity,
      'price': price,
      'agent_id': agentId,
      'serial_number': serialNumber,
      'status': status,
      'customer_confirmation': customerConfirmation,
      'comment': comment,
      'device_id': deviceId,
      'brand': brand,
      'issue_description_text': issueDescriptionText,
      'order': order,
    };
  }

  @override
  String toString() {
    return 'OrderItem{id: $id, media: $media, itemDetails: $itemDetails, attributes: $attributes, createdAt: $createdAt, type: $type, productId: $productId, serviceId: $serviceId, orderProductSuggestionId: $orderProductSuggestionId, serviceModificationId: $serviceModificationId, quantity: $quantity, price: $price, agentId: $agentId, serialNumber: $serialNumber, status: $status, customerConfirmation: $customerConfirmation, comment: $comment, deviceId: $deviceId, brand: $brand, issueDescriptionText: $issueDescriptionText, order: $order}';
  }

}

class ItemMedia {
  final String? id;
  final String? url;
  final String? mediaType;

  ItemMedia({this.id, this.url, this.mediaType});

  factory ItemMedia.fromJson(Map<String, dynamic> json) {
    return ItemMedia(
      id: json['id'],
      url: json['url'],
      mediaType: json['media_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'media_type': mediaType,
    };
  }
}

class ItemDetails {
  final String? name;
  final String? id;
  final FullDetails? fullDetails;

  ItemDetails({this.name, this.id, this.fullDetails});

  factory ItemDetails.fromJson(Map<String, dynamic> json) {
    return ItemDetails(
      name: json['name'],
      id: json['id'],
      fullDetails: json['full_details'] != null
          ? FullDetails.fromJson(json['full_details'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'full_details': fullDetails?.toJson(),
    };
  }
}

class FullDetails {
  final String? id;
  final String? name;
  final String? description;
  final bool? isOtpRequired;
  final int? eta;
  final String? status;
  final BrandDetails? brandDetails;
  final List<Category>? categories;
  final List<PricingModel>? pricingModels;
  final List<ZoneHubMapping>? zoneHubMappings;
  final List<MediaFile>? mediaFiles;
  final List<Pricing>? pricing;
  final String? modelName;
  final String? sku;
  final List<dynamic>? specification;
  final List<dynamic>? attributes;
  final List<dynamic>? media;
  final dynamic inventory;
  final List<dynamic>? children;
  final dynamic parent;
  final String? parentName;
  final String? createdAt;
  final String? updatedAt;

  FullDetails({
    this.id,
    this.name,
    this.description,
    this.isOtpRequired,
    this.eta,
    this.status,
    this.brandDetails,
    this.categories,
    this.pricingModels,
    this.zoneHubMappings,
    this.mediaFiles,
    this.pricing,
    this.modelName,
    this.sku,
    this.specification,
    this.attributes,
    this.media,
    this.inventory,
    this.children,
    this.createdAt,
    this.updatedAt, this.parent, this.parentName,
  });

  factory FullDetails.fromJson(Map<String, dynamic> json) {
    return FullDetails(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      isOtpRequired: json['is_otp_required'],
      eta: (json['eta'] as num?)?.toInt(),
      status: json['status'],
      brandDetails: json['brand_details'] != null
          ? BrandDetails.fromJson(json['brand_details'])
          : null,
      categories: _safeList(json['categories'])?.map((c) {
              if (c is Map<String, dynamic> && c.containsKey('category_name')) {
                return Category.fromJson(c);
              } else if (c is Map<String, dynamic> && c.containsKey('name')) {
                return Category(id: c['id'], categoryName: c['name']);
              }
              return Category();
            }).toList(),
      pricingModels: _safeList(json['pricing_models'])
              ?.map((p) => PricingModel.fromJson(p))
              .toList(),
      zoneHubMappings: _safeList(json['zone_hub_mappings'])
              ?.map((z) => ZoneHubMapping.fromJson(z))
              .toList(),
      mediaFiles: _safeList(json['media_files'])
              ?.map((m) => MediaFile.fromJson(m))
              .toList(),
      pricing: _safeList(json['pricing'])?.map((p) => Pricing.fromJson(p)).toList(),
      modelName: json['model_name'],
      sku: json['sku'],
      specification: _safeList(json['specification']),
      attributes: _safeList(json['attributes']),
      media: _safeList(json['media']),
      inventory: json['inventory'],
      children: _safeList(json['children']),
      parent: json['parent'],
      parentName: json['parent_name'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_otp_required': isOtpRequired,
      'eta': eta,
      'status': status,
      'brand_details': brandDetails?.toJson(),
      'categories': categories?.map((c) => c.toJson()).toList(),
      'pricing_models': pricingModels?.map((p) => p.toJson()).toList(),
      'zone_hub_mappings': zoneHubMappings?.map((z) => z.toJson()).toList(),
      'media_files': mediaFiles?.map((m) => m.toJson()).toList(),
      'pricing': pricing?.map((p) => p.toJson()).toList(),
      'model_name': modelName,
      'sku': sku,
      'specification': specification,
      'attributes': attributes,
      'media': media,
      'inventory': inventory,
      'children': children,
      'parent': parent,
      'parent_name': parentName,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class Category {
  final String? id;
  final String? categoryName;
  final String? service;
  final String? category;

  Category({this.id, this.categoryName, this.service, this.category});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      categoryName: json['category_name'],
      service: json['service'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': categoryName,
      'service': service,
      'category': category,
    };
  }
}

class PricingModel {
  final String? id;
  final String? pricingTypeName;
  final String? price;
  final String? service;
  final String? pricingType;
  final dynamic hub;

  PricingModel({
    this.id,
    this.pricingTypeName,
    this.price,
    this.service,
    this.pricingType,
    this.hub,
  });

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    return PricingModel(
      id: json['id'],
      pricingTypeName: json['pricing_type_name'],
      price: json['price'],
      service: json['service'],
      pricingType: json['pricing_type'],
      hub: json['hub'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pricing_type_name': pricingTypeName,
      'price': price,
      'service': service,
      'pricing_type': pricingType,
      'hub': hub,
    };
  }
}

class ZoneHubMapping {
  final String? id;
  final String? zoneName;
  final String? hubName;
  final String? service;
  final String? zone;
  final String? hub;

  ZoneHubMapping({
    this.id,
    this.zoneName,
    this.hubName,
    this.service,
    this.zone,
    this.hub,
  });

  factory ZoneHubMapping.fromJson(Map<String, dynamic> json) {
    return ZoneHubMapping(
      id: json['id'],
      zoneName: json['zone_name'],
      hubName: json['hub_name'],
      service: json['service'],
      zone: json['zone'],
      hub: json['hub'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'zone_name': zoneName,
      'hub_name': hubName,
      'service': service,
      'zone': zone,
      'hub': hub,
    };
  }
}

class MediaFile {
  final String? id;
  final String? imageUrl;
  final String? title;
  final dynamic tag;
  final dynamic altText;
  final String? referenceId;
  final String? referenceType;
  final bool? isPrimary;
  final String? status;
  final String? imagePath;
  final String? imageType;

  MediaFile({
    this.id,
    this.imageUrl,
    this.title,
    this.tag,
    this.altText,
    this.referenceId,
    this.referenceType,
    this.isPrimary,
    this.status,
    this.imagePath,
    this.imageType,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      id: json['id'],
      imageUrl: json['image_url'],
      title: json['title'],
      tag: json['tag'],
      altText: json['alt_text'],
      referenceId: json['reference_id'],
      referenceType: json['reference_type'],
      isPrimary: json['is_primary'],
      status: json['status'],
      imagePath: json['image_path'],
      imageType: json['image_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'title': title,
      'tag': tag,
      'alt_text': altText,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'is_primary': isPrimary,
      'status': status,
      'image_path': imagePath,
      'image_type': imageType,
    };
  }
}

class UserDetails {
  final String? id;
  final String? name;
  final String? email;
  final String? mobileNumber;
  final String? role;
  final bool? isMobileVerified;
  final bool? isEmailVerified;
  final String? status;
  final String? comments;
  final bool? isStaff;
  final bool? isActive;
  final bool? isSuperuser;
  final String? dateJoined;
  final dynamic createdBy;
  final dynamic hubId;
  final dynamic hub;

  UserDetails({
    this.id,
    this.name,
    this.email,
    this.mobileNumber,
    this.role,
    this.isMobileVerified,
    this.isEmailVerified,
    this.status,
    this.comments,
    this.isStaff,
    this.isActive,
    this.isSuperuser,
    this.dateJoined,
    this.createdBy,
    this.hub,
    this.hubId,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      mobileNumber: json['mobile_number'],
      role: json['role'],
      isMobileVerified: json['is_mobile_verified'],
      isEmailVerified: json['is_email_verified'],
      status: json['status'],
      comments: json['comments'],
      isStaff: json['is_staff'],
      isActive: json['is_active'],
      isSuperuser: json['is_superuser'],
      dateJoined: json['date_joined'],
      createdBy: json['created_by'],
      hubId: json['hub_id'],
      hub: json['hub'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile_number': mobileNumber,
      'role': role,
      'is_mobile_verified': isMobileVerified,
      'is_email_verified': isEmailVerified,
      'status': status,
      'comments': comments,
      'is_staff': isStaff,
      'is_active': isActive,
      'is_superuser': isSuperuser,
      'date_joined': dateJoined,
      'created_by': createdBy,
      'hub': hub,
      'hub_id': hubId,
    };
  }
}

class AgentDetails {
  final String? id;
  final String? user;
  final String? userName;
  final AgentUserDetails? userDetails;
  final dynamic aadharDocUrlModelId;
  final dynamic aadharDocUrl;
  final dynamic panCardUrlModelId;
  final dynamic panCardUrl;
  final dynamic videoKycUrlModelId;
  final dynamic videoKycUrl;
  final String? isPanVerified;
  final String? isAadharVerified;
  final String? cumulativeRating;
  final dynamic profileImageUrlModelId;
  final dynamic profileImageUrl;
  final String? startTime;
  final String? endTime;
  final String? agentType;
  final bool? isAdminPermissionRequired;
  final dynamic hubId;
  final dynamic hub;
  final dynamic hubName;
  final dynamic bankName;
  final dynamic accountNumber;
  final dynamic ifscCode;
  final dynamic upiId;
  final List<ZoneDetail>? zoneDetails;
  final dynamic managerDetails;
  final String? createdAt;
  final dynamic createdBy;
  final String? updatedAt;

  AgentDetails({
    this.id,
    this.user,
    this.userName,
    this.userDetails,
    this.aadharDocUrlModelId,
    this.aadharDocUrl,
    this.panCardUrlModelId,
    this.panCardUrl,
    this.videoKycUrlModelId,
    this.videoKycUrl,
    this.isPanVerified,
    this.isAadharVerified,
    this.cumulativeRating,
    this.profileImageUrlModelId,
    this.profileImageUrl,
    this.startTime,
    this.endTime,
    this.agentType,
    this.isAdminPermissionRequired,
    this.hubId,
    this.hub,
    this.hubName,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.zoneDetails,
    this.managerDetails,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  factory AgentDetails.fromJson(Map<String, dynamic> json) {
    return AgentDetails(
      id: json['id'],
      user: json['user'],
      userName: json['user_name'],
      userDetails: json['user_details'] != null
          ? AgentUserDetails.fromJson(json['user_details'])
          : null,
      aadharDocUrlModelId: json['aadhar_doc_url_model_id'],
      aadharDocUrl: json['aadhar_doc_url'],
      panCardUrlModelId: json['pan_card_url_model_id'],
      panCardUrl: json['pan_card_url'],
      videoKycUrlModelId: json['video_kyc_url_model_id'],
      videoKycUrl: json['video_kyc_url'],
      isPanVerified: json['is_pan_verified'],
      isAadharVerified: json['is_aadhar_verified'],
      cumulativeRating: json['cumulative_rating'],
      profileImageUrlModelId: json['profile_image_url_model_id'],
      profileImageUrl: json['profile_image_url'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      agentType: json['agent_type'],
      isAdminPermissionRequired: json['is_admin_permission_required'],
      hubId: json['hub_id'],
      hub: json['hub'],
      hubName: json['hub_name'],
      bankName: json['bank_name'],
      accountNumber: json['account_number'],
      ifscCode: json['ifsc_code'],
      upiId: json['upi_id'],
      zoneDetails: _safeList(json['zone_details'])
              ?.map((z) => ZoneDetail.fromJson(z))
              .toList(),
      managerDetails: json['manager_details'],
      createdAt: json['created_at'],
      createdBy: json['created_by'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'user_name': userName,
      'user_details': userDetails?.toJson(),
      'aadhar_doc_url_model_id': aadharDocUrlModelId,
      'aadhar_doc_url': aadharDocUrl,
      'pan_card_url_model_id': panCardUrlModelId,
      'pan_card_url': panCardUrl,
      'video_kyc_url_model_id': videoKycUrlModelId,
      'video_kyc_url': videoKycUrl,
      'is_pan_verified': isPanVerified,
      'is_aadhar_verified': isAadharVerified,
      'cumulative_rating': cumulativeRating,
      'profile_image_url_model_id': profileImageUrlModelId,
      'profile_image_url': profileImageUrl,
      'start_time': startTime,
      'end_time': endTime,
      'agent_type': agentType,
      'is_admin_permission_required': isAdminPermissionRequired,
      'hub_id': hubId,
      'hub': hub,
      'hub_name': hubName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'upi_id': upiId,
      'zone_details': zoneDetails?.map((z) => z.toJson()).toList(),
      'manager_details': managerDetails,
      'created_at': createdAt,
      'created_by': createdBy,
      'updated_at': updatedAt,
    };
  }
}

class AgentUserDetails {
  final String? id;
  final String? agentId;
  final String? name;
  final String? email;
  final String? mobileNumber;
  final String? role;
  final bool? isMobileVerified;
  final bool? isEmailVerified;
  final String? status;
  final String? comments;
  final bool? isStaff;
  final bool? isActive;
  final bool? isSuperuser;
  final String? dateJoined;
  final dynamic createdBy;
  final dynamic hub;

  AgentUserDetails({
    this.id,
    this.agentId,
    this.name,
    this.email,
    this.mobileNumber,
    this.role,
    this.isMobileVerified,
    this.isEmailVerified,
    this.status,
    this.comments,
    this.isStaff,
    this.isActive,
    this.isSuperuser,
    this.dateJoined,
    this.createdBy,
    this.hub,
  });

  factory AgentUserDetails.fromJson(Map<String, dynamic> json) {
    return AgentUserDetails(
      id: json['id'],
      agentId: json['agent_id'],
      name: json['name'],
      email: json['email'],
      mobileNumber: json['mobile_number'],
      role: json['role'],
      isMobileVerified: json['is_mobile_verified'],
      isEmailVerified: json['is_email_verified'],
      status: json['status'],
      comments: json['comments'],
      isStaff: json['is_staff'],
      isActive: json['is_active'],
      isSuperuser: json['is_superuser'],
      dateJoined: json['date_joined'],
      createdBy: json['created_by'],
      hub: json['hub'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agent_id': agentId,
      'name': name,
      'email': email,
      'mobile_number': mobileNumber,
      'role': role,
      'is_mobile_verified': isMobileVerified,
      'is_email_verified': isEmailVerified,
      'status': status,
      'comments': comments,
      'is_staff': isStaff,
      'is_active': isActive,
      'is_superuser': isSuperuser,
      'date_joined': dateJoined,
      'created_by': createdBy,
      'hub': hub,
    };
  }
}

class ZoneDetail {
  final String? id;
  final String? name;
  final String? status;
  final String? description;
  final bool? deleteStatus;
  final List<Coordinate>? coordinates;

  ZoneDetail({
    this.id,
    this.name,
    this.status,
    this.description,
    this.deleteStatus,
    this.coordinates,
  });

  factory ZoneDetail.fromJson(Map<String, dynamic> json) {
    return ZoneDetail(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      description: json['description'],
      deleteStatus: json['delete_status'],
      coordinates: _safeList(json['coordinates'])
              ?.map((c) => Coordinate.fromJson(c))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'description': description,
      'delete_status': deleteStatus,
      'coordinates': coordinates?.map((c) => c.toJson()).toList(),
    };
  }
}

class Coordinate {
  final double? lat;
  final double? lng;

  Coordinate({this.lat, this.lng});

  factory Coordinate.fromJson(Map<String, dynamic> json) {
    return Coordinate(
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}

class BrandDetails {
  final String? id;
  final String? name;
  final String? status;
  final bool? isFeatured;
  final String? type;
  final String? logoUrl;
  final bool? deleteStatus;
  final dynamic logoMediaId;

  BrandDetails({
    this.id,
    this.name,
    this.status,
    this.isFeatured,
    this.type,
    this.logoUrl,
    this.deleteStatus,
    this.logoMediaId,
  });

  factory BrandDetails.fromJson(Map<String, dynamic> json) {
    return BrandDetails(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      isFeatured: json['is_featured'],
      type: json['type'],
      logoUrl: json['logo_url'],
      deleteStatus: json['delete_status'],
      logoMediaId: json['logo_media_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'is_featured': isFeatured,
      'type': type,
      'logo_url': logoUrl,
      'delete_status': deleteStatus,
      'logo_media_id': logoMediaId,
    };
  }
}

class Pricing {
  final String? id;
  final String? pricingType;
  final String? pricingTypeName;
  final String? hub;
  final String? hubName;
  final String? startTime;
  final String? endTime;
  final int? maxQuantity;
  final String? price;
  final String? createdAt;
  final String? updatedAt;

  Pricing({
    this.id,
    this.pricingType,
    this.pricingTypeName,
    this.hub,
    this.hubName,
    this.startTime,
    this.endTime,
    this.maxQuantity,
    this.price,
    this.createdAt,
    this.updatedAt,
  });

  factory Pricing.fromJson(Map<String, dynamic> json) {
    return Pricing(
      id: json['id'],
      pricingType: json['pricing_type'],
      pricingTypeName: json['pricing_type_name'],
      hub: json['hub'],
      hubName: json['hub_name'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      maxQuantity: (json['max_quantity'] as num?)?.toInt(),
      price: json['price'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pricing_type': pricingType,
      'pricing_type_name': pricingTypeName,
      'hub': hub,
      'hub_name': hubName,
      'start_time': startTime,
      'end_time': endTime,
      'max_quantity': maxQuantity,
      'price': price,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
