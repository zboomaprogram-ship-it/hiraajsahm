import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/services/storage_service.dart';
import '../models/request_model.dart';
import '../models/service_provider_model.dart';

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

  Future<void> submitToFluentForms({
    required int formId,
    required Map<String, dynamic> data,
    File? vehicleImage,
    File? licenseImage,
  }) async {
    try {
      final token = await _storageService.getToken();
      final formData = FormData.fromMap({...data, 'form_id': formId});

      if (vehicleImage != null) {
        String fileName = vehicleImage.path.split('/').last;
        formData.files.add(
          MapEntry(
            'vehicle_image', // Correct key from USER
            await MultipartFile.fromFile(vehicleImage.path, filename: fileName),
          ),
        );
      }

      if (licenseImage != null) {
        String fileName = licenseImage.path.split('/').last;
        formData.files.add(
          MapEntry(
            'license_image', // Correct key from USER
            await MultipartFile.fromFile(licenseImage.path, filename: fileName),
          ),
        );
      }

      final response = await _dio.post(
        '/custom/v1/submit-fluent-form', // Fixed: Remove /wp-json
        data: formData,
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw 'Failed to submit form: ${response.statusCode}';
      }

      final responseData = response.data;
      if (responseData is Map && responseData['success'] == false) {
        throw responseData['message'] ?? 'Submission failed';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<ServiceProviderModel>> getServiceProviders(String city) async {
    try {
      final response = await _dio.get(
        '/custom/v1/service-providers',
        queryParameters: {'city': city},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((item) => ServiceProviderModel.fromJson(item)).toList();
      } else {
        throw 'Failed to fetch service providers: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
