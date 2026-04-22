import 'package:equatable/equatable.dart';

/// User Tier Enum (Bronze is default/free)
enum UserTier { bronze, silver, gold, zabayeh }

/// Subscription Status Enum
enum SubscriptionStatus { active, expired, none }

/// User Model
class UserModel extends Equatable {
  final int id;
  final String email;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final String? phone; // Added
  final String? address; // Added for Autofill
  final String? avatarUrl;
  final String role;
  final bool isVendor;
  final VendorInfo? vendorInfo;
  final int? subscriptionPackId;
  final String? subscriptionEndDate;
  final String? customerQrUrl; // Added
  final String? region; // Added
  final String? city; // Added
  final bool hasAlZabayehTier; // Al-Zabayeh add-on tier
  final String? downPaymentValue; // Added

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.phone,
    this.address,
    this.avatarUrl,
    required this.role,
    this.isVendor = false,
    this.vendorInfo,
    this.subscriptionPackId,
    this.subscriptionEndDate,
    this.customerQrUrl, // Added
    this.city, // Added
    this.region, // Added
    this.hasAlZabayehTier = false,
    this.downPaymentValue, // Added
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle role as string (WooCommerce) or list (WordPress)
    String role = 'customer';
    if (json['role'] != null) {
      if (json['role'] is List) {
        final roles = json['role'] as List<dynamic>;
        role = roles.isNotEmpty ? roles.first.toString() : 'customer';
      } else {
        role = json['role'].toString();
      }
    } else if (json['roles'] != null && json['roles'] is List) {
      final roles = json['roles'] as List<dynamic>;
      role = roles.isNotEmpty ? roles.first.toString() : 'customer';
    }

    final isVendor =
        role == 'Vendor' ||
        role == 'vendor' ||
        role == 'administrator' ||
        role == 'seller';

    int? packId;
    String? endDate;

    // Parse meta_data for subscription info
    if (json['meta_data'] != null) {
      final meta = json['meta_data'] as List;

      // Parse ID
      final packItem = meta.firstWhere(
        (i) => i['key'] == 'product_package_id',
        orElse: () => null,
      );
      if (packItem != null) packId = int.tryParse(packItem['value'].toString());

      // Parse Date
      final dateItem = meta.firstWhere(
        (i) => i['key'] == 'product_pack_enddate',
        orElse: () => null,
      );
      if (dateItem != null) endDate = dateItem['value'].toString();
    }

    // Check for Al-Zabayeh/Sacrifices verification (sacrifices_verified = yes)
    bool alZabayeh = packId == 29318;
    if (!alZabayeh && json['meta_data'] != null) {
      final meta = json['meta_data'] as List;
      // Check for sacrifices_verified key (the official verification)
      final verifiedItem = meta.firstWhere(
        (i) => i['key'] == 'sacrifices_verified' && i['value'] == 'yes',
        orElse: () => null,
      );
      alZabayeh = verifiedItem != null;
    }

    // Parse Address (billing.address_1)
    String? address;
    if (json['billing'] != null && json['billing']['address_1'] != null) {
      address = json['billing']['address_1'];
    }

    // DEBUG: Print parsed subscription info
    print('🔍 UserModel.fromJson DEBUG:');
    print('   role: $role');
    print('   isVendor: $isVendor');
    print('   packId: $packId');
    print('   endDate: $endDate');

    // Parse Phone
    String? phone;
    if (json['billing'] != null && json['billing'] is Map) {
      phone = json['billing']['phone'];
    }
    if (phone == null && json['phone'] != null) {
      phone = json['phone'];
    }

    // Parse QR Code URL
    String? qrUrl = json['customer_qr_url'];

    // Parse City & Region from meta_data if not directly available
    String? city;
    String? region;
    String? downPaymentValue;

