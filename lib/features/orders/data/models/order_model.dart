import 'package:equatable/equatable.dart';

/// Order Model for WooCommerce orders
class OrderModel extends Equatable {
  final int id;
  final String status;
  final String dateCreated;
  final String total;
  final String currency;
  final String paymentMethod;
  final String paymentMethodTitle;
  final BillingAddress billing;
  final ShippingAddress shipping;
  final List<LineItem> lineItems;
  final String? customerNote;

  const OrderModel({
    required this.id,
    required this.status,
    required this.dateCreated,
    required this.total,
    required this.currency,
    required this.paymentMethod,
    required this.paymentMethodTitle,
    required this.billing,
    required this.shipping,
    required this.lineItems,
    this.customerNote,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'pending',
      dateCreated: json['date_created'] ?? '',
      total: json['total'] ?? '0',
      currency: json['currency'] ?? 'SAR',
      paymentMethod: json['payment_method'] ?? '',
      paymentMethodTitle: json['payment_method_title'] ?? '',
      billing: BillingAddress.fromJson(json['billing'] ?? {}),
      shipping: ShippingAddress.fromJson(json['shipping'] ?? {}),
      lineItems:
          (json['line_items'] as List<dynamic>?)
              ?.map((item) => LineItem.fromJson(item))
              .toList() ??
          [],
      customerNote: json['customer_note'],
    );
  }

  /// Get localized status text
  String get statusText {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'processing':
        return 'جاري التجهيز';
      case 'on-hold':
        return 'معلق';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'refunded':
        return 'مسترد';
      case 'failed':
        return 'فشل';
      default:
        return status;
    }
  }

  /// Get formatted date
  String get formattedDate {
    try {
      final date = DateTime.parse(dateCreated);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateCreated;
    }
  }

  @override
  List<Object?> get props => [id, status, dateCreated, total];
}

class BillingAddress extends Equatable {
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String city;
  final String address1;

  const BillingAddress({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.city,
    required this.address1,
  });

  factory BillingAddress.fromJson(Map<String, dynamic> json) {
    return BillingAddress(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      city: json['city'] ?? '',
      address1: json['address_1'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get fullAddress => '$address1, $city'.trim();

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    phone,
    email,
    city,
    address1,
  ];
}

class ShippingAddress extends Equatable {
  final String firstName;
  final String lastName;
  final String city;
  final String address1;

  const ShippingAddress({
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.address1,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      city: json['city'] ?? '',
      address1: json['address_1'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get fullAddress => '$address1, $city'.trim();

  @override
  List<Object?> get props => [firstName, lastName, city, address1];
}

class LineItem extends Equatable {
  final int id;
  final String name;
  final int productId;
  final int quantity;
  final String total;
  final String price;
  final String? imageUrl;

  const LineItem({
    required this.id,
    required this.name,
    required this.productId,
    required this.quantity,
    required this.total,
    required this.price,
    this.imageUrl,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    if (json['image'] != null && json['image'] is Map) {
      imageUrl = json['image']['src'];
    }

    return LineItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      productId: json['product_id'] ?? 0,
      quantity: json['quantity'] ?? 1,
      total: json['total'] ?? '0',
      price: json['price']?.toString() ?? '0',
      imageUrl: imageUrl,
    );
  }

  @override
  List<Object?> get props => [id, name, productId, quantity, total];
}
