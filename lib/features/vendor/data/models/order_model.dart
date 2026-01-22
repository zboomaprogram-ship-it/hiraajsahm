import 'package:equatable/equatable.dart';

class OrderModel extends Equatable {
  final int id;
  final String status;
  final String total;
  final DateTime dateCreated;
  final String currency;
  final int itemCount;

  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.status,
    required this.total,
    required this.dateCreated,
    this.currency = 'SAR',
    this.itemCount = 0,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final lineItems = json['line_items'] as List? ?? [];
    return OrderModel(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      total: json['total'] as String? ?? '0.00',
      dateCreated:
          DateTime.tryParse(json['date_created'] as String? ?? '') ??
          DateTime.now(),
      currency: json['currency'] as String? ?? 'SAR',
      itemCount: lineItems.length,
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
