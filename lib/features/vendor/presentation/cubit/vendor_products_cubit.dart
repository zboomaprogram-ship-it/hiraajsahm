import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
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
      const perPage = 100;
      var page = 1;
      final products = <ProductModel>[];
      while (true) {
        final response = await _dio.get(
          AppConfig.vendorProductsSecureEndpoint,
          queryParameters: {
            'status': status,
            'per_page': perPage,
            'page': page,
          },
        );
        if (response.statusCode != 200 || response.data is! List) {
          emit(const VendorProductsError('Failed to load products'));
          return;
        }
        final data = response.data as List<dynamic>;
        for (final item in data) {
          try {
            products.add(
              ProductModel.fromJson(Map<String, dynamic>.from(item as Map)),
            );
          } catch (_) {
            // One malformed listing must not hide the rest of the dashboard.
          }
        }
        if (data.length < perPage) break;
        page++;
      }
      emit(VendorProductsLoaded(products));
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

  Future<void> deleteProduct(int productId) async {
    emit(VendorProductsLoading());
    try {
      final response = await _dio.delete(
        '${AppConfig.vendorProductsSecureEndpoint}/$productId',
        queryParameters: {'force': true}, // Force delete from bin as well
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await loadProducts(); // Refresh the list
      } else {
        emit(const VendorProductsError('Failed to delete product'));
      }
    } on DioException catch (e) {
      emit(
        VendorProductsError(
          e.response?.data?['message'] ?? 'Failed to delete product',
        ),
      );
    } catch (e) {
      emit(VendorProductsError(e.toString()));
    }
  }
}
