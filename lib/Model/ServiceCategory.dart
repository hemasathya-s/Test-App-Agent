import 'dart:convert';

class CategoryMedia {
  final String id;
  final String url;
  final String? type;

  CategoryMedia({
    required this.id,
    required this.url,
    this.type,
  });

  factory CategoryMedia.fromJson(Map<String, dynamic> json) {
    return CategoryMedia(
      id: json['id']?.toString() ?? '',
      url: json['url'] ?? '',
      type: json['media_type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'media_type': type,
  };
}

class ServiceCategory {
  final String id;
  final String name;
  final String description;
  final String? parent;
  final String status;
  final String type;
  final String createdAt;
  final String updatedAt;
  final List<CategoryMedia> media;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    this.parent,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.media,
  });

  String get imageUrl {
    if (media.isNotEmpty) {
      final url = media.first.url;
      if (url.startsWith('http')) {
        return url;
      }
      return "https://api-test.itfixer199.com$url";
    }
    return '';
  }

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      parent: json['parent']?.toString(),
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      media: (json['media'] is List)
          ? (json['media'] as List).map((m) => CategoryMedia.fromJson(m)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'parent': parent,
    'status': status,
    'type': type,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'media': media.map((m) => m.toJson()).toList(),
  };
}
