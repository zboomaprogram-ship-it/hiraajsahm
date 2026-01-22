import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../features/shop/data/models/product_model.dart';

abstract class VendorProductsState extends Equatable {
  const VendorProductsState();
  @override
  List<Object?> get props => [];
}

class VendorProductsInitial extends VendorProductsState {}

class VendorProductsLoading extends VendorProductsState {}

class VendorProductsLoaded extends VendorProductsState {
  final List<ProductModel> products;
  const VendorProductsLoaded(this.products);
  @override
  List<Object?> get props => [products];
}

class VendorProductsError extends VendorProductsState {
  final String message;
  const VendorProductsError(this.message);
  @override
  List<Object?> get props => [message];
}

class VendorProductsCubit extends Cubit<VendorProductsState> {
  final Dio _dio;

  VendorProductsCubit({required Dio dio})
    : _dio = dio,
      super(VendorProductsInitial());

  Future<void> loadProducts({String status = 'any'}) async {
    emit(VendorProductsLoading());
    try {
      final response = await _dio.get(
        '/dokan/v1/products',
        queryParameters: {'status': status, 'per_page': 20},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final products = data
            .map((json) => ProductModel.fromJson(json))
            .toList();
        emit(VendorProductsLoaded(products));
      } else {
        emit(const VendorProductsError('Failed to load products'));
      }
    } on DioException catch (e) {
      emit(
        VendorProductsError(
          e.response?.data?['message'] ?? 'Failed to load products',
        ),
      );
    } catch (e) {
      emit(VendorProductsError(e.toString()));
    }
  }
}
