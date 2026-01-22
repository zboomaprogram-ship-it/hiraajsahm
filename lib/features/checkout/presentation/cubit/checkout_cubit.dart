import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/storage_service.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart'; // Add import
import '../../../auth/presentation/cubit/auth_cubit.dart'; // Add import

// ============ CHECKOUT STATES ============
abstract class CheckoutState extends Equatable {
  const CheckoutState();

  @override
  List<Object?> get props => [];
}

class CheckoutInitial extends CheckoutState {
  const CheckoutInitial();
}

class CheckoutProcessing extends CheckoutState {
  const CheckoutProcessing();
}

class CheckoutSuccess extends CheckoutState {
  final int orderId;
  final String orderKey;

  const CheckoutSuccess({required this.orderId, required this.orderKey});

  @override
  List<Object?> get props => [orderId, orderKey];
}

class CheckoutFailure extends CheckoutState {
  final String message;

  const CheckoutFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  final Dio _cleanDio;
  final CartCubit _cartCubit;
  final AuthCubit _authCubit; // Add AuthCubit
  final StorageService _storageService;

  CheckoutCubit({
    required CartCubit cartCubit,
    required AuthCubit authCubit, // Add parameter
    required StorageService storageService,
  }) : _cartCubit = cartCubit,
       _authCubit = authCubit,
       _storageService = storageService,
       _cleanDio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 30),
           headers: {
             'Content-Type': 'application/json',
             'Accept': 'application/json',
           },
         ),
       ),
       super(const CheckoutInitial());

  /// Place order via WooCommerce API
  Future<void> placeOrder({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? city,
    String? address,
    required String paymentMethod,
    String paymentType = 'full',
    String? notes,
  }) async {
    emit(const CheckoutProcessing());

    try {
      final cartState = _cartCubit.state;
      if (cartState is! CartLoaded || cartState.isEmpty) {
        emit(const CheckoutFailure(message: 'السلة فارغة'));
        return;
      }

      // Check for Subscription
      final isSubscription = cartState.items.any((item) {
        final id = item.product.id;
        final name = item.product.name;
        return [29026, 29030, 29318].contains(id) || name.contains('باقة');
      });

      // Auto-fill Logic
      String finalFirstName = firstName ?? '';
      String finalLastName = lastName ?? '';
      String finalPhone = phone ?? '';
      String finalEmail = email ?? '';
      String finalCity = city ?? '';
      String finalAddress = address ?? '';

      if (isSubscription) {
        // Auto-fill from AuthCubit if fields are empty
        final authState = _authCubit.state;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          if (finalFirstName.isEmpty) finalFirstName = user.firstName ?? '';
          if (finalLastName.isEmpty) finalLastName = user.lastName ?? '';
          if (finalPhone.isEmpty) finalPhone = user.phone ?? '';
          if (finalEmail.isEmpty) finalEmail = user.email;
        } else {
          // Fallback to StorageService logic if needed, but AuthCubit should have it
          if (finalEmail.isEmpty)
            finalEmail = (await _storageService.getUserEmail()) ?? '';
        }

        if (finalAddress.isEmpty) finalAddress = 'Digital Subscription';
        if (finalCity.isEmpty) finalCity = 'Digital'; // Dummy city
      } else {
        // Validate required fields for physical products
        if (finalFirstName.isEmpty ||
            finalPhone.isEmpty ||
            finalAddress.isEmpty) {
          emit(const CheckoutFailure(message: 'يرجى إكمال بيانات الشحن'));
          return;
        }
      }

      // Get user ID
      final userId = await _storageService.getUserId();

      // Build line items
      final lineItems = cartState.items
          .map(
            (item) => {
              'product_id': item.product.id,
              'quantity': item.quantity,
            },
          )
          .toList();

      // Build order payload
      final orderData = {
        'payment_method': paymentMethod,
        'payment_method_title': _getPaymentMethodTitle(paymentMethod),
        'set_paid': paymentMethod == 'cod' ? false : false,
        'customer_id': userId ?? 0, // CRITICAL: Link order to user
        'billing': {
          'first_name': finalFirstName,
          'last_name': finalLastName,
          'address_1': finalAddress,
          'city': finalCity,
          'phone': finalPhone,
          'email': finalEmail,
          'country': 'SA',
        },
        'shipping': {
          'first_name': finalFirstName,
          'last_name': finalLastName,
          'address_1': finalAddress,
          'city': finalCity,
          'country': 'SA',
        },
        'line_items': lineItems,
        'customer_note': notes ?? '',
        'meta_data': [
          {'key': '_payment_type', 'value': paymentType},
        ],
      };

      const fullUrl = 'https://hiraajsahm.com/wp-json/wc/v3/orders';

      final response = await _cleanDio.post(
        fullUrl,
        data: orderData,
        queryParameters: {
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final orderId = response.data['id'];
        final orderKey = response.data['order_key'] ?? '';

        // Clear cart after successful order
        _cartCubit.clearCart();

        emit(CheckoutSuccess(orderId: orderId, orderKey: orderKey));
      } else {
        emit(const CheckoutFailure(message: 'فشل في إنشاء الطلب'));
      }
    } on DioException catch (e) {
      String errorMessage = 'خطأ في الاتصال بالخادم';

      if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }

      emit(CheckoutFailure(message: errorMessage));
    } catch (e) {
      emit(CheckoutFailure(message: e.toString()));
    }
  }

  String _getPaymentMethodTitle(String method) {
    switch (method) {
      case 'cod':
        return 'الدفع عند الاستلام';
      case 'bacs':
        return 'تحويل بنكي';
      case 'online':
        return 'دفع إلكتروني';
      default:
        return 'الدفع عند الاستلام';
    }
  }

  /// Reset to initial state
  void reset() {
    emit(const CheckoutInitial());
  }
}
