import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/order_model.dart';

// ============ ORDERS STATES ============
abstract class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object?> get props => [];
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  final List<OrderModel> currentOrders; // processing, on-hold, pending
  final List<OrderModel> historyOrders; // completed, cancelled, refunded

  const OrdersLoaded({
    required this.currentOrders,
    required this.historyOrders,
  });

  @override
  List<Object?> get props => [currentOrders, historyOrders];
}

class OrdersError extends OrdersState {
  final String message;

  const OrdersError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ============ ORDERS CUBIT ============
class OrdersCubit extends Cubit<OrdersState> {
  final Dio _cleanDio;
  final StorageService _storageService;

  OrdersCubit()
    : _cleanDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ),
      _storageService = sl<StorageService>(),
      super(const OrdersInitial());

  /// Load orders for the current logged-in user only
  Future<void> loadOrders() async {
    if (state is OrdersLoading) return;

    emit(const OrdersLoading());

    try {
      // CRITICAL FIX: Get the current user's ID from storage
      final currentUserId = await _storageService.getUserId();

      if (currentUserId == null || currentUserId == 0) {
        emit(const OrdersError(message: 'يجب تسجيل الدخول لعرض الطلبات'));
        return;
      }

      const ordersUrl = 'https://hiraajsahm.com/wp-json/wc/v3/orders';

      final queryParams = <String, dynamic>{
        'per_page': 100,
        'customer': currentUserId,
        'status':
            'any', // CRITICAL: Fetch all statuses (pending, processing, etc.)
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      final allOrders = <OrderModel>[];
      var page = 1;
      while (true) {
        queryParams['page'] = page;
        final response = await _cleanDio.get(
          ordersUrl,
          queryParameters: queryParams,
        );
        if (response.statusCode != 200 || response.data is! List) {
          emit(const OrdersError(message: 'فشل في تحميل الطلبات'));
          return;
        }
        final data = response.data as List<dynamic>;
        for (final item in data) {
          try {
            final order = OrderModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
            if (order.customerId == currentUserId) {
              allOrders.add(order);
            }
          } catch (_) {
            // Keep other valid orders visible.
          }
        }
        if (data.length < 100) break;
        page++;
      }

      // Treat every non-terminal/custom status as current so plugin-defined
      // WooCommerce statuses cannot silently disappear.
      final historyStatuses = [
        'completed',
        'cancelled',
        'refunded',
        'failed',
        'trash',
      ];

      final currentOrders = allOrders
          .where((o) => !historyStatuses.contains(o.status))
          .toList();
      final historyOrders = allOrders
          .where((o) => historyStatuses.contains(o.status))
          .toList();

      emit(
        OrdersLoaded(
          currentOrders: currentOrders,
          historyOrders: historyOrders,
        ),
      );
    } on DioException catch (e) {
      String errorMessage = 'خطأ في الاتصال بالخادم';

      if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }

      emit(OrdersError(message: errorMessage));
    } catch (e) {
      emit(OrdersError(message: e.toString()));
    }
  }

  /// Refresh orders
  Future<void> refresh() async {
    emit(const OrdersInitial());
    await loadOrders();
  }

  /// Fetch a single order by ID (for details screen refresh)
  Future<OrderModel?> fetchOrder(int orderId) async {
    try {
      // We can iterate the current state to see if we have it, but for refresh we want network.
      final currentUserId = await _storageService.getUserId();
      if (currentUserId == null) return null;

      final response = await _cleanDio.get(
        'https://hiraajsahm.com/wp-json/wc/v3/orders/$orderId',
        queryParameters: {
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );

      if (response.statusCode == 200) {
        final order = OrderModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        if (order.customerId != currentUserId) {
          return null;
        }
        // Optionally update the list state if we want to reflect changes in the list view too
        // But that requires finding and replacing in the list which is immutable.
        // For now, just return the fresh order.
        return order;
      }
    } catch (e) {
      print('Error fetching order $orderId: $e');
    }
    return null;
  }
}
