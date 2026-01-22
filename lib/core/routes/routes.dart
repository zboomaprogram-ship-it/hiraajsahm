/// Application Routes
class Routes {
  Routes._();

  // Core Routes
  static const String splash = '/';
  static const String onboarding = '/onboarding';

  // Auth Routes
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Main App Routes
  static const String main = '/main';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile'; // Added
  static const String settings = '/settings';
  static const String contactUs = '/contact-us';
  static const String changePassword = '/change-password';
  static const String webView = '/webview';

  // Shop Routes
  static const String products = '/products';
  static const String productDetails = '/product-details';
  static const String categories = '/categories';
  static const String categoryProducts = '/category-products';
  static const String search = '/search';
  static const String requests = '/requests';

  // Cart & Checkout Routes
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderSuccess = '/order-success';
  static const String orders = '/orders';
  static const String orderDetails = '/order-details';

  // Wishlist Routes
  static const String wishlist = '/wishlist';

  // Vendor Routes
  static const String vendorDashboard = '/vendor/dashboard';
  static const String vendorProducts = '/vendor/products';
  static const String vendorAddProduct = '/vendor/add-product';
  static const String addProduct = '/vendor/add-product'; // Alias
  static const String vendorEditProduct = '/vendor/edit-product';
  static const String vendorOrderDetails = '/vendor/order-details';
  static const String vendorOrders = '/vendor/orders';
  static const String vendorStore = '/vendor/store';
  static const String vendorWithdraw = '/vendor/withdraw';
  static const String vendorSubscription = '/vendor/subscription';
  static const String vendorEditProfile = '/vendor/edit-profile'; // Added
  static const String vendorQnA = '/vendor/qna'; // Added
  static const String serviceProviderSettings =
      '/vendor/service-provider'; // Added

  static const String storeDetails = '/store';
  static const String stores = '/stores';

  // Notifications
  static const String notifications = '/notifications';
}
