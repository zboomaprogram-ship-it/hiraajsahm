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
        'per_page': 50,
        'customer': currentUserId,
        'status':
            'any', // CRITICAL: Fetch all statuses (pending, processing, etc.)
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      final response = await _cleanDio.get(
        ordersUrl,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final allOrders = data
            .map((json) => OrderModel.fromJson(json))
            .toList();

        // Separate current and history orders
        final currentStatuses = ['processing', 'on-hold', 'pending'];
        final historyStatuses = [
          'completed',
          'cancelled',
          'refunded',
          'failed',
        ];

        final currentOrders = allOrders
            .where((o) => currentStatuses.contains(o.status))
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
      } else {
        emit(const OrdersError(message: 'فشل في تحميل الطلبات'));
      }
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
}
