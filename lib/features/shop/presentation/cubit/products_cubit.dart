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
  final String? region;
  final String? city;

  const ProductsLoaded({
    required this.products,
    this.page = 1,
    this.hasReachedMax = false,
    this.categoryId,
    this.search,
    this.region,
    this.city,
  });
  ProductsLoaded copyWith({
    List<ProductModel>? products,
    int? page,
    bool? hasReachedMax,
    int? categoryId,
    String? search,
    String? region,
    String? city,
  }) {
    return ProductsLoaded(
      products: products ?? this.products,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      categoryId: categoryId ?? this.categoryId,
      search: search ?? this.search,
      region: region ?? this.region,
      city: city ?? this.city,
    );
  }

  @override
  List<Object?> get props => [
    products,
    page,
    hasReachedMax,
    categoryId,
    search,
    region,
    city,
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

  // Cache of resolved category filter strings
  String? _resolvedCategoryFilter;
  
  // Cache WC categories to avoid massive sequential recursion
  List<dynamic>? _cachedWcCategories;

  /// Load products with optional filters
  Future<void> loadProducts({
    int? categoryId,
    String? search,
    String? region,
    String? city,
    bool refresh = false,
  }) async {
    if (state is ProductsLoading && !refresh) return;

    emit(const ProductsLoading());

    try {
      // Build query parameters
      final queryParams = <String, dynamic>{
        'per_page': _perPage,
        'page': 1,
        'status': 'any', // Use any and then filter locally to avoid API error
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      // Use base URL
      String fullUrl = 'https://hiraajsahm.com/wp-json/wc/v3/products';

      if (categoryId != null) {
        // Fetch ALL descendant subcategory IDs for this category
        final subIds = await _fetchAllDescendantIds(categoryId);
        final allIds = [categoryId, ...subIds];
        _resolvedCategoryFilter = allIds.join(',');
        
        // Append directly to URL to avoid Dio translating ',' to '%2C'
        fullUrl = '$fullUrl?category=$_resolvedCategoryFilter';
      } else {
        _resolvedCategoryFilter = null;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

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
        var products = data
            .map((json) => ProductModel.fromJson(json))
            .where((product) => product.status == 'publish' || product.status == 'pending')
            .where(
              (product) =>
                  !product.categories.any((c) => c.id == _excludeCategoryId),
            )
            .where((product) => product.id != alZabayehProductId)
            .toList();

        // Apply Region & City Filter client-side
        final hasRegion = region != null && region.isNotEmpty && region != 'الكل';
        final hasCity = city != null && city.isNotEmpty && city != 'الكل';

        if (hasRegion || hasCity) {
          products = products.where((p) {
            bool matches = true;
            if (hasRegion) {
              final loc = p.productLocation?.toLowerCase() ?? '';
              final reg = p.productRegion?.toLowerCase() ?? '';
              final cityVal = p.productCity?.toLowerCase() ?? '';
              final vendorLoc = p.vendorAddress?.toLowerCase() ?? '';
              matches = matches && (loc.contains(region.toLowerCase()) || reg.contains(region.toLowerCase()) || cityVal.contains(region.toLowerCase()) || vendorLoc.contains(region.toLowerCase()));
            }
            if (hasCity) {
              final loc = p.productLocation?.toLowerCase() ?? '';
              final reg = p.productRegion?.toLowerCase() ?? '';
              final cityVal = p.productCity?.toLowerCase() ?? '';
              matches = matches && (loc.contains(city.toLowerCase()) || reg.contains(city.toLowerCase()) || cityVal.contains(city.toLowerCase()));
            }
            return matches;
          }).toList();
        }

        emit(
          ProductsLoaded(
            products: products,
            page: 1,
            hasReachedMax: data.length < _perPage,
            categoryId: categoryId,
            search: search,
            region: region,
            city: city,
          ),
        );
      } else {
        emit(const ProductsError(message: 'فشل في تحميل الاعلانات'));
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
        'status': 'any', // Use any and then filter locally to avoid API error
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      String fullUrl = 'https://hiraajsahm.com/wp-json/wc/v3/products';

      if (currentState.categoryId != null && _resolvedCategoryFilter != null) {
        fullUrl = '$fullUrl?category=$_resolvedCategoryFilter';
      }

      if (currentState.search != null && currentState.search!.isNotEmpty) {
        queryParams['search'] = currentState.search;
      }

      final response = await _cleanDio.get(
        fullUrl,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Also filter 29318 from pagination results
        const alZabayehProductId = 29318;
        var newProducts = data
            .map((json) => ProductModel.fromJson(json))
            .where((product) => product.status == 'publish' || product.status == 'pending')
            .where(
              (product) =>
                  !product.categories.any((c) => c.id == _excludeCategoryId),
            )
            .where((product) => product.id != alZabayehProductId)
            .toList();
            
        // Apply Region & City Filter client-side
        final hasRegion = currentState.region != null && currentState.region!.isNotEmpty && currentState.region != 'الكل';
        final hasCity = currentState.city != null && currentState.city!.isNotEmpty && currentState.city != 'الكل';

        if (hasRegion || hasCity) {
          final region = currentState.region;
          final city = currentState.city;
          newProducts = newProducts.where((p) {
            bool matches = true;
            if (hasRegion) {
              final loc = p.productLocation?.toLowerCase() ?? '';
              final reg = p.productRegion?.toLowerCase() ?? '';
              final cityVal = p.productCity?.toLowerCase() ?? '';
              final vendorLoc = p.vendorAddress?.toLowerCase() ?? '';
              matches = matches && (loc.contains(region!.toLowerCase()) || reg.contains(region.toLowerCase()) || cityVal.contains(region.toLowerCase()) || vendorLoc.contains(region.toLowerCase()));
            }
            if (hasCity) {
              final loc = p.productLocation?.toLowerCase() ?? '';
              final reg = p.productRegion?.toLowerCase() ?? '';
              final cityVal = p.productCity?.toLowerCase() ?? '';
              matches = matches && (loc.contains(city!.toLowerCase()) || reg.contains(city.toLowerCase()) || cityVal.contains(city.toLowerCase()));
            }
            return matches;
          }).toList();
        }

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
    final state = this.state;
    String? region;
    String? city;
    if (state is ProductsLoaded) {
      region = state.region;
      city = state.city;
    }
    await loadProducts(search: query, region: region, city: city);
  }

  /// Filter by category
  Future<void> filterByCategory(int categoryId) async {
    final state = this.state;
    String? search;
    String? region;
    String? city;
    if (state is ProductsLoaded) {
      search = state.search;
      region = state.region;
      city = state.city;
    }
    await loadProducts(categoryId: categoryId, search: search, region: region, city: city);
  }

  /// Filter by region
  Future<void> filterByRegion(String region) async {
    final state = this.state;
    int? categoryId;
    String? search;
    String? city;
    if (state is ProductsLoaded) {
      categoryId = state.categoryId;
      search = state.search;
      city = state.city;
    }
    await loadProducts(categoryId: categoryId, search: search, region: region, city: city);
  }

  /// Filter by city
  Future<void> filterByCity(String city) async {
    final state = this.state;
    int? categoryId;
    String? search;
    String? region;
    if (state is ProductsLoaded) {
      categoryId = state.categoryId;
      search = state.search;
      region = state.region;
    }
    await loadProducts(categoryId: categoryId, search: search, region: region, city: city);
  }

  /// Get a single product by ID (for deep linking)
  Future<ProductModel?> getProductById(int productId) async {
    try {
      final queryParams = <String, dynamic>{
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      final response = await _cleanDio.get(
        'https://hiraajsahm.com/wp-json/wc/v3/products/$productId',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return ProductModel.fromJson(response.data);
      }
    } catch (e) {
      print('❌ Error fetching product by ID: $e');
    }
    return null;
  }

  /// Clear filters
  Future<void> clearFilters() async {
    await loadProducts();
  }

  /// Fetch ALL descendant subcategory IDs from the WC categories API
  Future<List<int>> _fetchAllDescendantIds(int parentId) async {
    try {
      if (_cachedWcCategories == null) {
        const url = 'https://hiraajsahm.com/wp-json/wc/v3/products/categories';
        final response = await _cleanDio.get(url, queryParameters: {
          'per_page': 100,
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        });
        if (response.statusCode == 200 && response.data is List) {
          _cachedWcCategories = response.data as List;
        } else {
          return [];
        }
      }

      final List<int> ids = [];
      final children = _cachedWcCategories!.where((cat) => cat['parent'] == parentId);
      for (final cat in children) {
        final id = cat['id'] as int;
        ids.add(id);
        ids.addAll(await _fetchAllDescendantIds(id));
      }
      return ids;
    } catch (_) {}
    return [];
  }
}
