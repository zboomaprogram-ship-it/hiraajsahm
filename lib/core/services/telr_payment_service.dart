import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Telr Payment Service
/// ⚠️ NOTE: As of the confirmed fix (FL-4), the URL building for TelrSdk.presentPayment
/// is performed directly inside _handleTelrPayment in checkout_screen.dart.
/// These methods can be used for manual verification but are not passed to the SDK.
class TelrPaymentService {
  final Dio _dio;

  TelrPaymentService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  /// ⚠️ NOT USED FOR SDK CALL: Build clean URLs for manual tracking
  String buildTokenUrl({
    required int orderId,
    required String amount,
    required String customerEmail,
    required String customerName,
  }) {
    final params = {
      'order_id': orderId.toString(),
      'amount': amount,
      'currency': 'SAR',
      'customer_email': customerEmail,
      'customer_name': customerName,
      'consumer_key': AppConfig.wcConsumerKey,
      'consumer_secret': AppConfig.wcConsumerSecret,
    };

    return Uri.parse('${AppConfig.baseUrl}${AppConfig.telrTokenEndpoint}')
        .replace(queryParameters: params)
        .toString();
  }

  /// ⚠️ NOT USED FOR SDK CALL: Status check URL
  String buildOrderUrl(int orderId) {
    final params = {
      'order_id': orderId.toString(),
      'consumer_key': AppConfig.wcConsumerKey,
      'consumer_secret': AppConfig.wcConsumerSecret,
    };

    return Uri.parse('${AppConfig.baseUrl}${AppConfig.telrOrderEndpoint}')
        .replace(queryParameters: params)
        .toString();
  }
}
