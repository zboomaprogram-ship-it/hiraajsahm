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
  final bool trusted;

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
      showEmail: json['show_email'] ?? false,
      banner: json['banner'],
      bannerId: json['banner_id'],
      gravatar: json['gravatar'],
      gravatarId: json['gravatar_id'],
      shopUrl: json['shop_url'],
      // Map storeUrl from various possible keys
      storeUrl: json['store_url'] ?? json['url'] ?? json['shop_url'],
      // Map storeSlug from 'store_slug' or 'slug'
      storeSlug: json['store_slug'] ?? json['slug'],
      productsPerPage: json['products_per_page'] == 1,
      showMoreProductTab: json['show_more_product_tab'] ?? false,
      tocEnabled: json['toc_enabled'] ?? false,
      storeToc: json['store_toc'],
      featured: json['featured'] ?? false,
      rating: rating,
      ratingCount: ratingCount,
      enabled: json['enabled'] ?? true,
      registered: json['registered'],
      address: json['address'] != null
          ? StoreAddress.fromJson(json['address'])
          : null,
      social: json['social'] != null
          ? StoreSocial.fromJson(json['social'])
          : null,
      paymentMethod: _parsePaymentMethod(json['payment']),
      trusted: json['trusted'] ?? false,
    );
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

  String get displayName {
    if (storeName.isNotEmpty) return storeName;
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return 'متجر';
  }

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
      street1: json['street_1'],
      street2: json['street_2'],
      city: json['city'],
      zip: json['zip'],
      state: json['state'],
      country: json['country'],
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
      facebook: json['fb'],
      twitter: json['twitter'],
      pinterest: json['pinterest'],
      linkedin: json['linkedin'],
      youtube: json['youtube'],
      instagram: json['instagram'],
      flickr: json['flickr'],
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
