import 'package:dio/dio.dart';
import '../models/service_provider_model.dart';

class ServiceProviderService {
  final Dio _dio;

  ServiceProviderService(this._dio);

  Future<List<ServiceProviderModel>> getServiceProviders(String city) async {
    try {
      final response = await _dio.get(
        '/custom/v1/service-providers',
        queryParameters: {'city': city},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ServiceProviderModel.fromJson(json)).toList();
      } else {
        throw 'Failed to fetch service providers: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
