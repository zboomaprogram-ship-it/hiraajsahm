import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../data/models/order_model.dart';

abstract class VendorOrdersState extends Equatable {
  const VendorOrdersState();
  @override
  List<Object?> get props => [];
}

class VendorOrdersInitial extends VendorOrdersState {}

class VendorOrdersLoading extends VendorOrdersState {}

class VendorOrdersLoaded extends VendorOrdersState {
  final List<OrderModel> orders;
  const VendorOrdersLoaded(this.orders);
  @override
  List<Object?> get props => [orders];
}

class VendorOrdersError extends VendorOrdersState {
  final String message;
  const VendorOrdersError(this.message);
  @override
  List<Object?> get props => [message];
}

class VendorOrdersCubit extends Cubit<VendorOrdersState> {
  final Dio _dio;

  VendorOrdersCubit({required Dio dio})
    : _dio = dio,
      super(VendorOrdersInitial());

  Future<void> loadOrders({String status = 'any'}) async {
    emit(VendorOrdersLoading());
    try {
      const perPage = 100;
      var page = 1;
      final orders = <OrderModel>[];
      while (true) {
        final response = await _dio.get(
          '/dokan/v1/orders',
          queryParameters: {
            'status': status,
            'per_page': perPage,
            'page': page,
          },
        );
        if (response.statusCode != 200 || response.data is! List) {
          emit(const VendorOrdersError('Failed to load orders'));
          return;
        }
        final data = response.data as List<dynamic>;
        for (final item in data) {
          try {
            orders.add(
              OrderModel.fromJson(Map<String, dynamic>.from(item as Map)),
            );
          } catch (_) {
            // Keep valid marketplace orders visible if one record is malformed.
          }
        }
        if (data.length < perPage) break;
        page++;
      }
      emit(VendorOrdersLoaded(orders));
    } on DioException catch (e) {
      emit(
        VendorOrdersError(
          e.response?.data?['message'] ?? 'Failed to load orders',
        ),
      );
    } catch (e) {
      emit(VendorOrdersError(e.toString()));
    }
  }
}
