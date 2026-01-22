import 'package:equatable/equatable.dart';

/// Product Model for WooCommerce Products
class ProductModel extends Equatable {
  final int id;
  final String name;
  final String slug;
  final String permalink;
  final String type;
  final String status;
  final String description;
  final String shortDescription;
  final String sku;
  final String price;
  final String regularPrice;
  final String salePrice;
  final bool onSale;
  final bool purchasable;
  final int totalSales;
  final bool virtual;
  final bool downloadable;
  final String taxStatus;
  final String stockStatus;
  final int? stockQuantity;
  final bool manageStock;
  final List<String> images;
  final List<CategoryRef> categories;
  final List<AttributeRef> attributes;
  final double? averageRating;
  final int ratingCount;
  final int? vendorId;
  final String? vendorName;
  final String? vendorAvatar; // Vendor profile image URL
  final String? vendorPhone; // Added
  final String vendorTier; // 'bronze', 'silver', 'gold'
  final String? vendorAddress;
  final String? productLocation;

  final bool featured;
  final bool isLocked;
  final String? videoUrl;
  final DateTime? dateCreated;

  const ProductModel({
    required this.id,
    required this.name,
    this.slug = '',
    this.permalink = '',
    this.type = 'simple',
    this.status = 'publish',
    this.description = '',
    this.shortDescription = '',
    this.sku = '',
    required this.price,
    this.regularPrice = '',
    this.salePrice = '',
    this.onSale = false,
    this.purchasable = true,
    this.totalSales = 0,
    this.virtual = false,
    this.downloadable = false,
    this.taxStatus = 'taxable',
    this.stockStatus = 'instock',
    this.stockQuantity,
    this.manageStock = false,
    this.images = const [],
    this.categories = const [],
    this.attributes = const [],
    this.averageRating,
    this.ratingCount = 0,
    this.vendorId,
    this.vendorName,
    this.vendorAvatar,
    this.vendorPhone,
    this.vendorTier = 'bronze',
    this.vendorAddress,
    this.productLocation,
    this.featured = false,
    this.isLocked = false,
    this.videoUrl,
    this.dateCreated,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      permalink: json['permalink'] ?? '',
      type: json['type'] ?? 'simple',
      status: json['status'] ?? 'publish',
      description: json['description'] ?? '',
      shortDescription: json['short_description'] ?? '',
      sku: json['sku'] ?? '',
      price: json['price']?.toString() ?? '0',
      regularPrice: json['regular_price']?.toString() ?? '',
      salePrice: json['sale_price']?.toString() ?? '',
      onSale: json['on_sale'] ?? false,
      purchasable: json['purchasable'] ?? true,
      totalSales: _parseInt(json['total_sales']),
      virtual: json['virtual'] ?? false,
      downloadable: json['downloadable'] ?? false,
      taxStatus: json['tax_status'] ?? 'taxable',
      stockStatus: json['stock_status'] ?? 'instock',
      stockQuantity: json['stock_quantity'],
      manageStock: json['manage_stock'] ?? false,
      images: _parseImages(json['images']),
      categories: _parseCategories(json['categories']),
      attributes: _parseAttributes(json['attributes']),
      averageRating: _parseDouble(json['average_rating']),
      ratingCount: _parseInt(json['rating_count']),
      vendorId: json['store']?['id'],
      vendorName: json['store']?['name'],
      vendorAvatar: json['store']?['gravatar'] ?? json['store']?['shop_url'],
      vendorPhone: json['store']?['phone'],
      vendorTier: json['store']?['vendor_tier'] ?? 'bronze',
      vendorAddress: _parseVendorAddress(json['store']),
      productLocation: _parseProductLocation(json['meta_data']),
      featured: json['featured'] ?? false,
      isLocked: _parseIsLocked(json['meta_data']),
      videoUrl: _parseVideoUrl(json['meta_data']),

      dateCreated: json['date_created'] != null
          ? DateTime.tryParse(json['date_created'])
          : null,
    );
  }

