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
      const productsUrl = 'https://hiraajsahm.com/wp-json/wc/v3/products';
      const alZabayehProductId = 29318;
      const excludeCategoryId = 122;

      // Prepare both requests
      final latestRequest = _cleanDio.get(
        productsUrl,
        queryParameters: {
          'per_page': 10,
          'orderby': 'date',
          'order': 'desc',
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );

      final featuredRequest = _cleanDio.get(
        productsUrl,
        queryParameters: {
          'per_page': 5,
          'featured': true,
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
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
        final latestProducts = data
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
