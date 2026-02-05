import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/services/storage_service.dart';
import '../models/request_model.dart';

class RequestsService {
  final Dio _dio;
  final StorageService _storageService;

  RequestsService(this._dio, this._storageService);

  Future<String> uploadImage(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final token = await _storageService.getToken();

      final response = await _dio.post(
        '/wp/v2/media',
        data: formData,
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['source_url'];
      } else {
        throw 'Failed to upload image: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Image upload failed: $e';
    }
  }

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