  static String? _parseProductLocation(dynamic metaData) {
    if (metaData is List) {
      final item = metaData.firstWhere(
        (m) => m is Map && m['key'] == '_product_location',
        orElse: () => null,
      );
      if (item != null) {
        return item['value']?.toString();
      }
    }
    return null;
  }

  static String? _parseVendorAddress(dynamic store) {
    if (store == null || store is! Map) return null;
    final address = store['address'];
    if (address == null) return null;

    if (address is String) return address.isNotEmpty ? address : null;

    if (address is Map) {
      final parts = <String>[];
      if (address['street_1'] != null &&
          address['street_1'].toString().isNotEmpty) {
        parts.add(address['street_1']);
      }
      if (address['city'] != null && address['city'].toString().isNotEmpty) {
        parts.add(address['city']);
      }
      if (address['country'] != null &&
          address['country'].toString().isNotEmpty) {
        parts.add(address['country']);
      }
      return parts.isNotEmpty ? parts.join(', ') : null;
    }
    return null;
  }

  static bool _parseIsLocked(dynamic metaData) {
    if (metaData is List) {
      return metaData.any(
        (m) =>
            m is Map &&
            m['key'] == '_product_locked' &&
            m['value'].toString().toLowerCase() == 'yes',
      );
    }
    return false;
  }

  static String? _parseVideoUrl(dynamic metaData) {
    if (metaData is List) {
      for (final m in metaData) {
        if (m is Map && m['key'] == '_product_video') {
          final value = m['value'];
          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'type': type,
      'status': status,
      'description': description,
      'short_description': shortDescription,
      'sku': sku,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'categories': categories.map((c) => c.toJson()).toList(),
      'images': images.map((url) => {'src': url}).toList(),
    };
  }

  static List<String> _parseImages(dynamic images) {
    if (images == null) return [];
    if (images is! List) return [];
    return images
        .map<String?>((img) => img['src']?.toString())
        .whereType<String>()
        .toList();
  }

  static List<CategoryRef> _parseCategories(dynamic categories) {
    if (categories == null) return [];
    if (categories is! List) return [];
    return categories.map((c) => CategoryRef.fromJson(c)).toList();
  }

  static List<AttributeRef> _parseAttributes(dynamic attributes) {
    if (attributes == null) return [];
    if (attributes is! List) return [];
    return attributes.map((a) => AttributeRef.fromJson(a)).toList();
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool get isInStock => stockStatus == 'instock';
  bool get hasDiscount => onSale && salePrice.isNotEmpty;

  double get priceAsDouble => double.tryParse(price) ?? 0;
  double get regularPriceAsDouble => double.tryParse(regularPrice) ?? 0;
  double get salePriceAsDouble => double.tryParse(salePrice) ?? 0;

  double get discountPercentage {
    if (!hasDiscount || regularPriceAsDouble == 0) return 0;
    return ((regularPriceAsDouble - salePriceAsDouble) / regularPriceAsDouble) *
        100;
  }

  /// Arboun deposit percentage based on vendor tier
  /// Bronze vendors: 1% deposit, Silver/Gold vendors: 10% deposit
  double get depositPercentage {
    if (vendorTier == 'silver' || vendorTier == 'gold') {
      return 0.10; // 10%
    }
    return 0.01; // 1%
  }

  /// Calculate deposit amount for inspection (Arboun)
  double get depositAmount => priceAsDouble * depositPercentage;

  @override
  List<Object?> get props => [id, name, price];
}

/// Category Reference
class CategoryRef extends Equatable {
  final int id;
  final String name;
  final String slug;

  const CategoryRef({required this.id, required this.name, this.slug = ''});

  factory CategoryRef.fromJson(Map<String, dynamic> json) {
    return CategoryRef(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id};

  @override
  List<Object?> get props => [id, name];
}

/// Attribute Reference
class AttributeRef extends Equatable {
  final int id;
  final String name;
  final List<String> options;

  const AttributeRef({
    required this.id,
    required this.name,
    this.options = const [],
  });

  factory AttributeRef.fromJson(Map<String, dynamic> json) {
    return AttributeRef(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      options: (json['options'] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  List<Object?> get props => [id, name, options];
}
