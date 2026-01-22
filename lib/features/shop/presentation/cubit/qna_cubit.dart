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

  Future<void> fetchProductQuestions(int productId) async {
    emit(QnALoading());
    try {
      final response = await dio.get(
        '${AppConfig.baseUrl}/custom/v1/qa/product',
        queryParameters: {'product_id': productId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final questions = data
            .map((json) => QuestionModel.fromJson(json))
            .toList();
        emit(QnALoaded(questions));
      } else {
        emit(const QnAError('فشل في تحميل الأسئلة'));
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // MOCK DATA FOR 404
        // TODO: Remove this mock when backend endpoint is ready
        await Future.delayed(const Duration(milliseconds: 500));
        // emit(
        //   QnALoaded([
        //     QuestionModel(
        //       id: 1,
        //       productName: 'منتج تجريبي',
        //       question: 'هل المنتج متوفر باللون الأحمر؟',
        //       answer: 'نعم، متوفر بجميع الألوان.',
        //       date: '2024-03-20',
        //       isAnswered: true,
        //     ),
        //     QuestionModel(
        //       id: 2,
        //       productName: 'منتج تجريبي',
        //       question: 'كم مدة الضمان؟',
        //       answer: null,
        //       date: '2024-03-21',
        //       isAnswered: false,
        //     ),
        //   ]),
        // );
      } else {
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
        // MOCK DATA FOR 404
        // TODO: Remove this mock when backend endpoint is ready
        await Future.delayed(const Duration(milliseconds: 500));
        emit(
          QnALoaded([
            QuestionModel(
              id: 3,
              productName: 'ساعة ذكية',
              question: 'هل تدعم اللغة العربية؟',
              answer: null,
              date: '2024-03-22',
              isAnswered: false,
            ),
            QuestionModel(
              id: 4,
              productName: 'سماعة بلوتوث',
              question: 'كم تدوم البطارية؟',
              answer: 'تدوم حتى 20 ساعة.',
              date: '2024-03-19',
              isAnswered: true,
            ),
          ]),
        );
      } else {
        emit(QnAError(e.toString()));
      }
    }
  }

  Future<void> askQuestion(int productId, String text) async {
    emit(QnALoading());
    try {
      final options = await _getOptions();
      final response = await dio.post(
        '${AppConfig.baseUrl}/custom/v1/qa/ask',
        data: {'product_id': productId, 'question': text},
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        emit(const QnASuccess('تم إرسال سؤالك بنجاح'));
        await fetchProductQuestions(productId);
      } else {
        emit(const QnAError('فشل في إرسال السؤال'));
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // MOCK SUCCESS FOR 404
        // TODO: Remove this mock when backend endpoint is ready
        await Future.delayed(const Duration(milliseconds: 500));
        emit(const QnASuccess('تم إرسال سؤالك بنجاح (محاكاة)'));
        // Re-fetch (which will return mock data)
        await fetchProductQuestions(productId);
      } else {
        emit(QnAError(e.toString()));
      }
    }
  }

  Future<void> replyToQuestion(int questionId, String answer) async {
    emit(QnALoading());
    try {
      final options = await _getOptions();
      final response = await dio.post(
        '${AppConfig.baseUrl}/custom/v1/qa/reply',
        data: {'question_id': questionId, 'answer': answer},
        options: options,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        emit(const QnASuccess('تم إرسال الرد بنجاح'));
        await fetchVendorQuestions();
      } else {
        emit(const QnAError('فشل في إرسال الرد'));
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // MOCK SUCCESS FOR 404
        // TODO: Remove this mock when backend endpoint is ready
        await Future.delayed(const Duration(milliseconds: 500));
        emit(const QnASuccess('تم إرسال الرد بنجاح (محاكاة)'));
        // Re-fetch (which will return mock data)
        await fetchVendorQuestions();
      } else {
        emit(QnAError(e.toString()));
      }
    }
  }
}
