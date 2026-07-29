import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/question_model.dart';
import '../../../../core/config/app_config.dart';

// States
abstract class QnAState extends Equatable {
  const QnAState();
  @override
  List<Object?> get props => [];
}

class QnAInitial extends QnAState {}

class QnALoading extends QnAState {}

class QnALoaded extends QnAState {
  final List<QuestionModel> questions;
  const QnALoaded(this.questions);
  @override
  List<Object?> get props => [questions];
}

class QnASuccess extends QnAState {
  final String message;
  const QnASuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class QnAError extends QnAState {
  final String message;
  const QnAError(this.message);
  @override
  List<Object?> get props => [message];
}

// Cubit
class QnACubit extends Cubit<QnAState> {
  final Dio dio;
  final StorageService storageService;

  QnACubit({required this.dio, required this.storageService})
    : super(QnAInitial());

  // Helper to get headers
  Future<Options> _getOptions() async {
    final token = await storageService.getToken();
    return Options(
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
  }

  String? _errorMessage(Object error) {
    if (error is! DioException || error.response?.data is! Map) return null;
    final data = Map<String, dynamic>.from(error.response!.data as Map);
    return switch (data['code']?.toString()) {
      'bid_unavailable' => 'هذه المزايدة لم تعد متاحة لهذا المشتري',
      'auction_closed' => 'تم إغلاق المزاد بعد إتمام البيع',
      'bid_too_low' => 'يجب أن تكون المزايدة أعلى من أعلى سعر حالي',
      'bid_not_highest' => 'يمكن قبول أعلى مزايدة حالية فقط',
      'sale_already_finalized' => 'تم بيع هذا الإعلان بالفعل',
      'cannot_bid_own_product' => 'لا يمكنك المزايدة على إعلانك',
      _ => data['message']?.toString(),
    };
  }

  Future<void> fetchProductQuestions(
    int productId, {
    bool showLoading = true,
  }) async {
    final previousState = state;
    if (showLoading) emit(QnALoading());
    try {
      final response = await dio.get(
        '${AppConfig.baseUrl}/custom/v1/qa/product',
        queryParameters: {'product_id': productId},
      );
      if (isClosed) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final questions = data
            .map((json) => QuestionModel.fromJson(json))
            .toList();
        emit(QnALoaded(questions));
      } else if (showLoading || previousState is! QnALoaded) {
        emit(const QnAError('فشل في تحميل الأسئلة'));
      }
    } catch (e) {
      if (isClosed) return;
      if (e is DioException && e.response?.statusCode == 404) {
        emit(const QnALoaded([]));
      } else if (showLoading || previousState is! QnALoaded) {
        emit(QnAError(e.toString()));
      }
    }
  }

  Future<void> fetchVendorQuestions() async {
    emit(QnALoading());
    try {
      final options = await _getOptions();
      final response = await dio.get(
        '${AppConfig.baseUrl}/custom/v1/qa/vendor',
        options: options,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final questions = data
            .map((json) => QuestionModel.fromJson(json))
            .toList();
        emit(QnALoaded(questions));
      } else {
        emit(const QnAError('فشل في تحميل أسئلة البائع'));
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        emit(const QnAError('خدمة التعليقات غير متاحة حالياً'));
      } else {
        emit(QnAError(e.toString()));
      }
    }
  }

  Future<bool> askQuestion(int productId, String text) async {
    final previousState = state;
    try {
      final options = await _getOptions();
      final response = await dio.post(
        '${AppConfig.baseUrl}/custom/v1/qa/ask',
        data: {'product_id': productId, 'question': text},
        options: options,
      );
      if (isClosed) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchProductQuestions(productId, showLoading: false);
        return true;
      } else {
        if (previousState is QnALoaded) {
          emit(previousState);
        } else {
          emit(const QnAError('فشل في إرسال السؤال'));
        }
        return false;
      }
    } catch (e) {
      if (isClosed) return false;
      if (previousState is QnALoaded) {
        emit(previousState);
      } else {
        emit(QnAError(e.toString()));
      }
      return false;
    }
  }

  Future<bool> replyToQuestion(
    int questionId,
    String answer, {
    int? productId,
  }) async {
    final previousState = state;
    try {
      final options = await _getOptions();
      final response = await dio.post(
        '${AppConfig.baseUrl}/custom/v1/qa/reply',
        data: {'question_id': questionId, 'answer': answer},
        options: options,
      );
      if (isClosed) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (productId != null) {
          await fetchProductQuestions(productId, showLoading: false);
        } else {
          await fetchVendorQuestions();
        }
        return true;
      } else {
        if (previousState is QnALoaded) {
          emit(previousState);
        } else {
          emit(const QnAError('فشل في إرسال الرد'));
        }
        return false;
      }
    } catch (e) {
      if (isClosed) return false;
      if (previousState is QnALoaded) {
        emit(previousState);
      } else {
        emit(QnAError(e.toString()));
      }
      return false;
    }
  }

  Future<bool> placeBid(
    int productId,
    double amount, {
    String note = '',
  }) async {
    try {
      final options = await _getOptions();
      final response = await dio.post(
        '${AppConfig.baseUrl}/custom/v1/qa/bid',
        data: {
          'product_id': productId,
          'amount': amount.toStringAsFixed(2),
          if (note.trim().isNotEmpty) 'note': note.trim(),
        },
        options: options,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchProductQuestions(productId);
        return true;
      }
      return false;
    } catch (error) {
      final message = _errorMessage(error);
      emit(QnAError(message ?? 'تعذر إضافة المزايدة'));
      return false;
    }
  }

  Future<bool> acceptBid(int productId, int bidId) async {
    try {
      final options = await _getOptions();
      final response = await dio.post(
        '${AppConfig.baseUrl}/custom/v1/qa/bid/$bidId/accept',
        options: options,
      );
      if (response.statusCode == 200) {
        await fetchProductQuestions(productId);
        return true;
      }
      return false;
    } catch (error) {
      final message = _errorMessage(error);
      emit(QnAError(message ?? 'تعذر اعتماد المزايدة'));
      return false;
    }
  }

  Future<AcceptedBidModel?> checkoutBid(int bidId) async {
    try {
      final options = await _getOptions();
      final response = await dio.post(
        '${AppConfig.baseUrl}/custom/v1/qa/bid/$bidId/checkout',
        options: options,
      );
      if (response.statusCode == 200 && response.data is Map) {
        return AcceptedBidModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (error) {
      final message = _errorMessage(error);
      emit(QnAError(message ?? 'تعذر تجهيز المزايدة للدفع'));
    }
    return null;
  }
}
