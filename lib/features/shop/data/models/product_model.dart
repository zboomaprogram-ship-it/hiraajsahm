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
  final String? vendorLocation; // Added
  final String? productLocation;
  final bool isVendorVerified;
  final double? vendorRating; // Added
  final int vendorRatingCount; // Added

  final bool featured;
  final bool isLocked;
  final String? videoUrl;
  final String? qrCodeUrl;
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
    this.vendorLocation,
    this.productLocation,
    this.isVendorVerified = false,
    this.vendorRating,
    this.vendorRatingCount = 0,
    this.featured = false,
    this.isLocked = false,
    this.videoUrl,
    this.qrCodeUrl,
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
      vendorName:
          json['store']?['store_name'] ??
          json['store']?['shop_name'] ??
          'المتجر',
      vendorAvatar: json['store']?['gravatar'] ?? json['store']?['shop_url'],
      vendorPhone: json['store']?['phone'],
      vendorTier: _parseVendorTier(json['store']),
      isVendorVerified:
          json['store']?['is_verified'] == true ||
          json['store']?['is_verified'] == 'true',
      vendorAddress: _parseVendorAddress(json['store']),
      vendorLocation: _parseVendorLocation(json['store']),
      productLocation: _parseProductLocation(json['meta_data']),
      vendorRating: _parseDouble(json['store']?['rating']?['rating']),
      vendorRatingCount: _parseInt(json['store']?['rating']?['count']),
      featured: json['featured'] ?? false,
      isLocked: _parseIsLocked(json['meta_data']),
      videoUrl: _parseVideoUrl(json['meta_data']),
      qrCodeUrl: json['qr_code_url'],
      dateCreated: json['date_created'] != null
          ? DateTime.tryParse(json['date_created'])
          : null,
    );
  }

  static String _parseVendorTier(dynamic store) {
    if (store == null || store is! Map) return 'bronze';

    // Helper to check ID
    String checkId(String? id) {
      if (id == null) return '';
      final cleanId = id.trim();
      if (cleanId == '29030') return 'gold';
      if (cleanId == '29028') return 'silver';
      if (cleanId == '29026') return 'bronze';
      return '';
    }

    // 1. Check direct 'vendor_tier' field
    if (store['vendor_tier'] != null) {
      final res = checkId(store['vendor_tier'].toString());
      if (res.isNotEmpty) return res;
      final val = store['vendor_tier'].toString().toLowerCase();
      if (val == 'gold' || val == 'silver' || val == 'bronze') return val;
    }

    // 2. Check 'current_subscription' object
    final sub = store['current_subscription'];
    if (sub != null && sub is Map) {
      final res = checkId(sub['name']?.toString());
      if (res.isNotEmpty) return res;

      // Check Label
      final label = sub['label']?.toString();
      if (label != null) {
        if (label.contains('Gold') || label.contains('ذهبية')) return 'gold';
        if (label.contains('Silver') || label.contains('فضية')) return 'silver';
        if (label.contains('Bronze') || label.contains('برونزية'))
          return 'bronze';
      }
    }

    // 3. Check 'assigned_subscription' (Direct Value)
    if (store['assigned_subscription'] != null) {
      if (store['assigned_subscription'] is! Map) {
        final res = checkId(store['assigned_subscription'].toString());
        if (res.isNotEmpty) return res;
      }
    }

    // 4. Check 'assigned_subscription_info'
    final info = store['assigned_subscription_info'];
    if (info != null && info is Map) {
      final res = checkId(info['subscription_id']?.toString());
      if (res.isNotEmpty) return res;
    }

    return 'bronze';
  }

  static String? _parseVendorLocation(dynamic store) {
    if (store == null || store is! Map) return null;
    final location = store['location'];
    if (location == null) return null;

    if (location is String) return location.isNotEmpty ? location : null;

    if (location is Map) {
      final lat = location['lat'] ?? location['latitude'];
      final lng = location['lng'] ?? location['longitude'];

      if (lat != null && lng != null) {
        return '$lat,$lng';
      }
    }

    return location.toString();
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

  ProductModel copyWith({
    int? id,
    String? name,
    String? slug,
    String? permalink,
    String? type,
    String? status,
    String? description,
    String? shortDescription,
    String? sku,
    String? price,
    String? regularPrice,
    String? salePrice,
    bool? onSale,
    bool? purchasable,
    int? totalSales,
    bool? virtual,
    bool? downloadable,
    String? taxStatus,
    String? stockStatus,
    int? stockQuantity,
    bool? manageStock,
    List<String>? images,
    List<CategoryRef>? categories,
    List<AttributeRef>? attributes,
    double? averageRating,
    int? ratingCount,
    int? vendorId,
    String? vendorName,
    String? vendorAvatar,
    String? vendorPhone,
    String? vendorTier,
    String? vendorAddress,
    String? vendorLocation,
    String? productLocation,
    bool? isVendorVerified,
    double? vendorRating,
    int? vendorRatingCount,
    bool? featured,
    bool? isLocked,
    String? videoUrl,
    String? qrCodeUrl,
    DateTime? dateCreated,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      permalink: permalink ?? this.permalink,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      regularPrice: regularPrice ?? this.regularPrice,
      salePrice: salePrice ?? this.salePrice,
      onSale: onSale ?? this.onSale,
      purchasable: purchasable ?? this.purchasable,
      totalSales: totalSales ?? this.totalSales,
      virtual: virtual ?? this.virtual,
      downloadable: downloadable ?? this.downloadable,
      taxStatus: taxStatus ?? this.taxStatus,
      stockStatus: stockStatus ?? this.stockStatus,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      manageStock: manageStock ?? this.manageStock,
      images: images ?? this.images,
      categories: categories ?? this.categories,
      attributes: attributes ?? this.attributes,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorAvatar: vendorAvatar ?? this.vendorAvatar,
      vendorPhone: vendorPhone ?? this.vendorPhone,
      vendorTier: vendorTier ?? this.vendorTier,
      vendorAddress: vendorAddress ?? this.vendorAddress,
      vendorLocation: vendorLocation ?? this.vendorLocation,
      productLocation: productLocation ?? this.productLocation,
      isVendorVerified: isVendorVerified ?? this.isVendorVerified,
      vendorRating: vendorRating ?? this.vendorRating,
      vendorRatingCount: vendorRatingCount ?? this.vendorRatingCount,
      featured: featured ?? this.featured,
      isLocked: isLocked ?? this.isLocked,
      videoUrl: videoUrl ?? this.videoUrl,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      dateCreated: dateCreated ?? this.dateCreated,
    );
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
  List<Object?> get props => [
    id,
    name,
    price,
    isVendorVerified,
    vendorTier,
    vendorRating,
    vendorRating,
    vendorRatingCount,
  ];
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
