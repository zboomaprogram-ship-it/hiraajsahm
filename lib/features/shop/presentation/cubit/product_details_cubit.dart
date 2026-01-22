import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../data/models/review_model.dart';

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

class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  final Dio dio;

  ProductDetailsCubit({required this.dio}) : super(ProductDetailsInitial());

  Future<void> loadReviews(int productId) async {
    if (isClosed) return;
    emit(ProductDetailsLoading());
    try {
      final response = await dio.get(
        'https://hiraajsahm.com/wp-json/wc/v3/products/reviews',
        queryParameters: {
          'product': productId,
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );

      if (isClosed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final reviews = data.map((json) => ReviewModel.fromJson(json)).toList();
        emit(ProductDetailsLoaded(reviews));
      } else {
        emit(const ProductDetailsError('فشل في تحميل التقييمات'));
      }
    } catch (e) {
      if (!isClosed) emit(ProductDetailsError(e.toString()));
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
        'https://hiraajsahm.com/wp-json/wc/v3/products/reviews',
        queryParameters: {
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
        data: {
          'product_id': productId,
          'review': review,
          'rating': rating,
          'reviewer': reviewer,
          'reviewer_email': reviewerEmail,
        },
      );

      if (isClosed) return;

      if (response.statusCode == 201) {
        // Reload reviews after successful submission
        await loadReviews(productId);
      } else {
        emit(const ProductDetailsError('فشل في إرسال التقييم'));
      }
    } catch (e) {
      if (!isClosed) emit(ProductDetailsError(e.toString()));
    }
  }
}
