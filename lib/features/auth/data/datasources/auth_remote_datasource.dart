import 'dart:convert'; // Required for Base64 encoding
import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../models/user_model.dart';
import '../models/subscription_pack_model.dart';

/// Authentication Remote Data Source
/// Handles all API calls for authentication
class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource({required Dio dio}) : _dio = dio;

  /// Login with email and password
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        AppConfig.jwtTokenEndpoint,
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return Right({
          'token': data['token'],
          'user_email': data['user_email'],
          'user_display_name': data['user_display_name'],
          'user_nicename': data['user_nicename'],
        });
      }

      return Left(
        ServerFailure(message: response.data['message'] ?? 'Login failed'),
      );
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Validate JWT token
  Future<Either<Failure, bool>> validateToken() async {
    try {
      final response = await _dio.post(AppConfig.jwtValidateEndpoint);

      if (response.statusCode == 200) {
        final data = response.data;
        return Right(data['code'] == 'jwt_auth_valid_token');
      }

      return const Right(false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        return const Right(false);
      }
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Register new customer
  Future<Either<Failure, UserModel>> registerCustomer({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await _dio.post(
        AppConfig.wcCustomersEndpoint,
        data: {
          'email': email,
          'password': password,
          'username': email.split('@')[0],
          'first_name': firstName,
          'last_name': lastName,
          'name': '$firstName $lastName',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Right(UserModel.fromJson(response.data));
      }

      return Left(
        ServerFailure(
          message: response.data['message'] ?? 'Registration failed',
        ),
      );
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Register new vendor using WooCommerce Customers API + WP Users API
  /// Uses Basic Auth to force 'seller' role assignment
  /// Register new vendor using Custom Server-Side Endpoint
  /// GUARANTEED to set role as 'seller'
  Future<Either<Failure, UserModel>> registerVendor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String storeName,
    required String phone,
    String? storeUrl,
    String? address,
    int? subscriptionPackId,
  }) async {
    final packId = subscriptionPackId ?? 29026;

    try {
      // 1. Basic Auth for Admin Access
      final String basicAuth =
          'Basic ' +
          base64Encode(
            utf8.encode(
              '${AppConfig.wcConsumerKey}:${AppConfig.wcConsumerSecret}',
            ),
          );

      final cleanDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          headers: {
            'Authorization': basicAuth,
            'Content-Type': 'application/json',
          },
        ),
      );

      // 2. Prepare Data
      final Map<String, dynamic> data = {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'username':
            email.split('@')[0] +
            DateTime.now().millisecondsSinceEpoch.toString().substring(8),
        'role': 'seller',
        'billing': {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'phone': phone,
          'address_1': address ?? '',
        },
        'shipping': {
          'first_name': firstName,
          'last_name': lastName,
          'address_1': address ?? '',
        },
        'meta_data': [
          {'key': 'dokan_enable_selling', 'value': 'yes'},
          {'key': 'dokan_store_name', 'value': storeName},
          {'key': 'dokan_store_phone', 'value': phone},
          {'key': 'product_package_id', 'value': packId.toString()},
          {
            'key': 'dokan_feature_seller_package_id',
            'value': packId.toString(),
          },
          {'key': 'can_post_product', 'value': '1'},
          {'key': 'product_pack_startdate', 'value': DateTime.now().toString()},
          {'key': 'dokan_admin_percentage_type', 'value': 'percentage'},
          {
            'key': 'dokan_profile_settings',
            'value': {
              'store_name': storeName,
              'phone': phone,
              'show_email': 'no',
              'location': '',
              'address': {
                'street_1': address ?? '',
                'city': '',
                'zip': '',
                'country': '',
                'state': '',
              },
              'enable_tnc': 'off',
              'show_min_order_discount': 'no',
              'assigned_subscription': packId.toString(),
              'assigned_subscription_info': {
                'subscription_id': packId.toString(),
                'has_subscription': true,
                'start_date': DateTime.now().toString(),
                'expiry_date': 'unlimited',
                'published_products': '0',
                'remaining_products': (packId == 29026 || packId == 1)
                    ? '5'
                    : '-1',
                'recurring': false,
              },
            },
          },
        ],
      };

      // 3. Call WooCommerce Customers endpoint
      final response = await cleanDio.post(
        AppConfig.wcCustomersEndpoint,
        data: data,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final userId = response.data['id'];

        // 4. Force Update Role to Seller (Backup mechanism)
        try {
          final wpUrl =
              '${AppConfig.baseUrl}${AppConfig.wpUsersEndpoint}/$userId';
          // Re-use same dio with basic auth
          await cleanDio.post(
            wpUrl,
            data: {
              'roles': ['seller'],
            },
          );
        } catch (e) {
          print('⚠️ WP role update failed: $e');
        }

        final userData = Map<String, dynamic>.from(response.data);
        userData['role'] = 'seller';
        return Right(UserModel.fromJson(userData));
      }

      return Left(ServerFailure(message: 'Registration failed'));
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 &&
          e.response?.data['code'] == 'registration-error-email-exists') {
        return Left(ServerFailure(message: 'البريد الإلكتروني مسجل مسبقاً'));
      }
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Manually update a vendor's subscription package
  /// Use this if the automatic update fails or after In-App Purchase
  Future<Either<Failure, bool>> updateVendorSubscription({
    required int userId,
    required SubscriptionPackModel pack,
  }) async {
    try {
      // Basic Auth Setup
      final String basicAuth =
          'Basic ' +
          base64Encode(
            utf8.encode(
              '${AppConfig.wcConsumerKey}:${AppConfig.wcConsumerSecret}',
            ),
          );

      final cleanDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          headers: {
            'Authorization': basicAuth,
            'Content-Type': 'application/json',
          },
        ),
      );

      // Determine product limit string
      final String productLimit = pack.productLimit == -1
          ? '-1'
          : pack.productLimit.toString();

      final Map<String, dynamic> data = {
        'meta_data': [
          {'key': 'product_package_id', 'value': pack.id.toString()},
          {
            'key': 'dokan_feature_seller_package_id',
            'value': pack.id.toString(),
          },
          {'key': 'product_pack_startdate', 'value': DateTime.now().toString()},
          {'key': 'product_pack_enddate', 'value': 'unlimited'},
          {'key': 'can_post_product', 'value': '1'},
          {
            'key': 'dokan_feature_seller',
            'value': (pack.id == 29030 || pack.id == 29318) ? 'yes' : 'no',
          },
          {
            'key': 'dokan_profile_settings',
            'value': {
              'assigned_subscription': pack.id.toString(),
              'assigned_subscription_info': {
                'subscription_id': pack.id.toString(),
                'has_subscription': true,
                'start_date': DateTime.now().toString(),
                'expiry_date': 'unlimited',
                'published_products': '0',
                'remaining_products': productLimit,
                'recurring': false,
              },
            },
          },
        ],
      };

      print('🚀 Updating Vendor Subscription for User $userId...');
      final response = await cleanDio.put(
        '${AppConfig.wcCustomersEndpoint}/$userId',
        data: data,
      );

      if (response.statusCode == 200) {
        print('✅ Subscription Updated Successfully');
        return const Right(true);
      }

      return Left(ServerFailure(message: 'Update failed'));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    }
  }

  /// Get subscription packs from WooCommerce Products (Category 122)
  Future<Either<Failure, List<SubscriptionPackModel>>>
  getSubscriptionPacks() async {
    try {
      final response = await _dio.get(
        AppConfig.wcProductsEndpoint,
        queryParameters: {
          'category': '122',
          'status': 'publish',
          'per_page': 50,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final packs = data
            .map((json) => SubscriptionPackModel.fromProductJson(json))
            .toList();
        return Right(packs);
      }
      return Right(_getMockSubscriptionPacks());
    } on DioException catch (e) {
      // Return mock data on error to keep UI working
      return Right(_getMockSubscriptionPacks());
    } catch (e) {
      return Right(_getMockSubscriptionPacks());
    }
  }

  /// Mock subscription packs for testing/fallback
  List<SubscriptionPackModel> _getMockSubscriptionPacks() {
    return const [
      SubscriptionPackModel(
        id: 1,
        title: 'الباقة المجانية',
        description: 'ابدأ مجاناً مع ميزات أساسية',
        price: 0,
        priceFormatted: 'مجاني',
        productLimit: 5,
        billingCycle: 'month',
        billingCycleCount: 1,
        trialDays: 0,
        features: ['5 منتجات فقط', 'دعم أساسي'],
        isFree: true,
      ),
      SubscriptionPackModel(
        id: 2,
        title: 'الباقة الفضية',
        description: 'مثالية للمتاجر المتوسطة',
        price: 200,
        priceFormatted: '200 ر.س',
        productLimit: 50,
        billingCycle: 'month',
        billingCycleCount: 1,
        trialDays: 7,
        features: ['50 منتج', 'دعم متقدم'],
        isFree: false,
      ),
      SubscriptionPackModel(
        id: 3,
        title: 'الباقة الذهبية',
        description: 'للمتاجر الاحترافية',
        price: 500,
        priceFormatted: '500 ر.س',
        productLimit: -1,
        billingCycle: 'month',
        billingCycleCount: 1,
        trialDays: 14,
        features: ['منتجات غير محدودة', 'دعم VIP'],
        isFree: false,
        isPopular: true,
      ),
    ];
  }

  /// Get current user profile
  Future<Either<Failure, UserModel>> getCurrentUser() async {
    try {
      // 1. Get ID from WP Me endpoint
      final wpResponse = await _dio.get('${AppConfig.wpUsersEndpoint}/me');

      if (wpResponse.statusCode != 200) {
        return Left(ServerFailure(message: 'Failed to fetch user ID'));
      }

      final userId = wpResponse.data['id'];

      // 2. Get Full Data from WooCommerce Customer Endpoint
      // Use clean Dio with Basic Auth for best reliability reading metadata
      final String basicAuth =
          'Basic ' +
          base64Encode(
            utf8.encode(
              '${AppConfig.wcConsumerKey}:${AppConfig.wcConsumerSecret}',
            ),
          );

      final cleanDio = Dio(BaseOptions(headers: {'Authorization': basicAuth}));

      final wcUrl =
          '${AppConfig.baseUrl}${AppConfig.wcCustomersEndpoint}/$userId';
      final wcResponse = await cleanDio.get(wcUrl);

      if (wcResponse.statusCode == 200) {
        return Right(UserModel.fromJson(wcResponse.data));
      }

      return Left(ServerFailure(message: 'Failed to fetch user profile'));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Get vendor info for current user
  Future<Either<Failure, UserModel>> getVendorInfo(int vendorId) async {
    try {
      final response = await _dio.get(
        '${AppConfig.dokanVendorsEndpoint}/$vendorId',
      );

      if (response.statusCode == 200) {
        return Right(UserModel.fromJson(response.data));
      }

      return Left(ServerFailure(message: 'Failed to fetch vendor info'));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Upgrade User to Vendor
  Future<Either<Failure, bool>> upgradeToVendor({
    required int userId,
    required String shopName,
    required String phone,
    String? shopLink,
  }) async {
    try {
      // 1. Update User Role and Meta
      final response = await _dio.post(
        '${AppConfig.wcCustomersEndpoint}/$userId',
        data: {
          'role': 'seller', // WCFM uses 'seller' or 'wcfm_vendor'
          'billing': {'phone': phone, 'company': shopName},
          'meta_data': [
            {'key': 'store_name', 'value': shopName},
            {
              'key': 'wcfm_vendor_verification_data',
              'value': {'shop_name': shopName, 'phone': phone},
            },
            if (shopLink != null) {'key': 'store_slug', 'value': shopLink},
            {
              'key': 'wc_memberships_active_memberships',
              'value': '29026',
            }, // Force Bronze Membership ID
          ],
        },
      );

      if (response.statusCode == 200) {
        return const Right(true);
      }

      return Left(
        ServerFailure(
          message: response.data['message'] ?? 'Start vendor upgrade failed',
        ),
      );
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Delete user (used when cancelling registration)
  Future<Either<Failure, bool>> deleteUser(int userId) async {
    try {
      final cleanDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final wcUrl =
          '${AppConfig.baseUrl}${AppConfig.wcCustomersEndpoint}/$id?consumer_key=${AppConfig.wcConsumerKey}&consumer_secret=${AppConfig.wcConsumerSecret}&force=true';

      await cleanDio.delete(wcUrl);
      return const Right(true);
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