    if (json['meta_data'] != null) {
      final meta = json['meta_data'] as List;
      
      final cityItem = meta.firstWhere(
        (i) => i['key'] == 'region',
        orElse: () => null,
      );
      if (cityItem != null) city = cityItem['value'].toString();

      final regionItem = meta.firstWhere(
        (i) => i['key'] == 'city',
        orElse: () => null,
      );
      if (regionItem != null) region = regionItem['value'].toString();

      final downPaymentItem = meta.firstWhere(
        (i) => i['key'] == 'add_down_payment_field',
        orElse: () => null,
      );
      if (downPaymentItem != null) {
        downPaymentValue = downPaymentItem['value'].toString();
      }
    }
    // Fallback to billing if meta not found
    city ??= json['billing']?['state'];
    region ??= json['billing']?['city'];

    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      email: json['email'] ?? '',
      displayName:
          json['username'] ?? json['display_name'] ?? json['name'] ?? '',
      firstName: json['first_name'] ?? json['firstname'],
      lastName: json['last_name'] ?? json['lastname'],
      phone: json['billing']?['phone'] ?? json['phone'],
      address: address, // Added
      avatarUrl:
          json['avatar_url'] ?? json['avatar'] ?? _extractAvatarUrl(json),
      role: role,
      isVendor: isVendor,
      vendorInfo: isVendor && json['store'] is Map
          ? VendorInfo.fromJson(json['store'])
          : null,
      subscriptionPackId: packId,
      subscriptionEndDate: endDate,
      customerQrUrl: qrUrl, // Added
      city: city, // Added
      region: region, // Added
      hasAlZabayehTier: alZabayeh,
      downPaymentValue: downPaymentValue, // Added
    );
  }

  static String? _extractAvatarUrl(Map<String, dynamic> json) {
    if (json['avatar_urls'] != null && json['avatar_urls'] is Map) {
      final avatarUrls = json['avatar_urls'] as Map;
      return avatarUrls['96']?.toString() ??
          avatarUrls['48']?.toString() ??
          avatarUrls['24']?.toString();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'address': address,
      'avatar_url': avatarUrl,
      'role': role,
      'is_vendor': isVendor,
      'vendor_info': vendorInfo?.toJson(),
      'product_package_id': subscriptionPackId,
      'subscription_end_date': subscriptionEndDate,
      'customer_qr_url': customerQrUrl,
      'city': city,
      'region': region,
      'has_al_zabayeh_tier': hasAlZabayehTier,
      'add_down_payment_field': downPaymentValue,
    };
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? phone,
    String? address, // Added
    String? avatarUrl,
    String? role,
    bool? isVendor,
    VendorInfo? vendorInfo,
    int? subscriptionPackId,
    String? subscriptionEndDate,
    String? customerQrUrl,
    String? city,
    String? region,
    bool? hasAlZabayehTier,
    String? downPaymentValue,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      address: address ?? this.address, // Added
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isVendor: isVendor ?? this.isVendor,
      vendorInfo: vendorInfo ?? this.vendorInfo,
      subscriptionPackId: subscriptionPackId ?? this.subscriptionPackId,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      customerQrUrl: customerQrUrl ?? this.customerQrUrl,
      city: city ?? this.city,
      region: region ?? this.region,
      hasAlZabayehTier: hasAlZabayehTier ?? this.hasAlZabayehTier,
      downPaymentValue: downPaymentValue ?? this.downPaymentValue,
    );
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName'.trim();
    }
    return displayName;
  }

  // Helper: Check Status (Valid or Expired?)
  SubscriptionStatus get subscriptionStatus {
    // If no pack ID, they are effectively "None" (which we treat as Bronze/Free)
    if (subscriptionPackId == null) return SubscriptionStatus.none;

    // Re-enabled expiry checking for all tiers
    if (subscriptionEndDate != null &&
        subscriptionEndDate != 'unlimited' &&
        subscriptionEndDate!.isNotEmpty) {
      try {
        final end = DateTime.tryParse(subscriptionEndDate!);
        // If date is past, it's expired
        if (end != null && end.isBefore(DateTime.now())) {
          return SubscriptionStatus.expired;
        }
      } catch (e) {
        print('⚠️ Error parsing subscription end date: $e');
      }
    }
    return SubscriptionStatus.active;
  }

  // Computed Tier
  UserTier get tier {
    print('🎯 UserTier.tier DEBUG:');
    print('   subscriptionPackId: $subscriptionPackId');
    print('   subscriptionStatus: $subscriptionStatus');

    // Rule: If no subscription, you are BRONZE.
    if (subscriptionStatus == SubscriptionStatus.none) {
      print('   RESULT: bronze (no subscription)');
      return UserTier.bronze;
    }

    // Check the ID - CORRECT IDs from backend
    UserTier result;
    switch (subscriptionPackId) {
      case 29030: // الباقة الذهبية (Gold)
        result = UserTier.gold;
        break;
      case 29028: // الباقة الفضية (Silver) - if exists
        result = UserTier.silver;
        break;
      case 29026: // عضوية برونزية (Bronze)
        result = UserTier.bronze;
        break;
      case 29318: // رسوم تفعيل قسم الذبائح (Al-Zabayeh)
        result = UserTier.zabayeh;
        break;
      default:
        result = UserTier.bronze; // Fallback
    }
    print('   RESULT: ${result.name}');
    return result;
  }

  // Permission Helpers
  bool get isSilverOrGold => tier == UserTier.silver || tier == UserTier.gold;
  bool get isGold => tier == UserTier.gold;

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    firstName,
    lastName,
    phone,
    address,
    avatarUrl,
    role,
    isVendor,
    vendorInfo,
    subscriptionPackId,
    subscriptionEndDate,
    customerQrUrl,
    city,
    region,
    hasAlZabayehTier,
    downPaymentValue,
  ];
}

