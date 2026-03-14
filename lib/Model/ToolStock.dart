class ToolStock {
  final String id;
  final String name;
  final int quantity;
  final String category;

  ToolStock({
    required this.id,
    required this.name,
    required this.quantity,
    required this.category,
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? (double.tryParse(value)?.toInt() ?? 0);
    return 0;
  }

  factory ToolStock.fromJson(Map<String, dynamic> json) {
    // Handle nested tool object
    Map<String, dynamic> toolMap = {};
    if (json['tool'] is Map) {
      toolMap = json['tool'];
    } else if (json['tools'] is Map) {
      toolMap = json['tools'];
    }

    String toolName = '';
    String toolCategory = 'Tools';

    if (toolMap.isNotEmpty) {
      toolName = toolMap['name'] ?? '';
      toolCategory = toolMap['category'] ?? 'Tools';
    } else {
      toolName = json['name'] ?? json['tool_name'] ?? '';
    }

    // Try finding quantity in root or inside tool object
    final qty = json['quantity'] ?? json['stock'] ?? json['current_stock'] ?? 
                json['balance'] ?? json['available_stock'] ?? 
                json['total_stock'] ?? json['stock_balance'] ??
                toolMap['quantity'] ?? toolMap['stock'] ?? toolMap['current_stock'] ??
                toolMap['balance'] ?? toolMap['total_stock'];

    return ToolStock(
      id: json['id'] ?? toolMap['id'] ?? '',
      name: toolName,
      quantity: _toInt(qty),
      category: toolCategory,
    );
  }

  Map<String, dynamic> toItemMap() => {
    'name': name,
    'qty': quantity,
    'category': category,
  };
}
