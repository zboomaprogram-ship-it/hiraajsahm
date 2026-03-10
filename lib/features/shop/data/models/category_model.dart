import 'package:equatable/equatable.dart';

/// Category Model for WooCommerce Product Categories
class CategoryModel extends Equatable {
  final int id;
  final String name;
  final String slug;
  final int parent;
  final String description;
  final String? imageUrl;
  final int count;

  const CategoryModel({
    required this.id,
    required this.name,
    this.slug = '',
    this.parent = 0,
    this.description = '',
    this.imageUrl,
    this.count = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      parent: json['parent'] ?? 0,
      description: json['description'] ?? '',
      imageUrl: json['image']?['src'],
      count: json['count'] ?? 0,
    );
  }

  /// Parses from the custom WordPress menu API endpoint `/custom/v1/menu`
  factory CategoryModel.fromMenuJson(Map<String, dynamic> json) {
    String extractSlug(String urlStr) {
      if (urlStr.isEmpty) return '';
      try {
        final uri = Uri.parse(urlStr);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          // Uri.pathSegments are already URL-decoded
          return segments.last;
        }
      } catch (_) {}
      return '';
    }

    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['title'] ?? '',
      slug: extractSlug(json['url'] ?? ''),
      parent: json['parent'] ?? 0,
      description: '',
      count: 0, // Menu API doesn't provide product count
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'parent': parent,
      'description': description,
      'count': count,
    };
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasProducts => count > 0;

  CategoryModel copyWith({
    int? id,
    String? name,
    String? slug,
    int? parent,
    String? description,
    String? imageUrl,
    int? count,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      parent: parent ?? this.parent,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      count: count ?? this.count,
    );
  }

  @override
  List<Object?> get props => [id, name, slug, parent, count];

  /// Get subcategories for a given parent ID from a list of categories
  static List<CategoryModel> getSubCategories(
    List<CategoryModel> categories,
    int parentId,
  ) {
    return categories.where((cat) => cat.parent == parentId).toList();
  }
}
