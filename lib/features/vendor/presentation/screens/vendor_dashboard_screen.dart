import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../../../../core/theme/colors.dart';
import '../cubit/vendor_dashboard_cubit.dart';
import '../../data/models/vendor_stats_model.dart';
import 'vendor_products_tab.dart';
import 'vendor_orders_tab.dart';
// import 'vendor_settings_tab.dart'; // Replaced by profile
import 'vendor_profile_screen.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Vendor Dashboard Screen
/// Displays vendor statistics, charts, and quick actions
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<VendorDashboardCubit>().loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: _buildCurrentTab(isDark),
      bottomNavigationBar: _buildBottomNavBar(isDark),
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

  Widget _buildBottomNavBar(bool isDark) {
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
      child: CurvedNavigationBar(
        index: _currentIndex,
        height: 65,
        items: [
          Icon(
            Icons.dashboard_rounded,
            size: 26.sp,
            color: _currentIndex == 0 ? Colors.white : const Color(0xFF1B4965),
          ),
          Icon(
            Icons.inventory_2_rounded,
            size: 26.sp,
            color: _currentIndex == 1 ? Colors.white : const Color(0xFF1B4965),
          ),
          Icon(
            Icons.shopping_bag_rounded,
            size: 26.sp,
            color: _currentIndex == 2 ? Colors.white : const Color(0xFF1B4965),
          ),
          Icon(
            Icons.person_rounded,
            size: 26.sp,
            color: _currentIndex == 3 ? Colors.white : const Color(0xFF1B4965),
          ),
        ],
        color: isDark ? AppColors.cardDark : Colors.white,
        buttonBackgroundColor: const Color(0xFF1B4965),
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) => setState(() => _currentIndex = index),
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

          // Stats Cards
          SliverToBoxAdapter(
            child: FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildStatsGrid(context, state.stats),
            ),
          ),

          // Orders Overview
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 500),
              child: _buildOrdersOverview(context, state.stats),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 500),
              child: _buildQuickActions(context),
            ),
          ),

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
              fontSize: 18.sp,
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

  Widget _buildStatsGrid(BuildContext context, VendorStatsModel stats) {
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
        'title': 'المنتجات المباعة',
        'value': '${stats.productsSold}',
        'icon': Icons.inventory_2_rounded,
        'color': AppColors.secondary,
        'gradient': AppColors.secondaryGradient,
      },
      {
        'title': 'إجمالي المنتجات',
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
          crossAxisCount: 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 1.1, // Reduced for more height to avoid overflow
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

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      {
        'title': 'إضافة منتج',
        'icon': Icons.add_box_rounded,
        'color': AppColors.primary,
      },
      {
        'title': 'عرض الطلبات',
        'icon': Icons.receipt_long_rounded,
        'color': AppColors.secondary,
      },
      {
        'title': 'تحرير المتجر',
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
                  if (action['title'] == 'إضافة منتج') {
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
