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
      final response = await _dio.get(
        '/dokan/v1/orders',
        queryParameters: {'status': status, 'per_page': 20},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final orders = data.map((json) => OrderModel.fromJson(json)).toList();
        emit(VendorOrdersLoaded(orders));
      } else {
        emit(const VendorOrdersError('Failed to load orders'));
      }
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
