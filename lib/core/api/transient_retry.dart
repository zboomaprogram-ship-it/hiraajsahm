import 'package:dio/dio.dart';

Future<Response<T>> getWithTransientRetry<T>(
  Dio dio,
  String path, {
  Map<String, dynamic>? queryParameters,
  Options? options,
}) async {
  DioException? lastError;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      lastError = error;
      final status = error.response?.statusCode;
      final transient =
          status == 502 ||
          status == 503 ||
          status == 504 ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
      if (!transient || attempt == 2) rethrow;
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 700 : 1600),
      );
    }
  }
  throw lastError!;
}
