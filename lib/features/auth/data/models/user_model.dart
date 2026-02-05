import 'package:equatable/equatable.dart';

/// User Tier Enum (Bronze is default/free)
enum UserTier { bronze, silver, gold }

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
  final bool hasAlZabayehTier; // Al-Zabayeh add-on tier

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
    this.hasAlZabayehTier = false,
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
      hasAlZabayehTier: alZabayeh,
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
      'has_al_zabayeh_tier': hasAlZabayehTier,
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
    bool? hasAlZabayehTier,
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
      hasAlZabayehTier: hasAlZabayehTier ?? this.hasAlZabayehTier,
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

    // Date checking disabled for now
    // if (subscriptionEndDate != null && subscriptionEndDate != 'unlimited') {
    //   final end = DateTime.tryParse(subscriptionEndDate!);
    //   // If date is past, it's expired
    //   if (end != null && end.isBefore(DateTime.now())) {
    //     return SubscriptionStatus.expired;
    //   }
    // }
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
      case 29318: // رسوم تفعيل قسم الذبائح (Al-Zabayeh) - treat as Gold
        result = UserTier.gold;
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
    avatarUrl,
    role,
    isVendor,
    vendorInfo,
    subscriptionPackId,
    subscriptionEndDate,
    hasAlZabayehTier,
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
      address: json['address'] is Map
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
      featured: json['featured'],
      subscriptionId: json['subscription'] is Map
          ? json['subscription']['id']?.toString()
          : null,
      subscriptionType: json['subscription'] is Map
          ? json['subscription']['type']
          : null,
    );
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
      street1: json['street_1'] ?? json['address_1'],
      street2: json['street_2'] ?? json['address_2'],
      city: json['city'],
      state: json['state'],
      postcode: json['postcode'] ?? json['zip'],
      country: json['country'],
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
