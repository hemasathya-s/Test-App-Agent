class ProductStock {
  final String id;
  final String productName;
  final String productId;
  final int stock;
  final String type;

  ProductStock({
    required this.id,
    required this.productName,
    required this.productId,
    required this.stock,
    required this.type,
  });

  factory ProductStock.fromJson(Map<String, dynamic> json) {
    // Handle nested product object
    String name = '';
    String pId = json['product_id'] ?? '';

    if (json['product'] is Map) {
      name = json['product']['name'] ?? '';
      if (pId.isEmpty) pId = json['product']['id'] ?? '';
    } else {
      name = json['product_name'] ?? json['name'] ?? '';
    }

    return ProductStock(
      id: json['id'] ?? '',
      productName: name,
      productId: pId,
      stock: json['stock'] ?? json['quantity'] ?? 0,
      type: json['type'] ?? 'PRODUCT',
    );
  }

  Map<String, dynamic> toItemMap() => {
    'name': productName,
    'qty': stock,
    'category': 'Stock',
  };
}
