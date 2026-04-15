import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../../../../core/config/app_config.dart';
import '../../data/models/store_model.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../shop/data/models/review_model.dart';

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
  final List<ReviewModel> reviews;
  final bool hasMoreProducts;

  const VendorProfileLoaded({
    required this.store,
    required this.products,
    required this.reviews,
    this.hasMoreProducts = false,
  });

  @override
  List<Object?> get props => [store, products, reviews, hasMoreProducts];

  VendorProfileLoaded copyWith({
    StoreModel? store,
    List<ProductModel>? products,
    List<ReviewModel>? reviews,
    bool? hasMoreProducts,
  }) {
    return VendorProfileLoaded(
      store: store ?? this.store,
      products: products ?? this.products,
      reviews: reviews ?? this.reviews,
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
  Future<void> loadVendorProfile(
    int vendorId, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      emit(const VendorProfileLoading());
    }
    _currentPage = 1;

    try {
      // Fetch store details, products, and reviews concurrently
      final results = await Future.wait([
        _fetchStoreDetails(vendorId),
        _fetchVendorProducts(vendorId, page: 1),
        _fetchStoreReviews(vendorId),
      ]);

      final store = results[0] as StoreModel;
      final productsResult = results[1] as _ProductsResult;
      final reviews = results[2] as List<ReviewModel>;

      if (isClosed) return;
      emit(
        VendorProfileLoaded(
          store: store,
          products: productsResult.products,
          reviews: reviews,
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
      if (isClosed) return;
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

      if (isClosed) return;
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

  /// Update Vendor Profile (Store Name, Phone, Address, Social, etc.)
  Future<void> updateVendorProfile({
    required int vendorId,
    required String storeName,
    required String phone,
    required String street,
    String? city,
    String? state,
    String? biography,
    String? location,
    String? facebook,
    String? instagram,
    String? twitter,
    String? youtube,
    int? gravatarId,
    // Store Banner ID for update
    int? bannerId,
  }) async {
    emit(const VendorProfileUpdating());
    try {
      final response = await _dio.put(
        '${AppConfig.dokanStoreEndpoint}/$vendorId',
        data: {
          'store_name': storeName,
          'phone': phone,
          'address': {
            'street_1': street,
            if (state != null) 'city': state,
            if (city != null) 'state': city,
          },
          if (biography != null) 'vendor_biography': biography,
          if (location != null) 'location': location,
          'social': {
            if (facebook != null) 'fb': facebook,
            if (instagram != null) 'instagram': instagram,
            if (twitter != null) 'twitter': twitter,
            if (youtube != null) 'youtube': youtube,
          },
          if (gravatarId != null) 'gravatar_id': gravatarId,
          if (bannerId != null) 'banner_id': bannerId,
        },
        // Ensure we send auth token
        options: Options(headers: {'requiresToken': true}),
      );

      if (isClosed) return;
      if (response.statusCode == 200) {
        // Sync standalone meta keys to WooCommerce specifically for custom WordPress plugins
        try {
          final cleanDio = Dio(
            BaseOptions(
              baseUrl: AppConfig.baseUrl,
              headers: {
                'Authorization': 'Basic ${base64Encode(utf8.encode('${AppConfig.wcConsumerKey}:${AppConfig.wcConsumerSecret}'))}',
                'Content-Type': 'application/json',
              },
            ),
          );
          await cleanDio.put(
            '${AppConfig.wcCustomersEndpoint}/$vendorId',
            data: {
              'meta_data': [
                if (state != null) {'key': 'city', 'value': state},
                if (city != null) {'key': 'region', 'value': city},
                if (location != null) {'key': 'location', 'value': location},
              ]
            },
          );
        } catch (e) {
          print('Warning: Syncing WP User meta failed $e');
        }

        emit(const VendorProfileUpdateSuccess('تم تحديث الملف الشخصي بنجاح'));
        // Reload profile to show changes
        loadVendorProfile(vendorId);
      } else {
        emit(const VendorProfileError('فشل تحديث المعلومات'));
      }
    } catch (e) {
      if (isClosed) return;
      emit(VendorProfileError(e.toString()));
    }
  }

  /// Submit a review for the store
  Future<void> submitStoreReview({
    required int vendorId,
    required int rating,
    required String comment,
  }) async {
    final currentState = state;
    if (currentState is! VendorProfileLoaded) return;

    emit(const VendorProfileUpdating());
    try {
      final response = await _dio.post(
        '${AppConfig.dokanStoreEndpoint}/$vendorId/reviews',
        data: {
          'rating': rating,
          'title': comment.length > 30 ? comment.substring(0, 30) : comment,
          'content': comment,
        },
        options: Options(headers: {'requiresToken': true}),
      );

      if (isClosed) return;
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Optimistically update the UI with the new review from response
        ReviewModel? optimisticReview;
        try {
          optimisticReview = ReviewModel.fromJson(response.data);
          final updatedReviews = [optimisticReview, ...currentState.reviews];
          emit(currentState.copyWith(reviews: updatedReviews));
        } catch (e) {
          // Silent catch for parse error
        }

        emit(const VendorProfileUpdateSuccess('تم إضافة تقييمك بنجاح'));

        // Refresh profile silently (background)
        await loadVendorProfile(vendorId, showLoading: false);

        // After refresh, check if the server still returned stale reviews.
        // If so, re-insert our optimistic review to keep it visible.
        if (isClosed) return;
        final newState = state;
        if (optimisticReview != null && newState is VendorProfileLoaded) {
          final isStillMissing = !newState.reviews.any(
            (r) => r.id == optimisticReview!.id,
          );
          if (isStillMissing) {
            emit(
              newState.copyWith(
                reviews: [optimisticReview, ...newState.reviews],
              ),
            );
          }
        }
      } else {
        emit(const VendorProfileError('فشل في إضافة التقييم'));
        // Stay on loaded state if error
        emit(currentState);
      }
    } catch (e) {
      if (isClosed) return;
      emit(VendorProfileError(e.toString()));
      emit(currentState);
    }
  }

  /// Fetch store details from Dokan API
  Future<StoreModel> _fetchStoreDetails(int vendorId) async {
    try {
      final response = await _dio.get(
        '${AppConfig.dokanStoreEndpoint}/$vendorId',
      );
      return _processStoreResponse(response);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Fallback: Try unauthenticated "Clean" Dio
        final probeDio = Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );
        try {
          final response = await probeDio.get(
            '${AppConfig.dokanStoreEndpoint}/$vendorId',
          );
          return _processStoreResponse(response);
        } catch (_) {
          // Both failed
          throw Exception('عذراً، هذا المتجر غير موجود أو تم إيقافه.');
        }
      }
      rethrow;
    }
  }

  StoreModel _processStoreResponse(Response response) {
    if (response.statusCode == 200) {
      final data = response.data;

      // 🛑 FIX: Handle case where API returns empty List [] instead of Map {}
      if (data is List) {
        if (data.isEmpty) {
          throw Exception('عذراً، هذا المتجر غير موجود أو تم إيقافه.');
        }
        if (data.first is Map<String, dynamic>) {
          return StoreModel.fromJson(data.first);
        }
      }

      if (data is Map<String, dynamic>) {
        if (data['address'] is List) data['address'] = null;
        if (data['social'] is List) data['social'] = null;
        return StoreModel.fromJson(data);
      }
      throw Exception('تنسيق بيانات المتجر غير صالح');
    }
    throw Exception('فشل في تحميل بيانات المتجر');
  }

  /// Fetch vendor products using multiple possible endpoints/strategies
  Future<_ProductsResult> _fetchVendorProducts(
    int vendorId, {
    required int page,
  }) async {
    // 1. Create a clean, unauthenticated Dio for probing data
    final probeDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    final queryParams = {
      'per_page': _perPage,
      'page': page,
      'publish': true,
      'consumer_key': AppConfig.wcConsumerKey,
      'consumer_secret': AppConfig.wcConsumerSecret,
    };

    // We'll try 2 paths for reliability:
    // A: Dokan Store Endpoint
    // B: WC Products with 'vendor' filter
    final List<String> paths = [
      '${AppConfig.dokanStoreEndpoint}/$vendorId/products',
      '${AppConfig.wcProductsEndpoint}?vendor=$vendorId',
    ];

    for (final path in paths) {
      try {
        final response = await probeDio.get(path, queryParameters: queryParams);
        if (response.statusCode == 200 && response.data is List) {
          final List<dynamic> data = response.data;
          final products = data
              .map((json) => ProductModel.fromJson(json))
              .where((product) {
                final name = product.name.toLowerCase();
                return !name.contains('باقة') &&
                    !name.contains('عضوية') &&
                    !name.contains('subscription') &&
                    !name.contains('membership') &&
                    product.id != 29318;
              })
              .toList();

          final totalPages =
              int.tryParse(response.headers.value('x-wp-totalpages') ?? '1') ??
              1;
          return _ProductsResult(products: products, hasMore: page < totalPages);
        }
      } catch (e) {
        // Continue to next path
      }
    }

    // Final fallback: empty list instead of crashing
    return _ProductsResult(products: [], hasMore: false);
  }

  /// Fetch store reviews from Dokan API
  /// Fetch store reviews from Dokan API (Clean & Simple)
  Future<List<ReviewModel>> _fetchStoreReviews(int vendorId) async {
    try {
      // Construct an ABSOLUTE URL for the fresh Dio instance
      final baseUrl = AppConfig.dokanStoreEndpoint.contains('http')
          ? ''
          : 'https://hiraajsahm.com/wp-json';
      final absoluteUrl =
          '$baseUrl${AppConfig.dokanStoreEndpoint}/$vendorId/reviews';

      // 1. Setup a browser-mimic Dio
      final probeDio = Dio(
        BaseOptions(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      // 2. Concurrently probe
      final results = await Future.wait([
        // Path A: The raw browser URL
        probeDio.get('$absoluteUrl?v=${DateTime.now().millisecondsSinceEpoch}'),

        // Path B: Exhaustive status
        probeDio.get(
          absoluteUrl,
          queryParameters: {
            'status': 'any,all,approved,pending,hold,unapproved',
            'per_page': 100,
            '_': DateTime.now().millisecondsSinceEpoch + 1,
          },
        ),

        // Path C: User's Path (Keys + Any)
        probeDio.get(
          absoluteUrl,
          queryParameters: {
            'status': 'any',
            'consumer_key': AppConfig.wcConsumerKey,
            'consumer_secret': AppConfig.wcConsumerSecret,
            '_': DateTime.now().millisecondsSinceEpoch + 2,
          },
        ),
      ]);

      final Map<int, ReviewModel> mergedReviews = {};

      for (var i = 0; i < results.length; i++) {
        final response = results[i];
        if (response.statusCode == 200 && response.data is List) {
          final List<dynamic> data = response.data;
          for (final json in data) {
            try {
              final review = ReviewModel.fromJson(json);
              mergedReviews[review.id] = review;
            } catch (e) {
              // Ignore parse errors for specific items
            }
          }
        }
      }

      final sortedReviews = mergedReviews.values.toList()
        ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

      return sortedReviews;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Just return empty, No need to log "Fatal Error" for a missing endpoint
        return [];
      }
      print('❌ Review Aggressive probe handled error: $e');
      return [];
    }
  }

  /// Upload media to WordPress Media Library
  Future<int?> uploadMedia(String filePath) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/wp/v2/media', // WordPress Media Endpoint
        data: formData,
        options: Options(headers: {'requiresToken': true}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['id'] as int?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Helper class for products result with pagination info
class _ProductsResult {
  final List<ProductModel> products;
  final bool hasMore;

  _ProductsResult({required this.products, required this.hasMore});
}
