import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/colors.dart';
import '../../data/models/order_model.dart';

/// Order Details Screen
class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
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
          'تفاصيل الطلب #${order.id}',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Card
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildStatusCard(isDark),
            ),
            SizedBox(height: 20.h),

            // Products Section
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 300),
              child: _buildProductsSection(isDark),
            ),
            SizedBox(height: 20.h),

            // Shipping Address
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 300),
              child: _buildAddressSection(isDark),
            ),
            SizedBox(height: 20.h),

            // Payment Info
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 300),
              child: _buildPaymentSection(isDark),
            ),
            SizedBox(height: 20.h),

            // Order Summary
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 300),
              child: _buildSummarySection(isDark),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(order.status),
              color: _getStatusColor(order.status),
              size: 30.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.statusText,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(order.status),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'تاريخ الطلب: ${order.formattedDate}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(bool isDark) {
    return _buildSection(
      title: 'المنتجات',
      icon: Icons.shopping_bag_outlined,
      isDark: isDark,
      child: Column(
        children: order.lineItems
            .map((item) => _buildProductItem(item, isDark))
            .toList(),
      ),
    );
  }

  Widget _buildProductItem(LineItem item, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 60.w,
                    height: 60.w,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          SizedBox(width: 16.w),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'الكمية: ${item.quantity}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Price
          Text(
            '${item.total} ر.س',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60.w,
      height: 60.w,
      color: AppColors.surface,
      child: Icon(Icons.image, color: AppColors.textSecondary),
    );
  }

  Widget _buildAddressSection(bool isDark) {
    final shipping = order.shipping;
    final hasShipping = shipping.fullAddress.isNotEmpty;
    final address = hasShipping ? shipping : order.billing;

    return _buildSection(
      title: 'عنوان التوصيل',
      icon: Icons.location_on_outlined,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 18.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                hasShipping ? shipping.fullName : order.billing.fullName,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.location_city_outlined,
                size: 18.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  hasShipping
                      ? shipping.fullAddress
                      : order.billing.fullAddress,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 18.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                order.billing.phone,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(bool isDark) {
    return _buildSection(
      title: 'طريقة الدفع',
      icon: Icons.payment_outlined,
      isDark: isDark,
      child: Row(
        children: [
          Icon(
            _getPaymentIcon(order.paymentMethod),
            size: 24.sp,
            color: AppColors.primary,
          ),
          SizedBox(width: 12.w),
          Text(
            order.paymentMethodTitle.isNotEmpty
                ? order.paymentMethodTitle
                : 'غير محدد',
            style: TextStyle(
              fontSize: 15.sp,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(bool isDark) {
    return _buildSection(
      title: 'ملخص الطلب',
      icon: Icons.receipt_outlined,
      isDark: isDark,
      child: Column(
        children: [
          _buildSummaryRow('عدد المنتجات', '${order.lineItems.length}', isDark),
          SizedBox(height: 12.h),
          Divider(color: AppColors.border),
          SizedBox(height: 12.h),
          _buildSummaryRow(
            'الإجمالي',
            '${order.total} ر.س',
            isDark,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    bool isDark, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16.sp : 14.sp,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20.sp : 14.sp,
            fontWeight: FontWeight.bold,
            color: isTotal
                ? AppColors.secondary
                : (isDark ? AppColors.textLight : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          child,
        ],
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
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'processing':
        return Icons.sync_rounded;
      case 'on-hold':
        return Icons.pause_circle_outline_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'cod':
        return Icons.payments_outlined;
      case 'bacs':
        return Icons.account_balance_outlined;
      default:
        return Icons.payment_outlined;
    }
  }
}
