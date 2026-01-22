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

  @override
  List<Object?> get props => [id, name, slug, parent, count];
}
