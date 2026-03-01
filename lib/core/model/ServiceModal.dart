
class ServiceModal {
  final String title;
  final double rating;
  final int reviewCount;
  final String providerName;
  final String providerImageUrl;
  final String occupation;
  final double price;
  final double oldPrice;
  final String imageUrl;
  final String description;
  final Map<String, dynamic>? selectedAddress;
  final String? serviceId;
  final String? categoryId;
  final int quantity; // NEW: for cart

  ServiceModal({
    required this.title,
    required this.rating,
    required this.reviewCount,
    required this.providerName,
    required this.providerImageUrl,
    required this.occupation,
    required this.price,
    required this.oldPrice,
    required this.imageUrl,
    required this.description,
    this.selectedAddress,
    this.serviceId,
    this.categoryId,
    this.quantity = 0,
  });

  // CONVERT TO Service (for API)
  Service toService() {
    return Service(
      id: serviceId ?? '',
      name: title,
      description: description,
      price: price,
      categoryId: categoryId ?? '',
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      status: 'active',
      rating: rating,
      reviewCount: reviewCount,
      providerName: providerName,
      providerImageUrl: providerImageUrl,
      occupation: occupation,
    );
  }

  // FROM Service → ServiceModal (with optional quantity)
  factory ServiceModal.fromService(Service service, {int quantity = 0}) {
    return ServiceModal(
      title: service.name,
      rating: service.rating,
      reviewCount: service.reviewCount,
      providerName: service.providerName,
      providerImageUrl: service.providerImageUrl.isNotEmpty
          ? service.providerImageUrl
          : 'https://via.placeholder.com/50',
      occupation: _truncateDescription(
        service.occupation.isNotEmpty ? service.occupation : service.description,
      ),
      price: service.price,
      oldPrice: (service.price * 1.3).roundToDouble(),
      imageUrl: (service.imageUrl != null && service.imageUrl!.isNotEmpty)
          ? service.imageUrl!
          : 'https://via.placeholder.com/300',
      description: service.description,
      serviceId: service.id,
      categoryId: service.categoryId,
      quantity: quantity,
    );
  }
  static String _truncateDescription(String desc) {
    final words = desc.split(' ');
    return words.take(3).join(' ') + (words.length > 3 ? '...' : '');
  }

