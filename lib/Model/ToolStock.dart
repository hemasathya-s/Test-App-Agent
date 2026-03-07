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

  factory ToolStock.fromJson(Map<String, dynamic> json) {
    // Handle nested tool object
    String toolName = '';
    String toolCategory = 'Tools';

    if (json['tool'] is Map) {
      toolName = json['tool']['name'] ?? '';
      toolCategory = json['tool']['category'] ?? 'Tools';
    } else {
      toolName = json['name'] ?? json['tool_name'] ?? '';
    }

    return ToolStock(
      id: json['id'] ?? '',
      name: toolName,
      quantity: json['quantity'] ?? json['stock'] ?? 0,
      category: toolCategory,
    );
  }

  Map<String, dynamic> toItemMap() => {
    'name': name,
    'qty': quantity,
    'category': category,
  };
}
