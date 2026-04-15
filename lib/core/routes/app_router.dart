import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'routes.dart';
import '../di/injection_container.dart';
import '../theme/colors.dart';

// Core & Auth
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/main/main_layout_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/edit_user_profile_screen.dart';

// Shop & Products
import '../../features/shop/presentation/screens/shop_screen.dart';
import '../../features/shop/presentation/screens/sub_category_screen.dart';
import '../../features/shop/presentation/screens/product_details_screen.dart';
import '../../features/shop/presentation/cubit/products_cubit.dart';
import '../../features/shop/data/models/product_model.dart';
import '../../features/shop/data/models/category_model.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/checkout/presentation/screens/checkout_screen.dart';

// Vendor
import '../../features/vendor/presentation/screens/vendor_dashboard_screen.dart';
import '../../features/vendor/presentation/screens/vendor_order_details_screen.dart';
import '../../features/vendor/data/models/order_model.dart' as vendor_order;
import '../../features/vendor/data/models/vendor_registration_data.dart';
import '../../features/vendor/presentation/screens/add_product_screen.dart';
import '../../features/vendor/presentation/screens/subscription_screen.dart';
import '../../features/vendor/presentation/screens/vendor_profile_screen.dart';
import '../../features/vendor/presentation/screens/edit_vendor_profile_screen.dart';
import '../../features/vendor/presentation/screens/service_provider_settings_screen.dart';
import '../../features/vendor/presentation/screens/vendor_qna_screen.dart';
import '../../features/vendor/presentation/cubit/vendor_upgrade_cubit.dart';

// Orders & Profile
import '../../features/orders/presentation/screens/my_orders_screen.dart';
import '../../features/orders/presentation/screens/order_details_screen.dart';
import '../../features/orders/data/models/order_model.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
// import '../../features/profile/presentation/screens/edit_profile_screen.dart';

// Settings & Requests
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/about_app_screen.dart';
import '../../features/settings/presentation/screens/contact_us_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/settings/presentation/screens/webview_screen.dart';
import '../../features/requests/presentation/cubit/requests_cubit.dart';
import '../../features/requests/presentation/screens/requests_screen.dart';

// Notifications
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';

// Addresses
import '../../features/addresses/presentation/screens/addresses_screen.dart';
import '../../features/addresses/presentation/cubit/addresses_cubit.dart';

