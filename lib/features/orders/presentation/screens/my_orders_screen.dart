import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../cubit/orders_cubit.dart';
import '../../data/models/order_model.dart';

/// My Orders Screen with Current/History tabs
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late OrdersCubit _ordersCubit;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ordersCubit = OrdersCubit();
    _ordersCubit.loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _ordersCubit,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.background,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          title: Text(
            'طلباتي',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'الطلبات الحالية'),
              Tab(text: 'السجل'),
            ],
          ),
        ),
        body: BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) {
            if (state is OrdersLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is OrdersError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64.sp,
                        color: AppColors.error,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        onPressed: () => _ordersCubit.loadOrders(),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is OrdersLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  // Current Orders Tab
                  _buildOrdersList(
                    state.currentOrders,
                    isDark,
                    isEmpty: 'لا توجد طلبات حالية',
                  ),
                  // History Tab
                  _buildOrdersList(
                    state.historyOrders,
                    isDark,
                    isEmpty: 'لا توجد طلبات سابقة',
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    List<OrderModel> orders,
    bool isDark, {
    required String isEmpty,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64.sp,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16.h),
            Text(
              isEmpty,
              style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _ordersCubit.loadOrders(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: orders.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          return FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: index * 50),
            child: _buildOrderCard(orders[index], isDark),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isDark) {
    return GestureDetector(
      onTap: () {
        AppRouter.navigateTo(context, Routes.orderDetails, arguments: order);
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.id}',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    order.statusText,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Date
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16.sp,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8.w),
                Text(
                  order.formattedDate,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Items count
            Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 16.sp,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${order.lineItems.length} منتجات',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Divider
            Divider(color: AppColors.border, height: 1),
            SizedBox(height: 12.h),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${order.total} ر.س',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.info;
      case 'on-hold':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'refunded':
        return AppColors.accent;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
