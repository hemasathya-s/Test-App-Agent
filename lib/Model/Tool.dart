class Tool {
  final String id;
  final String name;
  final String? description;
  final String? category;

  Tool({
    required this.id,
    required this.name,
    this.description,
    this.category,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'],
    );
  }
}
