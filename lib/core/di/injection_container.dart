import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../network/network_info.dart';
import '../api/api_interceptors.dart';
import '../config/app_config.dart';
import '../services/storage_service.dart';
import '../theme/cubit/theme_cubit.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/vendor/presentation/cubit/vendor_dashboard_cubit.dart';
import '../../features/shop/presentation/cubit/products_cubit.dart';
import '../../features/shop/presentation/cubit/product_details_cubit.dart';
import '../../features/cart/presentation/cubit/cart_cubit.dart';
import '../../features/vendor/presentation/cubit/vendor_products_cubit.dart';
import '../../features/vendor/presentation/cubit/vendor_orders_cubit.dart';
import '../../features/vendor/presentation/cubit/vendor_profile_cubit.dart';
import '../../features/requests/presentation/cubit/requests_cubit.dart';
import '../../features/requests/data/services/requests_service.dart';
import '../../features/vendor/presentation/cubit/add_product_cubit.dart';
import '../../features/shop/presentation/cubit/qna_cubit.dart';
// ✅ 1. Add Import
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';

final sl = GetIt.instance;

/// Initialize Dependency Injection
Future<void> init() async {
  // ============ EXTERNAL SERVICES ============

  // Shared Preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Secure Storage
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  sl.registerLazySingleton(() => secureStorage);

  // Initialize Hive
  await Hive.initFlutter();

  // Internet Connection Checker
  sl.registerLazySingleton(() => InternetConnectionChecker.createInstance());

  // ============ CORE SERVICES ============

  // Network Info
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // Storage Service
  sl.registerLazySingleton(
    () => StorageService(
      secureStorage: sl<FlutterSecureStorage>(),
      preferences: sl<SharedPreferences>(),
    ),
  );

  // ============ DIO CLIENT ============

  sl.registerLazySingleton(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    dio.interceptors.add(ApiInterceptor());
    dio.interceptors.add(AuthInterceptor(storageService: sl<StorageService>()));
    dio.interceptors.add(RetryInterceptor(dio: dio));

    // Add pretty logger in debug mode
    if (AppConfig.enableLogging) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: false,
          responseHeader: true,
          responseBody: false,
        ),
      );
    }

    return dio;
  });

  // ============ CUBITS ============

  // Theme Cubit
  sl.registerFactory(() => ThemeCubit(storageService: sl<StorageService>()));

  // Auth Cubit
  sl.registerFactory(
    () => AuthCubit(
      authRemoteDataSource: sl<AuthRemoteDataSource>(),
      storageService: sl<StorageService>(),
    ),
  );

  // Vendor Dashboard Cubit
  sl.registerFactory(() => VendorDashboardCubit(dio: sl<Dio>()));
  sl.registerFactory(() => VendorProductsCubit(dio: sl<Dio>()));
  sl.registerFactory(() => VendorOrdersCubit(dio: sl<Dio>()));
  sl.registerFactory(() => VendorProfileCubit(dio: sl<Dio>()));

  // Requests Cubit
  sl.registerFactory(() => RequestsService(sl<Dio>()));
  sl.registerFactory(
    () => RequestsCubit(requestsService: sl<RequestsService>()),
  );

  // Profile Cubit
  sl.registerFactory(() => ProfileCubit(dio: sl<Dio>()));

  // Products Cubit
  sl.registerFactory(() => ProductsCubit(dio: sl<Dio>()));
  sl.registerFactory(() => ProductDetailsCubit(dio: sl<Dio>()));

  // Cart Cubit
  sl.registerLazySingleton(() => CartCubit());

  // Add Product Cubit
  sl.registerFactory(() => AddProductCubit());

  // QnA Cubit
  sl.registerFactory(
    () => QnACubit(dio: sl<Dio>(), storageService: sl<StorageService>()),
  );

  // ✅ 2. Register NotificationsCubit
  // Note: If your NotificationsCubit takes arguments (like Dio), add them here:
  // e.g., () => NotificationsCubit(dio: sl<Dio>())
  sl.registerFactory(() => NotificationsCubit());

  // ============ DATA SOURCES ============

  // Auth Remote Data Source
  sl.registerLazySingleton(() => AuthRemoteDataSource(dio: sl<Dio>()));
}

/// Reset all singletons
Future<void> reset() async {
  await sl.reset();
}
