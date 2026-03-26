class Tool {
  final String id;
  final String name;
  final String? description;
  final String? category;       // legacy field
  final String? categoryId;     // from category_id or category_details.id
  final String? categoryName;   // from category_details.name

  Tool({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.categoryId,
    this.categoryName,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    // Extract from category_details object
    final catDetails = json['category_details'];
    String? catId;
    String? catName;
    if (catDetails is Map) {
      catId  = catDetails['id']?.toString();
      catName = catDetails['name']?.toString();
    }
    // Fallback to flat fields
    catId  ??= json['category_id']?.toString() ?? json['category']?.toString();
    catName ??= json['category_name']?.toString() ?? json['category']?.toString();

    return Tool(
      id:           json['id'] ?? '',
      name:         json['name'] ?? '',
      description:  json['description'],
      category:     json['category']?.toString(),
      categoryId:   catId,
      categoryName: catName,
    );
  }
}
