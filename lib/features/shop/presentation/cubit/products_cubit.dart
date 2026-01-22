import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../data/models/product_model.dart';

// ============ PRODUCTS STATES ============
abstract class ProductsState extends Equatable {
  const ProductsState();

  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {
  const ProductsInitial();
}

class ProductsLoading extends ProductsState {
  const ProductsLoading();
}

class ProductsLoaded extends ProductsState {
  final List<ProductModel> products;
  final int page;
  final bool hasReachedMax;
  final int? categoryId;
  final String? search;

  const ProductsLoaded({
    required this.products,
    this.page = 1,
    this.hasReachedMax = false,
    this.categoryId,
    this.search,
  });

  ProductsLoaded copyWith({
    List<ProductModel>? products,
    int? page,
    bool? hasReachedMax,
    int? categoryId,
    String? search,
  }) {
    return ProductsLoaded(
      products: products ?? this.products,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      categoryId: categoryId ?? this.categoryId,
      search: search ?? this.search,
    );
  }

  @override
  List<Object?> get props => [
    products,
    page,
    hasReachedMax,
    categoryId,
    search,
  ];
}

class ProductsError extends ProductsState {
  final String message;

  const ProductsError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ============ PRODUCTS CUBIT ============
class ProductsCubit extends Cubit<ProductsState> {
  static const int _perPage = 20;

  // Category ID to exclude (subscription packs)
  static const int _excludeCategoryId = 122;

  // Create a separate Dio instance without baseUrl for direct API calls
  late final Dio _cleanDio;

  ProductsCubit({required Dio dio})
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
      super(const ProductsInitial());

  /// Load products with optional filters
  Future<void> loadProducts({
    int? categoryId,
    String? search,
    bool refresh = false,
  }) async {
    if (state is ProductsLoading) return;

    emit(const ProductsLoading());

    try {
      // Build query parameters
      final queryParams = <String, dynamic>{
        'per_page': _perPage,
        'page': 1,
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      if (categoryId != null) {
        queryParams['category'] = categoryId;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // Use direct URL to avoid baseUrl issues
      const fullUrl = 'https://hiraajsahm.com/wp-json/wc/v3/products';

      final response = await _cleanDio.get(
        fullUrl,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;

        // Filter only published products and exclude:
        // 1. Subscription packs (Category 122)
        // 2. Al-Zabayeh activation fee (Product ID 29318)
        const alZabayehProductId = 29318;
        final products = data
            .map((json) => ProductModel.fromJson(json))
            .where((product) => product.status == 'publish')
            .where(
              (product) =>
                  !product.categories.any((c) => c.id == _excludeCategoryId),
            )
            .where((product) => product.id != alZabayehProductId)
            .toList();

        emit(
          ProductsLoaded(
            products: products,
            page: 1,
            hasReachedMax: data.length < _perPage,
            categoryId: categoryId,
            search: search,
          ),
        );
      } else {
        emit(const ProductsError(message: 'فشل في تحميل المنتجات'));
      }
    } on DioException catch (e) {
      String errorMessage = 'خطأ في الاتصال بالخادم';

      if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }

      emit(ProductsError(message: errorMessage));
    } catch (e) {
      emit(ProductsError(message: e.toString()));
    }
  }

  /// Load more products (pagination)
  Future<void> loadMoreProducts() async {
    if (state is! ProductsLoaded) return;

    final currentState = state as ProductsLoaded;
    if (currentState.hasReachedMax) return;

    try {
      final queryParams = <String, dynamic>{
        'per_page': _perPage,
        'page': currentState.page + 1,
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      if (currentState.categoryId != null) {
        queryParams['category'] = currentState.categoryId;
      }

      if (currentState.search != null && currentState.search!.isNotEmpty) {
        queryParams['search'] = currentState.search;
      }

      const fullUrl = 'https://hiraajsahm.com/wp-json/wc/v3/products';

      final response = await _cleanDio.get(
        fullUrl,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Also filter 29318 from pagination results
        const alZabayehProductId = 29318;
        final newProducts = data
            .map((json) => ProductModel.fromJson(json))
            .where((product) => product.status == 'publish')
            .where(
              (product) =>
                  !product.categories.any((c) => c.id == _excludeCategoryId),
            )
            .where((product) => product.id != alZabayehProductId)
            .toList();

        emit(
          currentState.copyWith(
            products: [...currentState.products, ...newProducts],
            page: currentState.page + 1,
            hasReachedMax: data.length < _perPage,
          ),
        );
      }
    } catch (e) {
      // Silently fail for pagination errors
    }
  }

  /// Search products
  Future<void> searchProducts(String query) async {
    await loadProducts(search: query);
  }

  /// Filter by category
  Future<void> filterByCategory(int categoryId) async {
    await loadProducts(categoryId: categoryId);
  }

  /// Clear filters
  Future<void> clearFilters() async {
    await loadProducts();
  }
}
