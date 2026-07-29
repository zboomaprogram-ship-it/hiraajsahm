import 'package:equatable/equatable.dart';

class OrderModel extends Equatable {
  final int id;
  final String status;
  final String total;
  final DateTime dateCreated;
  final String currency;
  final int itemCount;
  final String paymentMethod;
  final String paymentMethodTitle;
  final int customerId;
  final String buyerName;
  final String buyerPhone;
  final String buyerEmail;
  final String buyerAddress;

  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.status,
    required this.total,
    required this.dateCreated,
    this.currency = 'SAR',
    this.itemCount = 0,
    this.paymentMethod = '',
    this.paymentMethodTitle = '',
    this.customerId = 0,
    this.buyerName = '',
    this.buyerPhone = '',
    this.buyerEmail = '',
    this.buyerAddress = '',
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final lineItems = json['line_items'] as List? ?? [];
    final billing = json['billing'] is Map
        ? Map<String, dynamic>.from(json['billing'] as Map)
        : <String, dynamic>{};
    final shipping = json['shipping'] is Map
        ? Map<String, dynamic>.from(json['shipping'] as Map)
        : <String, dynamic>{};
    final meta = json['meta_data'] is List
        ? List<dynamic>.from(json['meta_data'] as List)
        : const <dynamic>[];

    String metaValue(String key) {
      for (final item in meta) {
        if (item is Map && item['key']?.toString() == key) {
          return item['value']?.toString().trim() ?? '';
        }
      }
      return '';
    }

    String firstValue(Iterable<dynamic> values) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final firstName = firstValue([
      billing['first_name'],
      shipping['first_name'],
      json['customer'] is Map ? json['customer']['first_name'] : null,
    ]);
    final lastName = firstValue([
      billing['last_name'],
      shipping['last_name'],
      json['customer'] is Map ? json['customer']['last_name'] : null,
    ]);
    final address = [
      firstValue([billing['address_1'], shipping['address_1']]),
      firstValue([billing['city'], shipping['city']]),
    ].where((value) => value.isNotEmpty).join('، ');

    return OrderModel(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      total: json['total'] as String? ?? '0.00',
      dateCreated:
          DateTime.tryParse(json['date_created'] as String? ?? '') ??
          DateTime.now(),
      currency: json['currency'] as String? ?? 'SAR',
      itemCount: lineItems.length,
      paymentMethod: json['payment_method']?.toString() ?? '',
      paymentMethodTitle: json['payment_method_title']?.toString() ?? '',
      customerId: int.tryParse(json['customer_id']?.toString() ?? '') ?? 0,
      buyerName: '$firstName $lastName'.trim(),
      buyerPhone: firstValue([
        billing['phone'],
        shipping['phone'],
        json['billing_phone'],
        json['phone'],
        json['customer'] is Map ? json['customer']['phone'] : null,
        metaValue('_billing_phone'),
        metaValue('billing_phone'),
      ]),
      buyerEmail: firstValue([
        billing['email'],
        json['customer'] is Map ? json['customer']['email'] : null,
      ]),
      buyerAddress: address,
      items: lineItems.map((e) => OrderItemModel.fromJson(e)).toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    total,
    dateCreated,
    currency,
    itemCount,
    paymentMethod,
    paymentMethodTitle,
    customerId,
    buyerName,
    buyerPhone,
    buyerEmail,
    buyerAddress,
    items,
  ];
}

class OrderItemModel extends Equatable {
  final int id;
  final String name;
  final int quantity;
  final String total;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.total,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      total: json['total'] as String? ?? '0.00',
    );
  }

  @override
  List<Object?> get props => [id, name, quantity, total];
}
