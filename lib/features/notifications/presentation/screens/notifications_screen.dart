import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../data/models/notification_model.dart';
import '../cubit/notifications_cubit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(
          'الإشعارات',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 24.sp),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                context.read<NotificationsCubit>().markAllAsRead();
              } else if (value == 'clear_all') {
                _showClearConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all),
                    SizedBox(width: 8),
                    Text('تحديد الكل كمقروء'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('مسح الكل', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.sp,
                    color: AppColors.error,
                  ),
                  SizedBox(height: 16.h),
                  Text(state.message),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<NotificationsCubit>().loadNotifications(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state is NotificationsLoaded) {
            if (state.notifications.isEmpty) {
              return _buildEmptyState(isDark);
            }
            return _buildNotificationsList(state.notifications, isDark);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.surfaceDark : AppColors.surface),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'ستظهر الإشعارات هنا عند وصولها',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    List<NotificationModel> notifications,
    bool isDark,
  ) {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification, isDark);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, bool isDark) {
    return InkWell(
      onTap: () => _handleNotificationTap(notification),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: notification.isRead
              ? (isDark ? AppColors.surfaceDark : Colors.white)
              : (isDark
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: notification.isRead
                ? AppColors.border
                : AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: _getIconColor(notification.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                _getIcon(notification.type),
                color: _getIconColor(notification.type),
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    timeago.format(notification.timestamp, locale: 'ar'),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'product':
        return Icons.inventory_2_outlined;
      case 'question':
        return Icons.help_outline;
      case 'review':
        return Icons.star_outline;
      case 'payment':
        return Icons.payments_outlined;
      case 'promo':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'order':
        return AppColors.primary;
      case 'product':
        return AppColors.info;
      case 'question':
        return AppColors.warning;
      case 'review':
        return Colors.amber;
      case 'payment':
        return AppColors.success;
      case 'promo':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read
    context.read<NotificationsCubit>().markAsRead(notification.id);

    // Handle deep linking
    final data = notification.data;
    if (data != null) {
      if (data.containsKey('order_id')) {
        // Navigate to order details
        // AppRouter.pushNamed(context, '/order-details', arguments: data['order_id']);
      } else if (data.containsKey('product_id')) {
        // Navigate to product details
        // AppRouter.pushNamed(context, '/product-details', arguments: data['product_id']);
      }
    }
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح جميع الإشعارات'),
        content: const Text('هل أنت متأكد من مسح جميع الإشعارات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<NotificationsCubit>().clearAll();
              Navigator.pop(ctx);
            },
            child: const Text('مسح', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
