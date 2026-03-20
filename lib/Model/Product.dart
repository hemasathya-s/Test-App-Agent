// PRODUCT MODEL
class ProductMedia {
  final String id;
  final String title;
  final String url;
  final String mediaType;

  ProductMedia({
    required this.id,
    required this.title,
    required this.url,
    required this.mediaType,
  });

  factory ProductMedia.fromJson(Map<String, dynamic> json) {
    return ProductMedia(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      mediaType: json['media_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'media_type': mediaType,
    };
  }
}

class ProductCategory {
  final String id;
  final String name;

  ProductCategory({
    required this.id,
    required this.name,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id']?.toString() ?? '',
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

class ProductSpecification {
  final String value;

  ProductSpecification({
    required this.value,
  });

  factory ProductSpecification.fromJson(Map<String, dynamic> json) {
    return ProductSpecification(
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
    };
  }
}

class ProductAttribute {
  final String attributeId;
  final String attributeName;
  final String valueId;
  final String value;

  ProductAttribute({
    required this.attributeId,
    required this.attributeName,
    required this.valueId,
    required this.value,
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      attributeId: json['attribute_id']?.toString() ?? '',
      attributeName: json['attribute_name'] ?? '',
      valueId: json['value_id']?.toString() ?? '',
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attribute_id': attributeId,
      'attribute_name': attributeName,
      'value_id': valueId,
      'value': value,
    };
  }
}

class ProductPricing {
  final String id;
  final String pricingType;
  final String pricingTypeName;
  final String? hub;
  final String? hubName;
  final String price;

  ProductPricing({
    required this.id,
    required this.pricingType,
    required this.pricingTypeName,
    this.hub,
    this.hubName,
    required this.price,
  });

  factory ProductPricing.fromJson(Map<String, dynamic> json) {
    return ProductPricing(
      id: json['id']?.toString() ?? '',
      pricingType: json['pricing_type']?.toString() ?? '',
      pricingTypeName: json['pricing_type_name'] ?? '',
      hub: json['hub'],
      hubName: json['hub_name'],
      price: json['price']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pricing_type': pricingType,
      'pricing_type_name': pricingTypeName,
      'hub': hub,
      'hub_name': hubName,
      'price': price,
    };
  }
}

class BrandDetails {
  final String id;
  final String logoUrl;
  final String name;
  final String status;
  final bool isFeatured;

  BrandDetails({
    required this.id,
    required this.logoUrl,
    required this.name,
    required this.status,
    required this.isFeatured,
  });

  factory BrandDetails.fromJson(Map<String, dynamic> json) {
    return BrandDetails(
      id: json['id']?.toString() ?? '',
      logoUrl: json['logo_url'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      isFeatured: json['is_featured'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'logo_url': logoUrl,
      'name': name,
      'status': status,
      'is_featured': isFeatured,
    };
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final String brand;
  final String? brandName;
  final BrandDetails? brandDetails;
  final String modelName;
  final String type;
  final String? parent;
  final bool isOptRequired;
  final String sku;
  final ProductSpecification? specification;
  final String status;
  final List<ProductCategory> categories;
  final List<ProductPricing> pricing;
  final List<ProductAttribute> attributes;
  final List<ProductMedia> media;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.brand,
    this.brandName,
    this.brandDetails,
    required this.modelName,
    required this.type,
    this.parent,
    required this.isOptRequired,
    required this.sku,
    this.specification,
    required this.status,
    required this.categories,
    required this.pricing,
    required this.attributes,
    required this.media,
  });

  // Getter for primary image URL (backward compatibility)
  String get imageUrl {
    if (media.isNotEmpty) {
      final firstImage = media.firstWhere(
            (m) => m.mediaType.toLowerCase() == 'image',
        orElse: () => media.first,
      );
      return firstImage.url.startsWith('http')
          ? firstImage.url
          : '';
    }
    return '';
  }

  // Getter for price (from first pricing entry if available, preferably SELLING)
  int get price => sellingPrice ?? mrpPrice ?? 0;

  // Getter for Selling Price
  int? get sellingPrice {
    if (pricing.isEmpty) return null;
    for (var p in pricing) {
      if (p.pricingTypeName == 'SELLING') {
        return double.tryParse(p.price)?.toInt();
      }
    }
    return null;
  }

  // Getter for MRP Price
  int? get mrpPrice {
    if (pricing.isEmpty) return null;
    for (var p in pricing) {
      if (p.pricingTypeName == 'MRP') {
        return double.tryParse(p.price)?.toInt();
      }
    }
    return null;
  }


  /// Returns true only when backend status string is exactly 'ACTIVE'.
  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      brand: json['brand']?.toString() ?? '',
      brandName: json['brand_name'],
      brandDetails: json['brand_details'] != null
          ? BrandDetails.fromJson(json['brand_details'])
          : null,
      modelName: json['model_name'] ?? '',
      type: json['type'] ?? '',
      parent: json['parent']?.toString(),
      isOptRequired: json['is_opt_required'] ?? false,
      sku: json['sku']?.toString() ?? '',
      specification: json['specification'] is Map<String, dynamic>
          ? ProductSpecification.fromJson(json['specification'] as Map<String, dynamic>)
          : null,
      status: json['status']?.toString() ?? '',
      categories: (json['categories'] is List)
          ? (json['categories'] as List)
          .map((cat) => ProductCategory.fromJson(cat))
          .toList()
          : [],
      pricing: (json['pricing'] is List)
          ? (json['pricing'] as List)
          .map((p) => ProductPricing.fromJson(p))
          .toList()
          : [],
      attributes: (json['attributes'] is List)
          ? (json['attributes'] as List)
          .map((a) => ProductAttribute.fromJson(a))
          .toList()
          : [],
      media: (json['media'] is List)
          ? (json['media'] as List)
          .map((m) => ProductMedia.fromJson(m))
          .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'brand': brand,
      'brand_name': brandName,
      'brand_details': brandDetails?.toJson(),
      'model_name': modelName,
      'type': type,
      'parent': parent,
      'is_opt_required': isOptRequired,
      'sku': sku,
      'specification': specification?.toJson(),
      'status': status,
      'categories': categories.map((cat) => cat.toJson()).toList(),
      'pricing': pricing.map((p) => p.toJson()).toList(),
      'attributes': attributes.map((a) => a.toJson()).toList(),
      'media': media.map((m) => m.toJson()).toList(),
    };
  }
}
class PaginatedProductResponse {
  final List<Map<String, dynamic>> products;
  final int total;
  final int totalPages;
  final int currentPage;
  final bool hasMore;

  PaginatedProductResponse({
    required this.products,
    required this.total,
    required this.totalPages,
    required this.currentPage,
    required this.hasMore,
  });
}
