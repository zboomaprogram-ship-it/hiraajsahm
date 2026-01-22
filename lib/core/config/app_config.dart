/// Application Configuration - Hiraaj Sahm E-commerce
class AppConfig {
  AppConfig._();

  // ============ APP INFO ============
  static const String appName = 'Hiraaj Sahm';
  static const String appNameAr = 'هراج سهم';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // // ============ DEVELOPER INFO ============
  // static const String developerName = 'Abdullah Essam';
  // static const String developerGithub = 'https://github.com/AbdalluhEssam';
  // static const String developerProfile = 'abdalluh-essam.com';
  // static const String developerLinkedIn =
  //     'https://www.linkedin.com/in/abdalluh-essam';
  // static const String developerEmail = 'contact@abdalluh-essam.com';

  // ============ ENVIRONMENT ============
  static const bool isProduction = false;
  static const bool enableLogging = true;

  // ============ API CONFIGURATION ============
  static const String productionBaseUrl = 'https://hiraajsahm.com/wp-json';
  static const String developmentBaseUrl = 'https://hiraajsahm.com/wp-json';

  static String get baseUrl {
    return isProduction ? productionBaseUrl : developmentBaseUrl;
  }

  // ============ API ENDPOINTS ============
  static const String jwtTokenEndpoint = '/jwt-auth/v1/token';
  static const String jwtValidateEndpoint = '/jwt-auth/v1/token/validate';

  // WordPress/WooCommerce Endpoints
  static const String wcProductsEndpoint = '/wc/v3/products';
  static const String wcCategoriesEndpoint = '/wc/v3/products/categories';
  static const String wcOrdersEndpoint = '/wc/v3/orders';
  static const String wcCustomersEndpoint = '/wc/v3/customers';
  static const String wpUsersEndpoint = '/wp/v2/users';

  // Dokan Endpoints
  static const String dokanVendorsEndpoint = '/dokan/v1/vendors';
  static const String dokanProductsEndpoint = '/dokan/v1/products';
  static const String dokanOrdersEndpoint = '/dokan/v1/orders';
  static const String dokanReportsEndpoint = '/dokan/v1/reports/summary';
  static const String dokanSubscriptionPacksEndpoint =
      '/dokan/v1/subscription-packs';
  static const String dokanWithdrawEndpoint = '/dokan/v1/withdraw';
  static const String dokanStoreEndpoint = '/dokan/v1/stores';

  // ============ WC API CREDENTIALS ============
  // These should be environment variables in production
  static const String wcConsumerKey =
      'ck_78ec6d3f6325ae403400781192045474f592b24a';
  static const String wcConsumerSecret =
      'cs_0accb11f98ea7516ab4630e521748e73ce3d3b54';

  // ============ STORAGE KEYS ============
  static const String tokenKey = 'jwt_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String userDisplayNameKey = 'user_display_name';
  static const String userRoleKey = 'user_role';
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'locale';
  static const String onboardingKey = 'onboarding_complete';

  // ============ PAGINATION ============
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ============ TIMEOUTS ============
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration cacheTimeout = Duration(hours: 1);

  // ============ USER ROLES ============
  static const String roleCustomer = 'customer';
  static const String roleVendor = 'seller';
  static const String roleAdmin = 'administrator';
}
