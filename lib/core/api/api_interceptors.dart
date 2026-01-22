import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../services/storage_service.dart';
import '../utils/navigator_key.dart';
import '../routes/routes.dart';

/// API Interceptor for handling requests, responses, and errors
/// Provides centralized logging and error handling
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (AppConfig.enableLogging) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 REQUEST[${options.method}] => PATH: ${options.path}');
      print('Headers: ${options.headers}');
      print('Query Parameters: ${options.queryParameters}');
      if (options.data != null) {
        print('Body: ${options.data}');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (AppConfig.enableLogging) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print(
        '📥 RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
      );
      print('Data: ${response.data}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (AppConfig.enableLogging) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print(
        '❌ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}',
      );
      print('Message: ${err.message}');
      print('Response: ${err.response?.data}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
    super.onError(err, handler);
  }
}

/// Authentication Interceptor
/// Automatically adds JWT authentication token to requests
class AuthInterceptor extends Interceptor {
  final StorageService _storageService;

  AuthInterceptor({required StorageService storageService})
    : _storageService = storageService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add JWT token to protected endpoints
    final path = options.path.toLowerCase();

    // Check if this is a protected endpoint that needs authentication
    final needsAuth =
        path.contains('/dokan/') ||
        path.contains('/wc/v3/') ||
        path.contains('/wp/v2/users') ||
        path.contains('/jwt-auth/v1/token/validate');

    if (needsAuth) {
      final token = await _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    // Add WooCommerce consumer keys for WC endpoints
    if (path.contains('/wc/v3/')) {
      // For public WC endpoints, use consumer key/secret
      if (!options.headers.containsKey('Authorization')) {
        options.queryParameters['consumer_key'] = AppConfig.wcConsumerKey;
        options.queryParameters['consumer_secret'] = AppConfig.wcConsumerSecret;
      }
    }

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized - Token expired
    if (err.response?.statusCode == 401) {
      // Clear all auth data
      await _storageService.logout();

      // Navigate to login screen
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Routes.login,
        (route) => false,
      );
    }
    super.onError(err, handler);
  }
}

/// Retry Interceptor
/// Automatically retries failed requests
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({required this.dio, this.maxRetries = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only retry on connection errors
    if (_shouldRetry(err) && err.requestOptions.extra['retryCount'] == null) {
      int retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < maxRetries) {
        err.requestOptions.extra['retryCount'] = retryCount + 1;

        // Wait before retrying
        await Future.delayed(Duration(seconds: retryCount + 1));

        try {
          final response = await dio.fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          // Continue with original error
        }
      }
    }

    super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}
