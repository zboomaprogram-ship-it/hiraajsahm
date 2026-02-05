import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ✅ Correct Import for Global Navigator Key
import 'core/services/notification_service.dart';

import 'core/routes/app_router.dart';
import 'core/routes/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/cubit/theme_cubit.dart';
import 'core/di/injection_container.dart' as di;
import 'core/localization/localization_manager.dart';

// Feature Imports
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/vendor/presentation/cubit/vendor_dashboard_cubit.dart';
import 'features/shop/presentation/cubit/products_cubit.dart';
import 'features/shop/presentation/cubit/categories_cubit.dart';
import 'features/shop/presentation/cubit/qna_cubit.dart';
import 'features/cart/presentation/cubit/cart_cubit.dart';
import 'features/home/cubit/home_content_cubit.dart';
import 'features/services/presentation/cubit/services_cubit.dart';
import 'features/vendor/presentation/cubit/vendor_products_cubit.dart';
import 'features/vendor/presentation/cubit/vendor_orders_cubit.dart';
import 'features/notifications/presentation/cubit/notifications_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize dependency injection
  await di.init();

  // ✅ Initialize OneSignal Notifications
  await NotificationService().initializeOneSignal();

  runApp(
    EasyLocalization(
      supportedLocales: LocalizationManager.supportedLocales,
      path: LocalizationManager.translationsPath,
      fallbackLocale: LocalizationManager.fallbackLocale,
      startLocale: LocalizationManager.fallbackLocale,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Theme Cubit
        BlocProvider<ThemeCubit>(
          create: (_) => di.sl<ThemeCubit>()..loadTheme(),
        ),
        // Auth Cubit
        BlocProvider<AuthCubit>(create: (_) => di.sl<AuthCubit>()),

        // Vendor Cubits
        BlocProvider<VendorDashboardCubit>(
          create: (_) => di.sl<VendorDashboardCubit>(),
        ),
        BlocProvider<VendorProductsCubit>(
          create: (_) => di.sl<VendorProductsCubit>(),
        ),
        BlocProvider<VendorOrdersCubit>(
          create: (_) => di.sl<VendorOrdersCubit>(),
        ),

        // Shop & Content Cubits
        BlocProvider<ProductsCubit>(create: (_) => di.sl<ProductsCubit>()),
        BlocProvider<CategoriesCubit>(create: (_) => CategoriesCubit()),
        BlocProvider<HomeContentCubit>(create: (_) => HomeContentCubit()),
        BlocProvider<CartCubit>(create: (_) => di.sl<CartCubit>()),
        BlocProvider<QnACubit>(create: (_) => di.sl<QnACubit>()),
        BlocProvider<ServicesCubit>(create: (_) => ServicesCubit()),

        // ✅ Notifications Cubit (Loaded on startup)
        BlocProvider<NotificationsCubit>(
          create: (_) => NotificationsCubit()..loadNotifications(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                title: 'Hiraaj Sahm - هراج سهم',
                debugShowCheckedModeBanner: false,

                // Theme Configuration
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeState.themeMode,

                // ✅ Global Navigator Key (From NotificationService)
                navigatorKey: navigatorKey,

                initialRoute: Routes.splash,
                onGenerateRoute: AppRouter.generateRoute,

                // Localization - Force RTL with Arabic
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar')],
                localizationsDelegates: [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  ...context.localizationDelegates,
                ],

                // Scroll behavior for smoother scrolling
                scrollBehavior: const MaterialScrollBehavior().copyWith(
                  physics: const BouncingScrollPhysics(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
