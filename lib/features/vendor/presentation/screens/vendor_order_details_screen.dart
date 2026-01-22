import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../data/models/order_model.dart';

class VendorOrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const VendorOrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(order.dateCreated);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text('تفاصيل الطلب #${order.id}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Status Card
            Container(
              padding: EdgeInsets.all(16.w),
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
              child: Column(
                children: [
                  _buildDetailRow(
                    'رقم الطلب',
                    '#${order.id}',
                    isDark,
                    isBold: true,
                  ),
                  const Divider(),
                  _buildDetailRow('تاريخ الطلب', dateStr, isDark),
                  const Divider(),
                  _buildDetailRow(
                    'حالة الطلب',
                    _getStatusLabel(order.status),
                    isDark,
                    valueColor: _getStatusColor(order.status),
                    isBold: true,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'طريقة الدفع',
                    'الدفع عند الاستلام', // Placeholder or add to model
                    isDark,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Products List
            Container(
              padding: EdgeInsets.all(16.w),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المنتجات',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textLight : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ...order.items.map((item) => _buildProductItem(item, isDark)),
                  const Divider(),
                  _buildDetailRow(
                    'الإجمالي',
                    '${order.total} ${order.currency}',
                    isDark,
                    isBold: true,
                    valueColor: AppColors.secondary,
                    textSize: 18.sp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isBold = false,
    Color? valueColor,
    double? textSize,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: textSize ?? 14.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ??
                  (isDark ? AppColors.textLight : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(OrderItemModel item, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'x${item.quantity}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${item.total} SAR',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    final s = status.toLowerCase().replaceAll('wc-', '');
    if (s == 'completed') return 'مكتمل';
    if (s == 'pending') return 'معلق';
    if (s == 'processing') return 'قيد التنفيذ';
    if (s == 'cancelled' || s == 'failed') return 'ملغى';
    if (s == 'refunded') return 'مسترجع';
    return status;
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase().replaceAll('wc-', '');
    if (s == 'completed') return AppColors.success;
    if (s == 'pending') return AppColors.warning;
    if (s == 'processing') return AppColors.info;
    if (s == 'cancelled' || s == 'failed') return AppColors.error;
    if (s == 'refunded') return Colors.purple;
    return AppColors.textSecondary;
  }
}