/// Application Router
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // --- Core Routes ---
      case Routes.splash:
        return _buildRoute(const SplashScreen(), settings);

      case Routes.onboarding:
        return _buildRoute(const OnboardingScreen(), settings);

      case Routes.main:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialIndex = args?['initialIndex'] as int? ?? 0;
        return _buildRoute(MainLayoutScreen(initialIndex: initialIndex), settings);

      case Routes.home:
        return _buildRoute(const HomeScreen(), settings);

      // --- Auth Routes ---
      case Routes.login:
        return _buildRoute(const LoginScreen(), settings);

      case Routes.register:
        return _buildRoute(const RegisterScreen(), settings);

      // --- Profile Routes ---
      case Routes.profile:
        return _buildRoute(const ProfileScreen(), settings);

      case Routes.editProfile:
        return _buildRoute(const EditUserProfileScreen(), settings);

      // --- Vendor Routes ---

      case Routes.vendorOrderDetails:
        final order = settings.arguments as vendor_order.OrderModel?;
        if (order != null) {
          return _buildRoute(VendorOrderDetailsScreen(order: order), settings);
        }
        return _buildRoute(_buildErrorScreen('Order not found'), settings);

      case Routes.addProduct:
        final product = settings.arguments as ProductModel?;
        return _buildRoute(AddProductScreen(productToEdit: product), settings);

      case Routes.vendorSubscription:
        final vendorData = settings.arguments as VendorRegistrationData?;
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<VendorUpgradeCubit>(),
            child: SubscriptionScreen(vendorRegistrationData: vendorData),
          ),
          settings,
        );

      case Routes.storeDetails:
        final vendorId = settings.arguments as int;
        return _buildRoute(VendorProfileScreen(vendorId: vendorId), settings);

      case Routes.vendorEditProfile:
        final vendorId = settings.arguments as int;
        return _buildRoute(
          EditVendorProfileScreen(vendorId: vendorId),
          settings,
        );

      case Routes.serviceProviderSettings:
        return _buildRoute(const ServiceProviderSettingsScreen(), settings);

      case Routes.vendorQnA:
        return _buildRoute(const VendorQnAScreen(), settings);

      // --- Shop & Product Routes ---
      case Routes.products:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          ShopScreen(
            initialSearch: args?['search'] as String?,
            initialCategoryId: args?['categoryId'] as int?,
            initialCategoryName: args?['categoryName'] as String?,
            hasExplicitCategory: args != null,
          ),
          settings,
        );

      case Routes.subCategories:
        final args = settings.arguments as Map<String, dynamic>;
        return _buildRoute(
          SubCategoryScreen(
            parentCategory: args['parentCategory'] as CategoryModel,
            subCategories: args['subCategories'] as List<CategoryModel>,
          ),
          settings,
        );

      case Routes.productDetails:
        final args = settings.arguments;
        // 1. Normal Navigation (Full Model)
        if (args is ProductModel) {
          return _buildRoute(ProductDetailsScreen(product: args), settings);
        }
        // 2. Deep Linking (ID Only)
        else if (args is int) {
          return _buildRoute(
            FutureBuilder<ProductModel?>(
              future: sl<ProductsCubit>().getProductById(args),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return ProductDetailsScreen(product: snapshot.data!);
                }
                return _buildErrorScreen('تعذر العثور على الإعلان');
              },
            ),
            settings,
          );
        }
        return _buildRoute(_buildErrorScreen('Product not found'), settings);

      // --- Cart & Checkout ---
      case Routes.cart:
        return _buildRoute(const CartScreen(), settings);

      case Routes.checkout:
        return _buildRoute(const CheckoutScreen(), settings);

      case Routes.orderSuccess:
        return _buildRoute(
          _buildPlaceholderScreen('نجاح الطلب', 'تم إنشاء طلبك بنجاح'),
          settings,
        );

      // --- Order Routes ---
      case Routes.orders:
        return _buildRoute(const MyOrdersScreen(), settings);

      case Routes.orderDetails:
        final args = settings.arguments;
        // 1. Normal Navigation (Full Model)
        if (args is OrderModel) {
          return _buildRoute(OrderDetailsScreen(order: args), settings);
        }
        // 2. Deep Linking (ID Only)
        else if (args is int) {
          // Fallback: Redirect to My Orders list so user can select the order
          // This avoids crashes when the notification only sends an ID
          return _buildRoute(const MyOrdersScreen(), settings);
        }
        return _buildRoute(_buildErrorScreen('Order not found'), settings);

      // --- Notifications ---
      case Routes.notifications:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<NotificationsCubit>()..loadNotifications(),
            child: const NotificationsScreen(),
          ),
          settings,
        );

      // --- Requests & Wishlist ---
      case Routes.requests:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<RequestsCubit>(),
            child: const RequestsScreen(),
          ),
          settings,
        );

      case Routes.wishlist:
        return _buildRoute(
          _buildPlaceholderScreen('المفضلة', 'صفحة المفضلة قيد التطوير'),
          settings,
        );

      // --- Addresses ---
      case Routes.addresses:
        return _buildRoute(
          BlocProvider(
            create: (context) => sl<AddressesCubit>()..loadAddresses(),
            child: const AddressesScreen(),
          ),
          settings,
        );

      // --- Settings & Webview ---
      case Routes.settings:
        return _buildRoute(const SettingsScreen(), settings);

      case Routes.aboutApp:
        return _buildRoute(const AboutAppScreen(), settings);

      case Routes.contactUs:
        return _buildRoute(const ContactUsScreen(), settings);

      case Routes.changePassword:
        return _buildRoute(const ChangePasswordScreen(), settings);

      case Routes.webView:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args != null) {
          return _buildRoute(
            WebViewScreen(
              title: args['title'] as String,
              url: args['url'] as String,
            ),
            settings,
          );
        }
        return _buildRoute(_buildErrorScreen('Invalid arguments'), settings);

      default:
        return _buildRoute(
          _buildErrorScreen('No route defined for ${settings.name}'),
          settings,
        );
    }
  }

  // --- Helpers ---

  static Widget _buildPlaceholderScreen(String title, String message) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  static Widget _buildErrorScreen(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('خطأ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static void navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndRemoveUntil(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void goBack(BuildContext context) {
    Navigator.pop(context);
  }

  static void goBackWithResult<T>(BuildContext context, T result) {
    Navigator.pop(context, result);
  }
}
