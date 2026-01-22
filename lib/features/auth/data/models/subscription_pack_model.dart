import 'package:equatable/equatable.dart';

/// Subscription Pack Model for Dokan Vendor Registration
class SubscriptionPackModel extends Equatable {
  final int id;
  final String title;
  final String description;
  final double price;
  final String priceFormatted;
  final int productLimit;
  final String billingCycle;
  final int billingCycleCount;
  final int trialDays;
  final List<String> features;
  final bool isPopular;
  final bool isFree;
  final bool isLocked;
  final String? lockMessage;

  const SubscriptionPackModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceFormatted,
    required this.productLimit,
    required this.billingCycle,
    required this.billingCycleCount,
    required this.trialDays,
    required this.features,
    this.isPopular = false,
    this.isFree = false,
    this.isLocked = false,
    this.lockMessage,
  });

  /// Create from WooCommerce Product JSON (category 122)
  factory SubscriptionPackModel.fromProductJson(Map<String, dynamic> json) {
    final price = double.tryParse(json['price']?.toString() ?? '0') ?? 0;
    final name = json['name'] ?? '';
    final description = (json['description'] ?? json['short_description'] ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), ''); // Clean HTML tags

    return SubscriptionPackModel(
      id: json['id'] ?? 0,
      title: name,
      description: description,
      price: price,
      priceFormatted: price == 0 ? 'مجاني' : '${price.toStringAsFixed(0)} ر.س',
      productLimit: -1, // Unlimited for subscription packs
      billingCycle: 'month',
      billingCycleCount: 1,
      trialDays: 0,
      features: _parseFeaturesFromDescription(description, name),
      isPopular:
          name.toLowerCase().contains('ذهب') ||
          name.toLowerCase().contains('gold'),
      isFree: price == 0,
      isLocked: false,
      lockMessage: null,
    );
  }

  static List<String> _parseFeaturesFromDescription(
    String description,
    String name,
  ) {
    final features = <String>[];
    final nameLower = name.toLowerCase();

    // Add tier-specific features based on name
    if (nameLower.contains('برونز') || nameLower.contains('bronze')) {
      features.addAll(['حساب تاجر أساسي', 'إضافة إعلانات', 'دعم فني']);
    } else if (nameLower.contains('فض') || nameLower.contains('silver')) {
      features.addAll(['ظهور أفضل في البحث', 'دعم فني سريع', 'عمولة مخفضة']);
    } else if (nameLower.contains('ذهب') || nameLower.contains('gold')) {
      features.addAll([
        'عرض مميز للإعلانات',
        'دعم فني متقدم',
        'إحصائيات مفصلة',
        'بدون عمولة',
      ]);
    } else if (nameLower.contains('زباي') || nameLower.contains('zabayeh')) {
      features.addAll([
        'شارة الزباية المميزة',
        'أولوية في العرض',
        'دعم VIP',
        'بدون عمولة',
      ]);
    }

    return features;
  }

  factory SubscriptionPackModel.fromJson(Map<String, dynamic> json) {
    final price = double.tryParse(json['price']?.toString() ?? '0') ?? 0;

    return SubscriptionPackModel(
      id: json['id'] ?? 0,
      title: json['post_title'] ?? json['title'] ?? '',
      description: json['post_content'] ?? json['description'] ?? '',
      price: price,
      priceFormatted:
          json['price_formatted'] ?? '\$${price.toStringAsFixed(2)}',
      productLimit:
          int.tryParse(json['number_of_products']?.toString() ?? '-1') ?? -1,
      billingCycle:
          json['recurring_interval'] ?? json['billing_cycle'] ?? 'month',
      billingCycleCount:
          int.tryParse(json['recurring_period']?.toString() ?? '1') ?? 1,
      trialDays:
          int.tryParse(
            json['trial_period_types']?['days']?.toString() ?? '0',
          ) ??
          0,
      features: _parseFeatures(json),
      isPopular:
          json['is_popular'] == true ||
          json['title']?.toString().toLowerCase().contains('gold') == true,
      isFree:
          price == 0 ||
          json['title']?.toString().toLowerCase().contains('free') == true,
    );
  }

  static List<String> _parseFeatures(Map<String, dynamic> json) {
    final features = <String>[];

    // Product limit
    final productLimit = json['number_of_products'] ?? -1;
    if (productLimit == -1) {
      features.add('Unlimited products');
    } else {
      features.add('$productLimit products');
    }

    // Bookings
    if (json['booking'] == 'on') {
      features.add('Bookings enabled');
    }

    // Auctions
    if (json['auction'] == 'on') {
      features.add('Auctions enabled');
    }

    // Staff
    final staffMembers = json['staff_members'] ?? 0;
    if (staffMembers > 0) {
      features.add('$staffMembers staff members');
    }

    // Store Support
    if (json['store_support'] == 'on') {
      features.add('Store support');
    }

    // Featured
    if (json['featured_Vendor'] == 'on') {
      features.add('Featured Vendor badge');
    }

    return features;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'price_formatted': priceFormatted,
      'product_limit': productLimit,
      'billing_cycle': billingCycle,
      'billing_cycle_count': billingCycleCount,
      'trial_days': trialDays,
      'features': features,
      'is_popular': isPopular,
      'is_free': isFree,
    };
  }

  String get productLimitDisplay {
    if (productLimit == -1) {
      return 'Unlimited';
    }
    return '$productLimit';
  }

  String get billingDisplay {
    if (isFree) {
      return 'Free';
    }
    final period = billingCycleCount > 1
        ? '$billingCycleCount ${billingCycle}s'
        : billingCycle;
    return '$priceFormatted / $period';
  }

  /// Copy with updated fields (for applying restrictions)
  SubscriptionPackModel copyWith({bool? isLocked, String? lockMessage}) {
    return SubscriptionPackModel(
      id: id,
      title: title,
      description: description,
      price: price,
      priceFormatted: priceFormatted,
      productLimit: productLimit,
      billingCycle: billingCycle,
      billingCycleCount: billingCycleCount,
      trialDays: trialDays,
      features: features,
      isPopular: isPopular,
      isFree: isFree,
      isLocked: isLocked ?? this.isLocked,
      lockMessage: lockMessage ?? this.lockMessage,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    price,
    priceFormatted,
    productLimit,
    billingCycle,
    billingCycleCount,
    trialDays,
    features,
    isPopular,
    isFree,
    isLocked,
    lockMessage,
  ];
}
