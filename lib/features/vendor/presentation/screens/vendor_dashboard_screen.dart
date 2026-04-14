import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:hiraajsahm/core/utils/html_utils.dart';
import 'package:hiraajsahm/features/settings/presentation/screens/webview_screen.dart';
import '../../../../core/theme/colors.dart';
import '../cubit/vendor_dashboard_cubit.dart';
import '../../data/models/vendor_stats_model.dart';
import 'vendor_products_tab.dart';
import 'vendor_orders_tab.dart';
import 'vendor_profile_screen.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/iap_service.dart';
import '../../presentation/cubit/vendor_upgrade_cubit.dart';

/// Vendor Dashboard Screen
/// Displays vendor statistics, charts, and quick actions
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  int _currentIndex = 0;
  List<String> _zabayehFeatures = [];

  @override
  void initState() {
    super.initState();
    context.read<VendorDashboardCubit>().loadDashboard();
    _loadZabayehPackInfo();
    _initIAP();
  }

  void _initIAP() {
    if (!Platform.isIOS) return;

    final iapService = di.sl<IAPService>();

    // Handle successful purchase/restoration
    iapService.onPurchaseComplete = (purchaseDetails) {
      if (!mounted) return;
      final authCubit = context.read<AuthCubit>();
      final userId = authCubit.currentUser?.id;

      if (userId != null) {
        context.read<VendorUpgradeCubit>().verifyIapPurchase(
          userId: userId,
          productId: purchaseDetails.productID,
          receiptData: purchaseDetails.verificationData.serverVerificationData,
        );
      }
    };

    iapService.onError = (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في عملية الشراء: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    };
  }

  Future<void> _loadZabayehPackInfo() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://hiraajsahm.com/wp-json/wc/v3/products/29318?consumer_key=ck_78ec6d3f6325ae403400781192045474f592b24a&consumer_secret=cs_0accb11f98ea7516ab4630e521748e73ce3d3b54',
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _zabayehFeatures = HtmlUtils.extractListItems(
              response.data['description'] ?? '',
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading Zabayeh pack info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: _buildCurrentTab(isDark),
      bottomNavigationBar: _buildBottomNavBar(isDark, isTablet),
    );
  }

  Widget _buildCurrentTab(bool isDark) {
    switch (_currentIndex) {
      case 0:
        return _buildOverviewTab(isDark);
      case 1:
        return const VendorProductsTab();
      case 2:
        return const VendorOrdersTab();
      case 3:
        // Use Builder to access context
        return Builder(
          builder: (context) {
            final authState = context.read<AuthCubit>().state;
            if (authState is AuthAuthenticated) {
              return VendorProfileScreen(vendorId: authState.user.id);
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      default:
        return _buildOverviewTab(isDark);
    }
  }

  Widget _buildOverviewTab(bool isDark) {
    return BlocBuilder<VendorDashboardCubit, VendorDashboardState>(
      builder: (context, state) {
        if (state is VendorDashboardLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (state is VendorDashboardError) {
          return _buildErrorState(state.message);
        }

        if (state is VendorDashboardLoaded) {
          return _buildDashboard(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBottomNavBar(bool isDark, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: CurvedNavigationBar(
          index: _currentIndex,
          height: isTablet ? 75 : 65,
          items: [
            Icon(
              Icons.dashboard_rounded,
              size: 26.sp,
              color: _currentIndex == 0
                  ? Colors.white
                  : const Color(0xFF1B4965),
            ),
            Icon(
              Icons.inventory_2_rounded,
              size: 26.sp,
              color: _currentIndex == 1
                  ? Colors.white
                  : const Color(0xFF1B4965),
            ),
            Icon(
              Icons.shopping_bag_rounded,
              size: 26.sp,
              color: _currentIndex == 2
                  ? Colors.white
                  : const Color(0xFF1B4965),
            ),
            Icon(
              Icons.person_rounded,
              size: 26.sp,
              color: _currentIndex == 3
                  ? Colors.white
                  : const Color(0xFF1B4965),
            ),
          ],
          color: isDark ? AppColors.cardDark : Colors.white,
          buttonBackgroundColor: const Color(0xFF1B4965),
          backgroundColor: Colors.transparent,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 300),
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64.sp,
            color: AppColors.error,
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () {
              context.read<VendorDashboardCubit>().loadDashboard();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, VendorDashboardLoaded state) {
    return RefreshIndicator(
      onRefresh: () => context.read<VendorDashboardCubit>().refresh(),
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          _buildAppBar(context),

          // Zabayeh Subscription Prompt
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 200),
              child: _buildZabayehPrompt(context),
            ),
          ),

          // Gold Tier Promotion
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 250),
              duration: const Duration(milliseconds: 500),
              child: _buildGoldTierPromo(context),
            ),
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildStatsGrid(
                context,
                state.stats,
                MediaQuery.of(context).size.width >= 600,
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 24.h)),

          // Orders Overview
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 500),
              child: _buildOrdersOverview(context, state.stats),
            ),
          ),

          // Quick Actions
          // SliverToBoxAdapter(
          //   child: FadeInUp(
          //     delay: const Duration(milliseconds: 400),
          //     duration: const Duration(milliseconds: 500),
          //     child: _buildQuickActions(context),
          //   ),
          // ),
          SliverToBoxAdapter(child: SizedBox(height: 100.h)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 120.h,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        title: Center(
          child: Text(
            'لوحة التحكم',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
        ),
        titlePadding: EdgeInsets.only(left: 16.w, bottom: 16.h, right: 16.w),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'مرحباً',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        context.read<AuthCubit>().state is AuthAuthenticated
                            ? (context.read<AuthCubit>().state
                                      as AuthAuthenticated)
                                  .user
                                  .firstName!
                            : 'البائع',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    VendorStatsModel stats,
    bool isTablet,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statItems = [
      {
        'title': 'صافي المبيعات',
        'value': '\$${stats.netSales.toStringAsFixed(2)}',
        'icon': Icons.attach_money_rounded,
        'color': AppColors.success,
        'gradient': AppColors.successGradient,
      },
      {
        'title': 'الطلبات',
        'value': '${stats.ordersCount}',
        'icon': Icons.shopping_bag_rounded,
        'color': AppColors.primary,
        'gradient': AppColors.primaryGradient,
      },
      {
        'title': 'الاعلانات المباعة',
        'value': '${stats.productsSold}',
        'icon': Icons.inventory_2_rounded,
        'color': AppColors.secondary,
        'gradient': AppColors.secondaryGradient,
      },
      {
        'title': 'إجمالي الاعلانات',
        'value': '${stats.totalProducts}',
        'icon': Icons.category_rounded,
        'color': AppColors.info,
        'gradient': LinearGradient(
          colors: [AppColors.info, AppColors.info.withValues(alpha: 0.7)],
        ),
      },
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 4 : 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: isTablet
              ? 1.5
              : 1.1, // Reduced for more height to avoid overflow
        ),
        itemCount: statItems.length,
        itemBuilder: (context, index) {
          final item = statItems[index];
          return _buildStatCard(
            context,
            title: item['title'] as String,
            value: item['value'] as String,
            icon: item['icon'] as IconData,
            color: item['color'] as Color,
            gradient: item['gradient'] as LinearGradient,
            isDark: isDark,
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: Colors.white, size: 22.sp),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersOverview(BuildContext context, VendorStatsModel stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final orderStatuses = [
      {
        'title': 'معلقة',
        'count': stats.pendingOrders,
        'color': AppColors.warning,
        'icon': Icons.schedule_rounded,
      },
      {
        'title': 'قيد التنفيذ',
        'count': stats.processingOrders,
        'color': AppColors.info,
        'icon': Icons.hourglass_empty_rounded,
      },
      {
        'title': 'مكتملة',
        'count': stats.completedOrders,
        'color': AppColors.success,
        'icon': Icons.check_circle_rounded,
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظرة عامة على الطلبات',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: orderStatuses.map((status) {
              return _buildOrderStatusItem(
                title: status['title'] as String,
                count: status['count'] as int,
                color: status['color'] as Color,
                icon: status['icon'] as IconData,
                isDark: isDark,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusItem({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          width: 60.w,
          height: 60.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: color, size: 28.sp),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          title,
          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildZabayehPrompt(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    final user = authState.user;
    if (user.subscriptionPackId == 29318 || user.hasAlZabayehTier == true) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ترقية إلى باقة الذبائح',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8.h),
                ..._zabayehFeatures.map(
                  (feature) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_zabayehFeatures.isEmpty)
                  Text(
                    'احصل على ظهور مميز وأولوية في تطبيق حراج سهم.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => _handleZabayehSubscription(context, user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: const Text('اشترك الآن'),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Icon(
            Icons.workspace_premium_rounded,
            size: 64.sp,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldTierPromo(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      if (authState.user.subscriptionPackId == 29030) {
        // Already Gold
        return const SizedBox.shrink();
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WebViewScreen(
              title: 'العضويات وميزاتها',
              url:
                  'https://hiraajsahm.com/%d8%a7%d9%84%d8%b9%d8%b6%d9%88%d9%8a%d8%a7%d8%aa-%d9%88%d9%85%d9%8a%d8%b2%d8%a7%d8%aa%d9%87%d8%a7/',
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEEB73E).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        color: AppColors.primary,
                        size: 24.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'العضوية الذهبية (تميز وتألق)',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildPromoFeature('عروض وفيديوهات متميزة واضحة لسلعك'),
                  _buildPromoFeature('وصف دقيق وبيانات موقع صحيحة'),
                  _buildPromoFeature('تخفيضات حصرية على خدمات المعاينة والنقل'),
                  _buildPromoFeature('تصوير احترافية لسلعك من حراج سهم'),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      'اكتشف المزيد',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Icon(
              Icons.military_tech_rounded,
              size: 70.sp,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoFeature(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.primary,
            size: 14.sp,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleZabayehSubscription(
    BuildContext context,
    UserModel user,
  ) async {
    // Only Silver (29028) or Gold (29030) can subscribe
    if (user.subscriptionPackId == 29026 || user.subscriptionPackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'يجب ترقية باقتك إلى الفضية أو الذهبية للاشتراك في الذبائح',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // NATIVE IAP FLOW (iOS)
    if (Platform.isIOS) {
      final iapService = di.sl<IAPService>();

      // Ensure IAP is ready
      if (!iapService.isInitialized || iapService.products.isEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: AppColors.error),
          ),
        );
        await iapService.initialize();
        if (mounted) Navigator.pop(context);
      }

      final updatedProduct = iapService.products.firstWhere(
        (p) => p.id == IAPService.tierZabayeh,
        orElse: () => null as dynamic,
      );

      if (updatedProduct != null) {
        iapService.buyProduct(updatedProduct);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'باقة الذبائح غير متاحة حالياً في متجر التطبيقات، يرجى المحاولة لاحقاً',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    // LEGACY FLOW (Android / Fallback)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.error),
      ),
    );

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://hiraajsahm.com/wp-json/wc/v3/products/29318?consumer_key=ck_78ec6d3f6325ae403400781192045474f592b24a&consumer_secret=cs_0accb11f98ea7516ab4630e521748e73ce3d3b54',
      );

      // ignore: use_build_context_synchronously
      if (mounted) Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        final pack = ProductModel.fromJson(response.data);
        if (mounted) {
          context.read<CartCubit>().clearCart();
          context.read<CartCubit>().addItem(pack);
          AppRouter.navigateTo(context, Routes.checkout);
        }
      } else {
        throw Exception('فشل في تحميل الباقة');
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'حدث خطأ أثناء تحميل الباقة، الرجاء المحاولة لاحقاً.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      {
        'title': 'إضافة اعلان',
        'icon': Icons.add_box_rounded,
        'color': AppColors.primary,
      },
      {
        'title': 'عرض الطلبات',
        'icon': Icons.receipt_long_rounded,
        'color': AppColors.secondary,
      },
      {
        'title': 'تحرير السوق',
        'icon': Icons.store_rounded,
        'color': AppColors.accent,
      },
      {
        'title': 'سحب الأرباح',
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.success,
      },
    ];

    return Container(
      margin: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجراءات سريعة',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 0.8,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _buildActionItem(
                title: action['title'] as String,
                icon: action['icon'] as IconData,
                color: action['color'] as Color,
                isDark: isDark,
                onTap: () {
                  if (action['title'] == 'إضافة اعلان') {
                    Navigator.pushNamed(context, '/vendor/add-product');
                  } else if (action['title'] == 'عرض الطلبات') {
                    setState(() => _currentIndex = 2);
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('قريباً')));
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color, size: 26.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
