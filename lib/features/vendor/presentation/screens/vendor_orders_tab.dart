import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hiraajsahm/core/routes/routes.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../data/models/order_model.dart';
import '../cubit/vendor_orders_cubit.dart';

class VendorOrdersTab extends StatefulWidget {
  const VendorOrdersTab({super.key});

  @override
  State<VendorOrdersTab> createState() => _VendorOrdersTabState();
}

class _VendorOrdersTabState extends State<VendorOrdersTab> {
  @override
  void initState() {
    super.initState();
    context.read<VendorOrdersCubit>().loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('الطلبات'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.read<VendorOrdersCubit>().loadOrders(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocBuilder<VendorOrdersCubit, VendorOrdersState>(
        builder: (context, state) {
          if (state is VendorOrdersLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is VendorOrdersError) {
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
                    state.message,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<VendorOrdersCubit>().loadOrders(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state is VendorOrdersLoaded) {
            final orders = state.orders;

            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80.sp,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'لا توجد طلبات بعد',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<VendorOrdersCubit>().loadOrders(),
              color: AppColors.primary,
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: orders.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  return _buildOrderItem(context, orders[index], isDark);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderModel order, bool isDark) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(order.dateCreated);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12.w),
        leading: Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: AppColors.primary,
            size: 24.sp,
          ),
        ),
        title: Row(
          children: [
            Text(
              'طلب #${order.id}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${order.total} ${order.currency}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14.sp,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 4.w),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(order.status),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              // Assuming logic for item count if needed, logic is in OrderModel
              '${order.itemCount} منتجات',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            Routes.vendorOrderDetails,
            arguments: order,
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label = status;
    Color color = AppColors.textSecondary;

    // Normalize status string
    final s = status.toLowerCase().replaceAll('wc-', '');

    if (s == 'completed') {
      label = 'مكتمل';
      color = AppColors.success;
    } else if (s == 'pending') {
      label = 'معلق';
      color = AppColors.warning;
    } else if (s == 'processing') {
      label = 'قيد التنفيذ';
      color = AppColors.info;
    } else if (s == 'cancelled' || s == 'failed') {
      label = 'ملغى';
      color = AppColors.error;
    } else if (s == 'refunded') {
      label = 'مسترجع';
      color = Colors.purple;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
