import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../data/models/store_model.dart';
import '../../../shop/data/models/product_model.dart';

// ============ STATES ============

abstract class VendorProfileState extends Equatable {
  const VendorProfileState();

  @override
  List<Object?> get props => [];
}

class VendorProfileInitial extends VendorProfileState {
  const VendorProfileInitial();
}

class VendorProfileLoading extends VendorProfileState {
  const VendorProfileLoading();
}

class VendorProfileLoaded extends VendorProfileState {
  final StoreModel store;
  final List<ProductModel> products;
  final bool hasMoreProducts;

  const VendorProfileLoaded({
    required this.store,
    required this.products,
    this.hasMoreProducts = false,
  });

  @override
  List<Object?> get props => [store, products, hasMoreProducts];

  VendorProfileLoaded copyWith({
    StoreModel? store,
    List<ProductModel>? products,
    bool? hasMoreProducts,
  }) {
    return VendorProfileLoaded(
      store: store ?? this.store,
      products: products ?? this.products,
      hasMoreProducts: hasMoreProducts ?? this.hasMoreProducts,
    );
  }
}

class VendorProfileError extends VendorProfileState {
  final String message;

  const VendorProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class VendorProfileUpdating extends VendorProfileState {
  const VendorProfileUpdating();
}

class VendorProfileUpdateSuccess extends VendorProfileState {
  final String message;
  const VendorProfileUpdateSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

// ============ CUBIT ============

class VendorProfileCubit extends Cubit<VendorProfileState> {
  final Dio _dio;
  int _currentPage = 1;
  static const int _perPage = 20;

  VendorProfileCubit({required Dio dio})
    : _dio = dio,
      super(const VendorProfileInitial());

  /// Load vendor profile with store details and products
  Future<void> loadVendorProfile(int vendorId) async {
    emit(const VendorProfileLoading());
    _currentPage = 1;

    try {
      // Fetch store details and products concurrently
      final results = await Future.wait([
        _fetchStoreDetails(vendorId),
        _fetchVendorProducts(vendorId, page: 1),
      ]);

      final store = results[0] as StoreModel;
      final productsResult = results[1] as _ProductsResult;

      emit(
        VendorProfileLoaded(
          store: store,
          products: productsResult.products,
          hasMoreProducts: productsResult.hasMore,
        ),
      );
    } catch (e) {
      // Clean up error message for user
      String msg = e.toString();
      if (msg.contains("subtype of type")) {
        msg = "بيانات المتجر غير متوفرة حالياً";
      } else {
        msg = msg.replaceAll("Exception:", "").trim();
      }
      emit(VendorProfileError(msg));
    }
  }

  /// Load more products (pagination)
  Future<void> loadMoreProducts(int vendorId) async {
    final currentState = state;
    if (currentState is! VendorProfileLoaded || !currentState.hasMoreProducts) {
      return;
    }

    _currentPage++;

    try {
      final result = await _fetchVendorProducts(vendorId, page: _currentPage);

      emit(
        currentState.copyWith(
          products: [...currentState.products, ...result.products],
          hasMoreProducts: result.hasMore,
        ),
      );
    } catch (e) {
      // Revert page on error
      _currentPage--;
    }
  }

  /// Update Vendor Profile (Store Name, Phone, Address)
  Future<void> updateVendorProfile({
    required int vendorId,
    required String storeName,
    required String phone,
    required String address,
  }) async {
    emit(const VendorProfileUpdating());
    try {
      final response = await _dio.put(
        '${AppConfig.dokanStoreEndpoint}/$vendorId',
        data: {
          'store_name': storeName,
          'phone': phone,
          'address': {'street_1': address},
        },
        // Ensure we send auth token
        options: Options(headers: {'requiresToken': true}),
      );

      if (response.statusCode == 200) {
        emit(const VendorProfileUpdateSuccess('تم تحديث الملف الشخصي بنجاح'));
        // Reload profile to show changes
        loadVendorProfile(vendorId);
      } else {
        emit(const VendorProfileError('فشل تحديث المعلومات'));
      }
    } catch (e) {
      emit(VendorProfileError(e.toString()));
    }
  }

  /// Fetch store details from Dokan API
  Future<StoreModel> _fetchStoreDetails(int vendorId) async {
    final response = await _dio.get(
      '${AppConfig.dokanStoreEndpoint}/$vendorId',
    );

    if (response.statusCode == 200) {
      final data = response.data;

      // 🛑 FIX: Handle case where API returns empty List [] instead of Map {}
      if (data is List) {
        if (data.isEmpty) {
          throw Exception('عذراً، هذا المتجر غير موجود أو تم إيقافه.');
        }
        // If it's a list but not empty, try taking the first item if it's a map
        if (data.first is Map<String, dynamic>) {
          return StoreModel.fromJson(data.first);
        }
      }

      // Normal case: It is a Map
      if (data is Map<String, dynamic>) {
        // 🛡️ Extra Safety: Sanitize fields that might be empty lists []
        // PHP sometimes sends "address": [] instead of "address": {}
        if (data['address'] is List) {
          data['address'] = null; // Set to null to avoid StoreModel crash
        }
        if (data['social'] is List) {
          data['social'] = null;
        }

        return StoreModel.fromJson(data);
      }

      throw Exception('تنسيق بيانات المتجر غير صالح');
    }

    throw Exception('فشل في تحميل بيانات المتجر');
  }

  /// Fetch vendor products from WooCommerce API
  Future<_ProductsResult> _fetchVendorProducts(
    int vendorId, {
    required int page,
  }) async {
    final response = await _dio.get(
      '${AppConfig.dokanStoreEndpoint}/$vendorId/products',
      queryParameters: {
        'per_page': _perPage,
        'page': page,
        'publish': true,
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      },
    );

    if (response.statusCode == 200) {
      // 🛑 FIX: Ensure we actually got a List
      if (response.data is! List) {
        // If we got a Map, it might be an error object or empty result treated weirdly
        return _ProductsResult(products: [], hasMore: false);
      }

      final List<dynamic> data = response.data;
      final products = data.map((json) => ProductModel.fromJson(json)).where((
        product,
      ) {
        // Filter out subscription packs
        final name = product.name.toLowerCase();
        return !name.contains('باقة') &&
            !name.contains('عضوية') &&
            !name.contains('subscription') &&
            !name.contains('membership') &&
            product.id != 29318;
      }).toList();

      final totalPages =
          int.tryParse(response.headers.value('x-wp-totalpages') ?? '1') ?? 1;

      return _ProductsResult(products: products, hasMore: page < totalPages);
    }

    throw Exception('فشل في تحميل منتجات البائع');
  }
}

/// Helper class for products result with pagination info
class _ProductsResult {
  final List<ProductModel> products;
  final bool hasMore;

  _ProductsResult({required this.products, required this.hasMore});
}
