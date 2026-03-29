import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/colors.dart';
import '../../data/models/product_model.dart';

class ProductQRCard extends StatelessWidget {
  final ProductModel product;

  const ProductQRCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQr = product.qrCodeUrl != null && product.qrCodeUrl!.isNotEmpty;

    if (!hasQr) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رمز QR للسلعه',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'امسح الرمز للوصول السريع للسلعه',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: CachedNetworkImage(
              imageUrl: product.qrCodeUrl!,
              height: 150.h,
              width: 150.h,
              placeholder: (context, url) => SizedBox(
                height: 150.h,
                width: 150.h,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.qr_code_2_rounded,
                size: 100.sp,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
