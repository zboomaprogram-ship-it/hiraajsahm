import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';

// ============ SERVICES STATES ============
abstract class ServicesState extends Equatable {
  const ServicesState();

  @override
  List<Object?> get props => [];
}

class ServicesInitial extends ServicesState {
  const ServicesInitial();
}

class ServicesSubmitting extends ServicesState {
  const ServicesSubmitting();
}

class ServicesSuccess extends ServicesState {
  final int requestId;
  final String requestType;

  const ServicesSuccess({required this.requestId, required this.requestType});

  @override
  List<Object?> get props => [requestId, requestType];
}

class ServicesError extends ServicesState {
  final String message;

  const ServicesError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ============ SERVICES CUBIT ============
/// Handles Transport and Inspection service requests
class ServicesCubit extends Cubit<ServicesState> {
  final Dio _cleanDio;

  ServicesCubit()
    : _cleanDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ),
      super(const ServicesInitial());

  /// Submit Transport Request
  Future<void> submitTransportRequest({
    required String customerName,
    required String phone,
    required String fromLocation,
    required String toLocation,
    required int productId,
    required String productName,
    String? vehicleType,
    String? notes,
  }) async {
    emit(const ServicesSubmitting());

    try {
      final customerNote =
          '''
REQUEST TYPE: Transport
Product: $productName (ID: $productId)
From: $fromLocation
To: $toLocation
Vehicle Type: ${vehicleType ?? 'Standard'}
Notes: ${notes ?? 'None'}
''';

      await _submitServiceOrder(
        customerName: customerName,
        phone: phone,
        customerNote: customerNote,
        requestType: 'نقل',
      );
    } catch (e) {
      emit(ServicesError(message: e.toString()));
    }
  }

  /// Submit Inspection Request
  Future<void> submitInspectionRequest({
    required String customerName,
    required String phone,
    required String location,
    required int productId,
    required String productName,
    String? preferredDate,
    String? notes,
  }) async {
    emit(const ServicesSubmitting());

    try {
      final customerNote =
          '''
REQUEST TYPE: Inspection
Product: $productName (ID: $productId)
Location: $location
Preferred Date: ${preferredDate ?? 'As soon as possible'}
Notes: ${notes ?? 'None'}
''';

      await _submitServiceOrder(
        customerName: customerName,
        phone: phone,
        customerNote: customerNote,
        requestType: 'معاينة',
      );
    } catch (e) {
      emit(ServicesError(message: e.toString()));
    }
  }

  Future<void> _submitServiceOrder({
    required String customerName,
    required String phone,
    required String customerNote,
    required String requestType,
  }) async {
    try {
      const fullUrl = 'https://hiraajsahm.com/wp-json/wc/v3/orders';

      // Split name into first and last
      final nameParts = customerName.split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      final orderData = {
        'payment_method': 'cod',
        'payment_method_title': 'الدفع عند الإتمام',
        'set_paid': false,
        'status': 'pending',
        'billing': {
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'country': 'SA',
        },
        'line_items': [], // Empty - service request, no products
        'customer_note': customerNote,
        'meta_data': [
          {'key': 'service_request_type', 'value': requestType},
        ],
      };

      final response = await _cleanDio.post(
        fullUrl,
        data: orderData,
        queryParameters: {
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final orderId = response.data['id'] ?? 0;
        emit(ServicesSuccess(requestId: orderId, requestType: requestType));
      } else {
        emit(const ServicesError(message: 'فشل إرسال الطلب'));
      }
    } on DioException catch (e) {
      String errorMessage = 'خطأ في الاتصال بالخادم';

      if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }

      emit(ServicesError(message: errorMessage));
    }
  }

  /// Reset to initial state
  void reset() {
    emit(const ServicesInitial());
  }
}
