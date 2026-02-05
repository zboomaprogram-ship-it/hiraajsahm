import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/config/app_config.dart';
import 'package:dartz/dartz.dart';

abstract class VendorRemoteDataSource {
  Future<Either<Failure, bool>> upgradeUserToVendor({
    required int userId,
    required String shopName,
    required String phone,
    String? shopLink,
  });
}

class VendorRemoteDataSourceImpl implements VendorRemoteDataSource {
  final Dio _dio;

  VendorRemoteDataSourceImpl(this._dio);

  @override
  Future<Either<Failure, bool>> upgradeUserToVendor({
    required int userId,
    required String shopName,
    required String phone,
    String? shopLink,
  }) async {
    try {
      final response = await _dio.post(
        AppConfig.customVendorUpgradeEndpoint,
        data: {
          'user_id': userId,
          'store_name': shopName,
          'phone': phone,
          if (shopLink != null && shopLink.isNotEmpty) 'shop_link': shopLink,
        },
      );

      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(
          ServerFailure(
            message: response.data['message'] ?? 'Failed to upgrade to vendor',
          ),
        );
      }
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Failure _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      String message = 'An error occurred';

      if (data is Map<String, dynamic>) {
        message = data['message'] ?? data['error'] ?? message;
      }

      switch (e.response?.statusCode) {
        case 400:
          return ServerFailure(message: message);
        case 401:
          return AuthFailure(message: message);
        case 403:
          return AuthFailure(message: 'Access denied');
        case 404:
          return ServerFailure(message: 'Resource not found');
        case 500:
          return ServerFailure(message: 'Server error');
        default:
          return ServerFailure(message: message);
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkFailure(message: 'Connection timeout');
      case DioExceptionType.connectionError:
        return NetworkFailure(message: 'No internet connection');
      default:
        return ServerFailure(message: e.message ?? 'Unknown error');
    }
  }
}
