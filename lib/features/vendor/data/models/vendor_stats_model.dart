import 'package:equatable/equatable.dart';

/// Vendor Dashboard Stats Model
class VendorStatsModel extends Equatable {
  final double netSales;
  final double grossSales;
  final double earnings;
  final int ordersCount;
  final int productsSold;
  final int totalProducts;
  final double averageOrderValue;
  final int pendingOrders;
  final int processingOrders;
  final int completedOrders;

  const VendorStatsModel({
    required this.netSales,
    required this.grossSales,
    required this.earnings,
    required this.ordersCount,
    required this.productsSold,
    required this.totalProducts,
    required this.averageOrderValue,
    this.pendingOrders = 0,
    this.processingOrders = 0,
    this.completedOrders = 0,
  });

  factory VendorStatsModel.fromJson(Map<String, dynamic> json) {
    // Parse orders count which can be a Map or int
    int orders = 0;
    int pending = 0;
    int processing = 0;
    int completed = 0;

    final ordersData = json['orders_count'];
    if (ordersData is Map) {
      orders = _parseInt(ordersData['total']);
      pending = _parseInt(ordersData['wc-pending'] ?? ordersData['pending']);
      processing = _parseInt(
        ordersData['wc-processing'] ?? ordersData['processing'],
      );
      completed = _parseInt(
        ordersData['wc-completed'] ?? ordersData['completed'],
      );
    } else {
      orders = _parseInt(ordersData);
    }

    // Parse sales (handle 'sales' vs 'gross_sales')
    double grossSales = _parseDouble(json['gross_sales']);
    if (grossSales == 0) grossSales = _parseDouble(json['sales']);

    return VendorStatsModel(
      netSales: _parseDouble(json['net_sales'] ?? grossSales),
      grossSales: grossSales,
      earnings: _parseDouble(json['earnings']),
      ordersCount: orders,
      productsSold: _parseInt(json['products_sold'] ?? json['items_sold']),
      totalProducts: _parseInt(json['total_products']),
      averageOrderValue: _parseDouble(json['average_order_value']),
      pendingOrders: pending,
      processingOrders: processing,
      completedOrders: completed,
    );
  }

  factory VendorStatsModel.empty() {
    return const VendorStatsModel(
      netSales: 0,
      grossSales: 0,
      earnings: 0,
      ordersCount: 0,
      productsSold: 0,
      totalProducts: 0,
      averageOrderValue: 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'net_sales': netSales,
      'gross_sales': grossSales,
      'earnings': earnings,
      'orders_count': ordersCount,
      'products_sold': productsSold,
      'total_products': totalProducts,
      'average_order_value': averageOrderValue,
      'pending_orders': pendingOrders,
      'processing_orders': processingOrders,
      'completed_orders': completedOrders,
    };
  }

  VendorStatsModel copyWith({
    double? netSales,
    double? grossSales,
    double? earnings,
    int? ordersCount,
    int? productsSold,
    int? totalProducts,
    double? averageOrderValue,
    int? pendingOrders,
    int? processingOrders,
    int? completedOrders,
  }) {
    return VendorStatsModel(
      netSales: netSales ?? this.netSales,
      grossSales: grossSales ?? this.grossSales,
      earnings: earnings ?? this.earnings,
      ordersCount: ordersCount ?? this.ordersCount,
      productsSold: productsSold ?? this.productsSold,
      totalProducts: totalProducts ?? this.totalProducts,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      processingOrders: processingOrders ?? this.processingOrders,
      completedOrders: completedOrders ?? this.completedOrders,
    );
  }

  @override
  List<Object?> get props => [
    netSales,
    grossSales,
    earnings,
    ordersCount,
    productsSold,
    totalProducts,
    averageOrderValue,
    pendingOrders,
    processingOrders,
    completedOrders,
  ];
}