/// Vendor Information Model
class VendorInfo extends Equatable {
  final int? storeId;
  final String? storeName;
  final String? storeSlug;
  final String? storeUrl;
  final String? banner;
  final String? bannerUrl;
  final String? phone;
  final AddressModel? address;
  final double? rating;
  final int? reviewCount;
  final bool? featured;
  final String? subscriptionId;
  final String? subscriptionType;
  final String? biography;
  final String? location;
  final bool? isVerified;
  final Map<String, dynamic>? social;

  const VendorInfo({
    this.storeId,
    this.storeName,
    this.storeSlug,
    this.storeUrl,
    this.banner,
    this.bannerUrl,
    this.phone,
    this.address,
    this.rating,
    this.reviewCount,
    this.featured,
    this.subscriptionId,
    this.subscriptionType,
    this.biography,
    this.location,
    this.isVerified,
    this.social,
  });

  factory VendorInfo.fromJson(Map<String, dynamic> json) {
    return VendorInfo(
      storeId: json['id'],
      storeName: json['store_name'] ?? json['name'],
      storeSlug: json['store_slug'] ?? json['slug'],
      storeUrl: json['store_url'] ?? json['url'],
      banner: json['banner'],
      bannerUrl: json['banner_url'] ?? json['gravatar'],
      phone: json['phone'],
      address: (json['address'] is Map)
          ? AddressModel.fromJson(Map<String, dynamic>.from(json['address']))
          : null,
      rating: json['rating'] is Map
          ? (json['rating']['rating'] != null &&
                    json['rating']['rating'].toString().isNotEmpty
                ? double.tryParse(json['rating']['rating'].toString())
                : 0.0)
          : (json['rating'] is num ? (json['rating'] as num).toDouble() : 0.0),
      reviewCount: json['rating'] is Map
          ? (json['rating']['count'] ?? 0)
          : (json['review_count'] ?? 0),
      featured: _parseBool(json['featured']),
      subscriptionId: json['subscription'] is Map
          ? json['subscription']['id']?.toString()
          : null,
      subscriptionType: json['subscription'] is Map
          ? json['subscription']['type']
          : null,
      biography: json['vendor_biography']?.toString(),
      location: json['location']?.toString(),
      isVerified: _parseBool(json['is_verified']),
      social: json['social'] is Map
          ? Map<String, dynamic>.from(json['social'])
          : null,
    );
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    if (value is num) return value == 1;
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'store_slug': storeSlug,
      'store_url': storeUrl,
      'banner': banner,
      'banner_url': bannerUrl,
      'phone': phone,
      'address': address?.toJson(),
      'rating': rating,
      'review_count': reviewCount,
      'featured': featured,
      'subscription_id': subscriptionId,
      'subscription_type': subscriptionType,
      'vendor_biography': biography,
      'location': location,
      'is_verified': isVerified,
      'social': social,
    };
  }

  @override
  List<Object?> get props => [
    storeId,
    storeName,
    storeSlug,
    storeUrl,
    banner,
    bannerUrl,
    phone,
    address,
    rating,
    reviewCount,
    featured,
    subscriptionId,
    subscriptionType,
    biography,
    location,
    isVerified,
    social,
  ];
}

/// Address Model
class AddressModel extends Equatable {
  final String? street1;
  final String? street2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;

  const AddressModel({
    this.street1,
    this.street2,
    this.city,
    this.state,
    this.postcode,
    this.country,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      street1: json['street_1']?.toString(),
      street2: json['street_2']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      postcode: json['postcode']?.toString() ?? json['zip']?.toString(),
      country: json['country']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street_1': street1,
      'street_2': street2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
    };
  }

  String get fullAddress {
    final parts = <String>[];
    if (street1?.isNotEmpty == true) parts.add(street1!);
    if (street2?.isNotEmpty == true) parts.add(street2!);
    if (city?.isNotEmpty == true) parts.add(city!);
    if (state?.isNotEmpty == true) parts.add(state!);
    if (country?.isNotEmpty == true) parts.add(country!);
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [street1, street2, city, state, postcode, country];
}
