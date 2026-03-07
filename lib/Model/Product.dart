class Product {
  final String id;
  final String name;
  final String? description;
  final String? brand;
  final String? modelName;
  final String? type;
  final String? sku;
  final String? status;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.brand,
    this.modelName,
    this.type,
    this.sku,
    this.status,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      brand: json['brand'],
      modelName: json['model_name'],
      type: json['type'],
      sku: json['sku'],
      status: json['status'],
    );
  }
}

class ProductResponse {
  final bool success;
  final List<Product> data;

  ProductResponse({required this.success, required this.data});

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List? ?? [];
    List<Product> productList = list.map((i) => Product.fromJson(i)).toList();
    return ProductResponse(
      success: json['success'] ?? false,
      data: productList,
    );
  }
}
