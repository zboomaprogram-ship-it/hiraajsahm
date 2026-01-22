import 'package:dio/dio.dart';
import '../models/request_model.dart';

class RequestsService {
  final Dio _dio;

  RequestsService(this._dio);

  Future<void> submitRequest(RequestModel request) async {
    try {
      final response = await _dio.post(
        '/hiraajsahm/v1/submit-entry',
        data: request.toJson(),
      );

      if (response.statusCode != 200) {
        throw 'Failed to submit request: ${response.statusCode}';
      }

      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw data['message'] ?? 'Failed to submit request';
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
