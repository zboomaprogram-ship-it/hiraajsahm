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
  final bool isSubscription;

  const CheckoutSuccess({
    required this.orderId,
    required this.orderKey,
    this.isSubscription = false,
  });

  @override
  List<Object?> get props => [orderId, orderKey, isSubscription];
}

class CheckoutFailure extends CheckoutState {
  final String message;

  const CheckoutFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State emitted when an online payment order is created and awaiting Telr payment
class CheckoutAwaitingPayment extends CheckoutState {
  final int orderId;
  final String amount;
  final String customerEmail;
  final String customerName;
  final bool isSubscription;

  const CheckoutAwaitingPayment({
    required this.orderId,
    required this.amount,
    required this.customerEmail,
    required this.customerName,
    this.isSubscription = false,
  });

  @override
  List<Object?> get props => [
    orderId,
    amount,
    customerEmail,
    customerName,
    isSubscription,
  ];
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
      
      // Ensure last name is not empty for WooCommerce and Telr (which require it)
      if (finalLastName.trim().isEmpty) {
        finalLastName = finalFirstName.isNotEmpty ? finalFirstName : ' ';
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

      // Extract vendor name if available
      String vendorName = '$finalFirstName $finalLastName'.trim();
      final authState = _authCubit.state;
      if (authState is AuthAuthenticated) {
        final storeName = authState.user.vendorInfo?.storeName;
        if (storeName != null && storeName.isNotEmpty) {
          vendorName = storeName;
        } else if (authState.user.displayName.isNotEmpty) {
          vendorName = authState.user.displayName;
        }
      }

      // Build order payload
      final orderData = {
        'payment_method': paymentMethod,
        'payment_method_title': _getPaymentMethodTitle(paymentMethod),
        'set_paid': paymentMethod == 'online' ? true : false,
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
        'created_via': 'mobile_app',
        'meta_data': [
          {'key': '_payment_type', 'value': paymentType},
          {'key': 'vendor_name', 'value': vendorName},
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

        // Update user profile metadata with new info if provided
        _authCubit.updateUserMetadata(
          firstName: finalFirstName,
          lastName: finalLastName,
          phone: finalPhone,
          city: finalCity,
          location: finalAddress,
        );

        // Determine if this is a subscription by checking cart items
        final cartState = _cartCubit.state;
        bool isSubscription = false;
        if (cartState is CartLoaded) {
          isSubscription = cartState.items.any((item) => 
            item.product.categories.any((cat) => cat.id == 122) || 
            item.product.name.contains('باقة') || 
            item.product.name.contains('اشتراك')
          );
        }

        // If online payment, emit awaiting payment state for Telr
        if (paymentMethod == 'online') {
          final total = cartState is CartLoaded
              ? cartState.total.toStringAsFixed(2)
              : '0.00';
          emit(
            CheckoutAwaitingPayment(
              orderId: orderId,
              amount: total,
              customerEmail: finalEmail,
              customerName: '$finalFirstName $finalLastName'.trim(),
              isSubscription: isSubscription,
            ),
          );
        } else {
          // Clear cart for non-online payments
          _cartCubit.clearCart();
          emit(CheckoutSuccess(orderId: orderId, orderKey: orderKey, isSubscription: isSubscription));
        }
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
      case 'online':
        return 'دفع إلكتروني';
      default:
        return method;
    }
  }

  /// Mark payment as complete after Telr success
  Future<void> completePayment(int orderId, {bool isSubscription = false}) async {
    try {
      final url = 'https://hiraajsahm.com/wp-json/wc/v3/orders/$orderId';
      
      await _cleanDio.put(
        url,
        data: {'status': 'completed'},
        queryParameters: {
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );
    } catch (e) {
      print('CheckoutCubit: Failed to update order status to completed: $e');
    }

    _cartCubit.clearCart();
    emit(CheckoutSuccess(orderId: orderId, orderKey: '', isSubscription: isSubscription));
  }

  /// Mark payment as failed
  void failPayment(String message) {
    emit(CheckoutFailure(message: message));
  }

  /// Reset to initial state
  void reset() {
    emit(const CheckoutInitial());
  }
}
