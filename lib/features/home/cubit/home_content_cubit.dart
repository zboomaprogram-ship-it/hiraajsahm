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

  /// Load home content - latest products and featured items
  Future<void> loadHomeContent() async {
    if (state is HomeContentLoading) return;

    emit(const HomeContentLoading());

    try {
      // Fetch latest products
      const productsUrl = 'https://hiraajsahm.com/wp-json/wc/v3/products';

      final response = await _cleanDio.get(
        productsUrl,
        queryParameters: {
          'per_page': 10,
          'orderby': 'date',
          'order': 'desc',
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Filter out product 29318 (Al-Zabayeh fee) and category 122 (subscription packs)
        const alZabayehProductId = 29318;
        const excludeCategoryId = 122;
        final latestProducts = data
            .map((json) => ProductModel.fromJson(json))
            .where((product) => product.status == 'publish')
            .where((product) => product.id != alZabayehProductId)
            .where((p) => !p.categories.any((c) => c.id == excludeCategoryId))
            .toList();

        // Try to fetch featured products
        List<ProductModel> featuredProducts = [];
        try {
          final featuredResponse = await _cleanDio.get(
            productsUrl,
            queryParameters: {
              'per_page': 5,
              'featured': true,
              'consumer_key': AppConfig.wcConsumerKey,
              'consumer_secret': AppConfig.wcConsumerSecret,
            },
          );

          if (featuredResponse.statusCode == 200) {
            final List<dynamic> featuredData = featuredResponse.data;
            featuredProducts = featuredData
                .map((json) => ProductModel.fromJson(json))
                .where((product) => product.status == 'publish')
                .where((product) => product.id != alZabayehProductId)
                .where(
                  (p) => !p.categories.any((c) => c.id == excludeCategoryId),
                )
                .toList();
          }
        } catch (_) {
          // Featured products optional, continue without them
        }

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

  /// Refresh home content
  Future<void> refresh() async {
    emit(const HomeContentInitial());
    await loadHomeContent();
  }
}