  // JSON SUPPORT
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'rating': rating,
      'reviewCount': reviewCount,
      'providerName': providerName,
      'providerImageUrl': providerImageUrl,
      'occupation': occupation,
      'price': price,
      'oldPrice': oldPrice,
      'imageUrl': imageUrl,
      'description': description,
      'selectedAddress': selectedAddress,
      'serviceId': serviceId,
      'categoryId': categoryId,
      'quantity': quantity,
    };
  }

  factory ServiceModal.fromJson(Map<String, dynamic> json) {
    return ServiceModal(
      title: json['title'] ?? json['name'] ?? '', // fallback
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? json['review_count'] ?? 0,
      providerName: json['providerName'] ?? json['provider_name'] ?? '',
      providerImageUrl: json['providerImageUrl'] ?? json['provider_image_url'] ?? '',
      occupation: json['occupation'] ?? '',
      price: (json['price'] ?? json['base_price'] ?? 0.0).toDouble(),
      oldPrice: (json['oldPrice'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      description: json['description'] ?? '',
      selectedAddress: json['selectedAddress'],
      // FIX: Read 'id' as serviceId
      serviceId: json['serviceId'] ?? json['id']?.toString(),
      categoryId: json['categoryId'] ?? json['category_id']?.toString(),
      quantity: json['quantity'] ?? 0,
    );
  }

  ServiceModal copyWith({
    String? title,
    double? rating,
    int? reviewCount,
    String? providerName,
    String? providerImageUrl,
    String? occupation,
    double? price,
    double? oldPrice,
    String? imageUrl,
    String? description,
    Map<String, dynamic>? selectedAddress,
    String? serviceId,
    String? categoryId,
    int? quantity,
  }) {
    return ServiceModal(
      title: title ?? this.title,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      providerName: providerName ?? this.providerName,
      providerImageUrl: providerImageUrl ?? this.providerImageUrl,
      occupation: occupation ?? this.occupation,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      serviceId: serviceId ?? this.serviceId,
      categoryId: categoryId ?? this.categoryId,
      quantity: quantity ?? this.quantity,
    );
  }
}

class Service {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String? imageUrl;
  final String status;
  final double rating;
  final int reviewCount;
  final String providerName;
  final String providerImageUrl;
  final String occupation;
  final String? machineVariantId;

  // New fields from updated API
  final bool isOtpRequired;
  final int eta;
  final String? parent;
  final List<ServiceCategoryMapping> categories;
  final List<PricingModel> pricingModels;
  final List<ZoneHubMapping> zoneHubMappings;
  final List<MediaFile> mediaFiles;

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    this.imageUrl,
    required this.status,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.providerName = '',
    this.providerImageUrl = '',
    this.occupation = '',
    this.machineVariantId,
    this.isOtpRequired = false,
    this.eta = 0,
    this.parent,
    this.categories = const [],
    this.pricingModels = const [],
    this.zoneHubMappings = const [],
    this.mediaFiles = const [],
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    // Parse nested arrays
    final List<ServiceCategoryMapping> categories = (json['categories'] as List<dynamic>?)
        ?.map((e) => ServiceCategoryMapping.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    final List<PricingModel> pricingModels = (json['pricing_models'] as List<dynamic>?)
        ?.map((e) => PricingModel.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    final List<ZoneHubMapping> zoneHubMappings = (json['zone_hub_mappings'] as List<dynamic>?)
        ?.map((e) => ZoneHubMapping.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    final List<MediaFile> mediaFiles = (json['media_files'] as List<dynamic>?)
        ?.map((e) => MediaFile.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    // Extract image URL: media_files → primary_image → image_url field
    String rawImageUrl = '';
    if (mediaFiles.isNotEmpty) {
      final primary = mediaFiles.where((m) => m.isPrimary).toList();
      rawImageUrl = primary.isNotEmpty ? primary.first.imageUrl : mediaFiles.first.imageUrl;
    } else if (json['primary_image'] != null) {
      final primaryImage = json['primary_image'];
      rawImageUrl = primaryImage['image_url']?.toString() ?? '';
    } else if (json['image_url'] != null) {
      rawImageUrl = json['image_url'].toString();
    }

    // Build full URL if it's a relative path
    final String fullImageUrl = rawImageUrl.isNotEmpty && !rawImageUrl.startsWith('http')
        ? 'https://api.itfixer199.com$rawImageUrl'
        : rawImageUrl;

    // Extract price: base_price → price field → first pricing_model
    double price = (json['base_price'] ?? json['price'] ?? 0.0).toDouble();
    if (price == 0.0 && pricingModels.isNotEmpty) {
      final firstPrice = double.tryParse(pricingModels.first.price);
      if (firstPrice != null) price = firstPrice;
    }

    // Extract categoryId from first category if not at top level
    String categoryId = json['category_id']?.toString() ?? '';
    if (categoryId.isEmpty && categories.isNotEmpty) {
      categoryId = categories.first.categoryId;
    }

    return Service(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Service',
      description: json['description']?.toString() ?? '',
      price: price,
      categoryId: categoryId,
      imageUrl: fullImageUrl.isNotEmpty ? fullImageUrl : null,
      status: json['status']?.toString() ?? 'active',
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: (json['review_count'] is num) ? (json['review_count'] as num).toInt() : 0,
      providerName: json['provider_name']?.toString() ?? 'IT Fixer Team',
      providerImageUrl: json['provider_image_url']?.toString() ?? '',
      occupation: json['occupation']?.toString() ?? '',
      machineVariantId: json['machine_variant_id']?.toString(),
      isOtpRequired: json['is_otp_required'] ?? false,
      eta: (json['eta'] is num) ? (json['eta'] as num).toInt() : 0,
      parent: json['parent']?.toString(),
      categories: categories,
      pricingModels: pricingModels,
      zoneHubMappings: zoneHubMappings,
      mediaFiles: mediaFiles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'image_url': imageUrl,
      'status': status,
      'rating': rating,
      'review_count': reviewCount,
      'provider_name': providerName,
      'provider_image_url': providerImageUrl,
      'occupation': occupation,
      'is_otp_required': isOtpRequired,
      'eta': eta,
      'parent': parent,
      'categories': categories.map((c) => c.toJson()).toList(),
      'pricing_models': pricingModels.map((p) => p.toJson()).toList(),
      'zone_hub_mappings': zoneHubMappings.map((z) => z.toJson()).toList(),
      'media_files': mediaFiles.map((m) => m.toJson()).toList(),
    };
  }
}

// ── Sub-models ──

class ServiceCategoryMapping {
  final String id;
  final String categoryName;
  final String service;
  final String categoryId;

  ServiceCategoryMapping({
    required this.id,
    required this.categoryName,
    required this.service,
    required this.categoryId,
  });

  factory ServiceCategoryMapping.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryMapping(
      id: json['id']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      service: json['service']?.toString() ?? '',
      categoryId: json['category']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category_name': categoryName,
    'service': service,
    'category': categoryId,
  };
}

class PricingModel {
  final String id;
  final String pricingTypeName;
  final String hubName;
  final String price;
  final String service;
  final String pricingType;
  final String hub;

  PricingModel({
    required this.id,
    required this.pricingTypeName,
    required this.hubName,
    required this.price,
    required this.service,
    required this.pricingType,
    required this.hub,
  });

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    return PricingModel(
      id: json['id']?.toString() ?? '',
      pricingTypeName: json['pricing_type_name']?.toString() ?? '',
      hubName: json['hub_name']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      service: json['service']?.toString() ?? '',
      pricingType: json['pricing_type']?.toString() ?? '',
      hub: json['hub']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pricing_type_name': pricingTypeName,
    'hub_name': hubName,
    'price': price,
    'service': service,
    'pricing_type': pricingType,
    'hub': hub,
  };
}

class ZoneHubMapping {
  final String id;
  final String zoneName;
  final String hubName;
  final String service;
  final String zone;
  final String hub;

  ZoneHubMapping({
    required this.id,
    required this.zoneName,
    required this.hubName,
    required this.service,
    required this.zone,
    required this.hub,
  });

  factory ZoneHubMapping.fromJson(Map<String, dynamic> json) {
    return ZoneHubMapping(
      id: json['id']?.toString() ?? '',
      zoneName: json['zone_name']?.toString() ?? '',
      hubName: json['hub_name']?.toString() ?? '',
      service: json['service']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      hub: json['hub']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'zone_name': zoneName,
    'hub_name': hubName,
    'service': service,
    'zone': zone,
    'hub': hub,
  };
}

class MediaFile {
  final String id;
  final String imageUrl;
  final String title;
  final String? tag;
  final String? altText;
  final String referenceId;
  final String referenceType;
  final bool isPrimary;
  final String status;
  final String? imagePath;
  final String? imageType;

  MediaFile({
    required this.id,
    required this.imageUrl,
    required this.title,
    this.tag,
    this.altText,
    required this.referenceId,
    required this.referenceType,
    this.isPrimary = false,
    this.status = 'ACTIVE',
    this.imagePath,
    this.imageType,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    String rawUrl = json['image_url']?.toString() ?? '';
    final String fullUrl = rawUrl.isNotEmpty && !rawUrl.startsWith('http')
        ? 'https://api.itfixer199.com$rawUrl'
        : rawUrl;

    return MediaFile(
      id: json['id']?.toString() ?? '',
      imageUrl: fullUrl,
      title: json['title']?.toString() ?? '',
      tag: json['tag']?.toString(),
      altText: json['alt_text']?.toString(),
      referenceId: json['reference_id']?.toString() ?? '',
      referenceType: json['reference_type']?.toString() ?? '',
      isPrimary: json['is_primary'] ?? false,
      status: json['status']?.toString() ?? 'ACTIVE',
      imagePath: json['image_path']?.toString(),
      imageType: json['image_type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
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
