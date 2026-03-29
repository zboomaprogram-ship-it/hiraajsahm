import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../shop/data/models/product_model.dart';

// ============ HOME CONTENT STATES ============
abstract class HomeContentState extends Equatable {
  const HomeContentState();

  @override
  List<Object?> get props => [];
}

class HomeContentInitial extends HomeContentState {
  const HomeContentInitial();
}

class HomeContentLoading extends HomeContentState {
  const HomeContentLoading();
}

class HomeContentLoaded extends HomeContentState {
  final List<ProductModel> latestProducts;
  final List<ProductModel> featuredProducts;

  const HomeContentLoaded({
    required this.latestProducts,
    this.featuredProducts = const [],
  });

  @override
  List<Object?> get props => [latestProducts, featuredProducts];
}

class HomeContentError extends HomeContentState {
  final String message;

  const HomeContentError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ============ HOME CONTENT CUBIT ============
/// Manages home screen content independently from Shop filtering
class HomeContentCubit extends Cubit<HomeContentState> {
  // Clean Dio instance for direct API calls
  final Dio _cleanDio;

  HomeContentCubit()
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
      super(const HomeContentInitial());

  int? _currentCategoryId;
  String? _currentRegion;

  // Cache WC categories to avoid massive sequential recursion
  List<dynamic>? _cachedWcCategories;

  /// Get active region
  String? get activeRegion => _currentRegion;

  /// Get active category
  int? get activeCategory => _currentCategoryId;

  /// Load home content - latest products and featured items (with optional filters)
  Future<void> loadHomeContent({int? categoryId, String? region}) async {
    // If not matching current filters, ignore "already loading" state
    final isNewFilters =
        categoryId != _currentCategoryId || region != _currentRegion;
    if (state is HomeContentLoading && !isNewFilters) return;

    _currentCategoryId = categoryId;
    _currentRegion = region;

    emit(const HomeContentLoading());

    try {
      String productsUrl = 'https://hiraajsahm.com/wp-json/wc/v3/products';
      const alZabayehProductId = 29318;
      const excludeCategoryId = 122; // Packages

      // If a category is selected, fetch ALL descendant subcategory IDs from WC API
      String? categoryFilter;
      if (categoryId != null) {
        final subIds = await _fetchAllDescendantIds(categoryId);
        final allIds = [categoryId, ...subIds];
        categoryFilter = allIds.join(',');
      }

      // To avoid Dio encoding commas as '%2C' which WC API ignores,
      // we append it directly to the URL.
      if (categoryFilter != null) {
        productsUrl = '$productsUrl?category=$categoryFilter';
      }

      // Build Query Parameters
      final latestParams = <String, dynamic>{
        'per_page': region != null || categoryId != null ? 50 : 10,
        'orderby': 'date',
        'order': 'desc',
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      final featuredParams = <String, dynamic>{
        'per_page': region != null || categoryId != null ? 20 : 5,
        'featured': true,
        'consumer_key': AppConfig.wcConsumerKey,
        'consumer_secret': AppConfig.wcConsumerSecret,
      };

      // Prepare both requests
      final latestRequest = _cleanDio.get(
        productsUrl,
        queryParameters: latestParams,
      );
      final featuredRequest = _cleanDio.get(
        productsUrl,
        queryParameters: featuredParams,
      );

      // Execute in parallel
      final responses = await Future.wait([
        latestRequest,
        featuredRequest.catchError(
          (e) => Response(
            requestOptions: RequestOptions(path: productsUrl),
            statusCode: 500, // Dummy error status
          ),
        ),
      ]);

      final latestResponse = responses[0];
      final featuredResponse = responses[1];

      if (latestResponse.statusCode == 200) {
        final List<dynamic> data = latestResponse.data;
        var latestProducts = data
            .map((json) => ProductModel.fromJson(json))
            .where((product) => product.status == 'publish')
            .where((product) => product.id != alZabayehProductId)
            .where((p) => !p.categories.any((c) => c.id == excludeCategoryId))
            .toList();

        List<ProductModel> featuredProducts = [];
        if (featuredResponse.statusCode == 200 &&
            featuredResponse.data is List) {
          final List<dynamic> featuredData = featuredResponse.data;
          featuredProducts = featuredData
              .map((json) => ProductModel.fromJson(json))
              .where((product) => product.status == 'publish')
              .where((product) => product.id != alZabayehProductId)
              .where((p) => !p.categories.any((c) => c.id == excludeCategoryId))
              .toList();
        }

        // Apply Region Filter client-side
        if (region != null && region.isNotEmpty && region != 'الكل') {
          latestProducts = latestProducts.where((p) {
            final loc = p.productLocation?.toLowerCase() ?? '';
            final vendorLoc = p.vendorAddress?.toLowerCase() ?? '';
            return loc.contains(region) || vendorLoc.contains(region);
          }).toList();

          featuredProducts = featuredProducts.where((p) {
            final loc = p.productLocation?.toLowerCase() ?? '';
            final vendorLoc = p.vendorAddress?.toLowerCase() ?? '';
            return loc.contains(region) || vendorLoc.contains(region);
          }).toList();
        }

        // Limit results for UI after filtering
        if (latestProducts.length > 20)
          latestProducts = latestProducts.sublist(0, 20);
        if (featuredProducts.length > 10)
          featuredProducts = featuredProducts.sublist(0, 10);

        emit(
          HomeContentLoaded(
            latestProducts: latestProducts,
            featuredProducts: featuredProducts,
          ),
        );
      } else {
        emit(const HomeContentError(message: 'فشل في تحميل المحتوى'));
      }
    } on DioException catch (e) {
      String errorMessage = 'خطأ في الاتصال بالخادم';
      if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }
      emit(HomeContentError(message: errorMessage));
    } catch (e) {
      emit(HomeContentError(message: e.toString()));
    }
  }

  /// Fetch ALL descendant subcategory IDs from the WC categories API
  Future<List<int>> _fetchAllDescendantIds(int parentId) async {
    try {
      if (_cachedWcCategories == null) {
        const url = 'https://hiraajsahm.com/wp-json/wc/v3/products/categories';
        final response = await _cleanDio.get(
          url,
          queryParameters: {
            'per_page': 100,
            'consumer_key': AppConfig.wcConsumerKey,
            'consumer_secret': AppConfig.wcConsumerSecret,
          },
        );
        if (response.statusCode == 200 && response.data is List) {
          _cachedWcCategories = response.data as List;
        } else {
          return [];
        }
      }

      final List<int> ids = [];
      // Find direct children
      final children = _cachedWcCategories!.where(
        (cat) => cat['parent'] == parentId,
      );
      for (final cat in children) {
        final id = cat['id'] as int;
        ids.add(id);
        // Recursively find sub-children
        ids.addAll(await _fetchAllDescendantIds(id));
      }
      return ids;
    } catch (_) {}
    return [];
  }

  /// Refresh home content with existing filters
  Future<void> refresh() async {
    emit(const HomeContentInitial());
    await loadHomeContent(
      categoryId: _currentCategoryId,
      region: _currentRegion,
    );
  }
}
