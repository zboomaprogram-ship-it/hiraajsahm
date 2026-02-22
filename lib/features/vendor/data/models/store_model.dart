import 'package:equatable/equatable.dart';

/// Store Model for Dokan Vendor Stores
class StoreModel extends Equatable {
  final int id;
  final String storeName;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool showEmail;
  final String? banner;
  final int? bannerId;
  final String? gravatar;
  final int? gravatarId;
  final String? shopUrl; // Original Dokan field
  final String? storeUrl; // New field for Custom/Direct URL
  final String? storeSlug; // New field for Slug (e.g. 'my-store')
  final bool productsPerPage;
  final bool showMoreProductTab;
  final bool tocEnabled;
  final String? storeToc;
  final bool featured;
  final double? rating;
  final int? ratingCount;
  final bool enabled;
  final String? registered;
  final StoreAddress? address;
  final StoreSocial? social;
  final String? paymentMethod;
  final String? biography;
  final String? location;
  final bool isVerified;
  final bool trusted;
  final String vendorTier;
  final int publishedProducts;
  final int remainingProducts;

  const StoreModel({
    required this.id,
    required this.storeName,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.showEmail = false,
    this.banner,
    this.bannerId,
    this.gravatar,
    this.gravatarId,
    this.shopUrl,
    this.storeUrl,
    this.storeSlug,
    this.productsPerPage = false,
    this.showMoreProductTab = false,
    this.tocEnabled = false,
    this.storeToc,
    this.featured = false,
    this.rating,
    this.ratingCount,
    this.enabled = true,
    this.registered,
    this.address,
    this.social,
    this.paymentMethod,
    this.trusted = false,
    this.biography,
    this.location,
    this.isVerified = false,
    this.vendorTier = 'bronze',
    this.publishedProducts = 0,
    this.remainingProducts = -1, // -1 means unlimited or unknown
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    // Parse rating
    double? rating;
    int? ratingCount;
    if (json['rating'] is Map) {
      rating = double.tryParse(json['rating']['rating']?.toString() ?? '0');
      ratingCount = int.tryParse(json['rating']['count']?.toString() ?? '0');
    }

    return StoreModel(
      id: json['id'] ?? 0,
      storeName: json['store_name'] ?? json['name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      showEmail: _parseBool(json['show_email']),
      banner: json['banner'],
      bannerId: json['banner_id'],
      gravatar: json['gravatar'],
      gravatarId: json['gravatar_id'],
      shopUrl: json['shop_url'],
      // Map storeUrl from various possible keys
      storeUrl: json['store_url'] ?? json['url'] ?? json['shop_url'],
      // Map storeSlug from 'store_slug' or 'slug'
      storeSlug: json['store_slug'] ?? json['slug'],
      productsPerPage:
          json['products_per_page'] == 1 || json['products_per_page'] == true,
      showMoreProductTab: _parseBool(json['show_more_product_tab']),
      tocEnabled: _parseBool(json['toc_enabled']),
      storeToc: json['store_toc'],
      featured: _parseBool(json['featured']),
      rating: rating,
      ratingCount: ratingCount,
      enabled: _parseBool(json['enabled'], defaultValue: true),
      registered: json['registered'],
      address: (json['address'] is Map)
          ? StoreAddress.fromJson(Map<String, dynamic>.from(json['address']))
          : null,
      social: (json['social'] is Map)
          ? StoreSocial.fromJson(Map<String, dynamic>.from(json['social']))
          : null,
      paymentMethod: _parsePaymentMethod(json['payment']),
      trusted: _parseBool(json['trusted']),
      biography: json['vendor_biography']?.toString(),
      location: json['location']?.toString(),
      isVerified: _parseBool(json['is_verified']),
      vendorTier: _parseVendorTier(json),
      publishedProducts: _parseInt(json['published_products']),
      remainingProducts: _parseInt(
        json['remaining_products'],
        defaultValue: -1,
      ),
    );
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  static String _parseVendorTier(Map<String, dynamic> json) {
    // Helper to check ID
    String checkId(String? id) {
      if (id == null) return '';
      final cleanId = id.trim();
      if (cleanId == '29030') return 'gold';
      if (cleanId == '29028') return 'silver';
      if (cleanId == '29026') return 'bronze';
      return '';
    }

    // 1. Check direct 'vendor_tier' field (if exists from custom API)
    if (json['vendor_tier'] != null) {
      final res = checkId(json['vendor_tier'].toString());
      if (res.isNotEmpty) return res;
      final val = json['vendor_tier'].toString().toLowerCase();
      if (val == 'gold' || val == 'silver' || val == 'bronze') return val;
    }

    // 2. Check 'current_subscription' object from Dokan API
    final sub = json['current_subscription'];
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
    if (json['assigned_subscription'] != null) {
      if (json['assigned_subscription'] is! Map) {
        final res = checkId(json['assigned_subscription'].toString());
        if (res.isNotEmpty) return res;
      }
    }

    // 4. Check 'assigned_subscription_info'
    final info = json['assigned_subscription_info'];
    if (info != null && info is Map) {
      final res = checkId(info['subscription_id']?.toString());
      if (res.isNotEmpty) return res;
    }

    // Default
    return 'bronze';
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    if (value is num) return value == 1;
    return defaultValue;
  }

  static String? _parsePaymentMethod(dynamic payment) {
    if (payment == null) return null;
    try {
      if (payment is Map) {
        final paypal = payment['paypal'];
        if (paypal is List && paypal.isNotEmpty) {
          final firstItem = paypal[0];
          if (firstItem is String) return firstItem;
          if (firstItem is Map) return firstItem['value']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  // Requested: Only show store_name
  String get displayName => storeName.isNotEmpty ? storeName : 'متجر';

  /// Helper to get the best available link
  String get permalink => storeUrl ?? shopUrl ?? '';

  @override
  List<Object?> get props => [
    id,
    storeName,
    email,
    phone,
    banner,
    gravatar,
    rating,
    ratingCount,
    address,
    storeUrl,
    storeSlug,
    biography,
    location,
    isVerified,
    vendorTier,
    publishedProducts,
    remainingProducts,
  ];
}

/// Store Address Model
class StoreAddress extends Equatable {
  final String? street1;
  final String? street2;
  final String? city;
  final String? zip;
  final String? state;
  final String? country;

  const StoreAddress({
    this.street1,
    this.street2,
    this.city,
    this.zip,
    this.state,
    this.country,
  });

  factory StoreAddress.fromJson(Map<String, dynamic> json) {
    return StoreAddress(
      street1: json['street_1']?.toString(),
      street2: json['street_2']?.toString(),
      city: json['city']?.toString(),
      zip: json['zip']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
    );
  }

  String get fullAddress {
    final parts = <String>[];
    if (street1?.isNotEmpty == true) parts.add(street1!);
    if (city?.isNotEmpty == true) parts.add(city!);
    if (state?.isNotEmpty == true) parts.add(state!);
    if (country?.isNotEmpty == true) parts.add(country!);
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [street1, street2, city, zip, state, country];
}

/// Store Social Links Model
class StoreSocial extends Equatable {
  final String? facebook;
  final String? twitter;
  final String? pinterest;
  final String? linkedin;
  final String? youtube;
  final String? instagram;
  final String? flickr;

  const StoreSocial({
    this.facebook,
    this.twitter,
    this.pinterest,
    this.linkedin,
    this.youtube,
    this.instagram,
    this.flickr,
  });

  factory StoreSocial.fromJson(Map<String, dynamic> json) {
    return StoreSocial(
      facebook: json['fb']?.toString(),
      twitter: json['twitter']?.toString(),
      pinterest: json['pinterest']?.toString(),
      linkedin: json['linkedin']?.toString(),
      youtube: json['youtube']?.toString(),
      instagram: json['instagram']?.toString(),
      flickr: json['flickr']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    facebook,
    twitter,
    pinterest,
    linkedin,
    youtube,
    instagram,
    flickr,
  ];
}
