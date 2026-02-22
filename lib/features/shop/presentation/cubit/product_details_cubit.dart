import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../data/models/review_model.dart';

// --- States ---
abstract class ProductDetailsState extends Equatable {
  const ProductDetailsState();
  @override
  List<Object> get props => [];
}

class ProductDetailsInitial extends ProductDetailsState {}

class ProductDetailsLoading extends ProductDetailsState {}

class ProductDetailsLoaded extends ProductDetailsState {
  final List<ReviewModel> reviews;
  const ProductDetailsLoaded(this.reviews);
  @override
  List<Object> get props => [reviews];
}

class ProductDetailsError extends ProductDetailsState {
  final String message;
  const ProductDetailsError(this.message);
  @override
  List<Object> get props => [message];
}

// --- Cubit ---
class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  final Dio dio;

  ProductDetailsCubit({required this.dio}) : super(ProductDetailsInitial());

  // Helper to generate Basic Auth Header
  String _getBasicAuthHeader() {
    return 'Basic ' +
        base64Encode(
          utf8.encode(
            '${AppConfig.wcConsumerKey}:${AppConfig.wcConsumerSecret}',
          ),
        );
  }

  Future<void> loadReviews(int productId) async {
    if (isClosed) return;
    emit(ProductDetailsLoading());

    try {
      // ✅ FIX: Create a fresh Dio instance to avoid sending the User Token
      final cleanDio = Dio();

      final response = await cleanDio.get(
        '${AppConfig.baseUrl}${AppConfig.wcProductsEndpoint}/reviews',
        queryParameters: {
          'product': productId,
          'status': 'any',
          'order': 'desc',
          'orderby': 'date',
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
          '_': DateTime.now().millisecondsSinceEpoch,
        },
        // Remove headers to be safe
        options: Options(headers: {}),
      );

      print(
        '📥 PRODUCT REVIEWS RESP [$productId]: Size ${response.data is List ? (response.data as List).length : 'JSON Map'}',
      );
      print('📝 PRODUCT REVIEWS DATA: ${response.data}');

      if (isClosed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final reviews = data.map((json) => ReviewModel.fromJson(json)).toList();
        emit(ProductDetailsLoaded(reviews));
      } else {
        emit(const ProductDetailsError('فشل في تحميل التقييمات'));
      }
    } catch (e) {
      if (!isClosed) {
        print('Error loading reviews: $e');
        emit(ProductDetailsError(e.toString()));
      }
    }
  }

  Future<void> submitReview({
    required int productId,
    required String review,
    required int rating,
    required String reviewer,
    required String reviewerEmail,
  }) async {
    if (isClosed) return;
    emit(ProductDetailsLoading());

    try {
      final response = await dio.post(
        '${AppConfig.baseUrl}${AppConfig.wcProductsEndpoint}/reviews',
        data: {
          'product_id': productId,
          'review': review,
          'rating': rating,
          'reviewer': reviewer,
          'reviewer_email': reviewerEmail,
        },
        options: Options(
          headers: {
            'Authorization': _getBasicAuthHeader(),
            'Content-Type': 'application/json',
          },
        ),
      );

      if (isClosed) return;

      if (response.statusCode == 201) {
        // Reload reviews to show the new one immediately
        await loadReviews(productId);
      } else {
        emit(const ProductDetailsError('فشل في إرسال التقييم'));
      }
    } catch (e) {
      if (!isClosed) emit(ProductDetailsError(e.toString()));
    }
  }
}
