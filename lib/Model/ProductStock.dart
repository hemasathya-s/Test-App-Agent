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

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? (double.tryParse(value)?.toInt() ?? 0);
    return 0;
  }

  factory ProductStock.fromJson(Map<String, dynamic> json) {
    // Handle nested product object
    Map<String, dynamic> pMap = {};
    if (json['product'] is Map) {
      pMap = json['product'];
    }

    String name = '';
    String pId = json['product_id'] ?? '';

    if (pMap.isNotEmpty) {
      name = pMap['name'] ?? '';
      if (pId.isEmpty) pId = pMap['id'] ?? '';
    } else {
      name = json['product_name'] ?? json['name'] ?? '';
    }

    // Try finding stock in root or inside product object
    final rawStock = json['stock'] ?? json['quantity'] ?? json['current_stock'] ?? 
                     json['balance'] ?? json['available_stock'] ??
                     pMap['stock'] ?? pMap['quantity'] ?? pMap['current_stock'];

    return ProductStock(
      id: json['id'] ?? pMap['id'] ?? '',
      productName: name,
      productId: pId,
      stock: _toInt(rawStock),
      type: json['type'] ?? 'PRODUCT',
    );
  }

  Map<String, dynamic> toItemMap() => {
    'name': productName,
    'qty': stock,
    'category': 'Stock',
  };
}
