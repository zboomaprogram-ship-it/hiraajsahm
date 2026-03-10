import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Telr Payment Service
/// Handles communication with the WP backend to create a Telr Hosted Payment Page session
/// and verify its status upon completion.
class TelrPaymentService {
  TelrPaymentService();

  /// Create a Telr Order Session via WP Backend
  /// Returns a Map containing 'order_url' and 'order_ref'
  Future<Map<String, dynamic>> createOrderSession({
    required int orderId,
    required String amount,
    required String customerEmail,
    required String customerName,
    String currency = 'SAR',
    String? description,
    String? billingAddress,
    String? billingCity,
    String? billingCountry,
    String? billingPhone,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}${AppConfig.telrTokenEndpoint}');

    final payload = {
      'consumer_key': AppConfig.wcConsumerKey,
      'consumer_secret': AppConfig.wcConsumerSecret,
      'order_id': orderId.toString(),
      'amount': amount,
      'currency': currency,
      'description': description ?? 'Order #$orderId',
      'customer_email': customerEmail,
      'customer_name': customerName,
      'billing_address': billingAddress ?? '',
      'billing_city': billingCity ?? '',
      'billing_country': billingCountry ?? 'SA',
      'billing_phone': billingPhone ?? '',
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'order_url': data['order_url'], 'order_ref': data['order_ref']};
    } else {
      throw Exception('Failed to create payment session: ${response.body}');
    }
  }

  /// Check the status of the order to confirm payment success.
  /// The Telr SDK calls this with GET + Authorization: Bearer <token>.
  /// We use a custom query parameter on the homepage to bypass JWT plugins.
  String buildOrderUrl() {
    final params = {
      'telr_order_check': '1',
      'consumer_key': AppConfig.wcConsumerKey,
      'consumer_secret': AppConfig.wcConsumerSecret,
    };

    // Strip /wp-json from baseUrl to get the site root (e.g., https://site.com)
    final siteUrl = AppConfig.baseUrl.replaceAll('/wp-json', '');

    final uri = Uri.parse(siteUrl).replace(queryParameters: params);
    return uri.toString();
  }
}
