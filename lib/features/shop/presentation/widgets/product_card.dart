import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../data/models/product_model.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';

/// Premium Unified Product Card
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isTablet;

  const ProductCard({
    super.key,
    required this.product,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOutOfStock = product.stockStatus == 'outofstock' || product.stockQuantity == 0;
    
    // Determine if this is a Zabayeh product (category 78)
    final isZabayeh = product.categories.any((c) => c.id == 78);

    return GestureDetector(
      onTap: () => AppRouter.navigateTo(
        context,
        Routes.productDetails,
        arguments: product,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: isZabayeh ? Border.all(color: AppColors.error.withOpacity(0.3), width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                    child: product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => _buildPlaceholder(isDark),
                            errorWidget: (context, url, error) => _buildPlaceholder(isDark),
                          )
                        : _buildPlaceholder(isDark),
                  ),
                  
                  // Discount Badge
                  if (product.hasDiscount)
                    Positioned(
                      top: 10.h,
                      left: 10.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '${product.discountPercentage.toStringAsFixed(0)}%-',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Zabayeh Badge
                  if (isZabayeh)
                    Positioned(
                      top: 10.h,
                      right: 10.w,
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                          ],
                        ),
                        child: Icon(Icons.restaurant_menu, color: AppColors.error, size: 16.sp),
                      ),
                    ),

                  // Verification Badge
                  if (product.isVendorVerified)
                    Positioned(
                      bottom: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.verified, color: Colors.blue, size: 18.sp),
                      ),
                    ),

                  // Locked/Status Banner
                  if (product.isLocked)
                    Positioned(
                      top: 15.h,
                      left: -25.w,
                      child: Transform.rotate(
                        angle: -0.785398, // -45 degrees
                        child: Container(
                          width: 100.w,
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            'قيد المعاينة',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textLight : AppColors.textPrimary,
                      ),
                    ),
                    
                    const Spacer(),

                    // Location Info
                    if (product.productRegion != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 12.sp, color: AppColors.textSecondary),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                '${product.productRegion} ${product.productCity != null ? "• ${product.productCity}" : ""}',
                                style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Price and Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.hasDiscount)
                                Text(
                                  '${product.regularPrice} ر.س',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.textSecondary,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                '${product.price} ر.س',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Add to Cart Button
                        GestureDetector(
                          onTap: isOutOfStock
                              ? null
                              : () {
                                  context.read<CartCubit>().addItem(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('تمت الإضافة إلى طلباتي'),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                          child: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: isOutOfStock ? Colors.grey[400] : AppColors.primary,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: isOutOfStock ? null : [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isOutOfStock ? Icons.remove_shopping_cart_outlined : Icons.add_shopping_cart_rounded,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.surfaceVariantDark : AppColors.surface,
      child: Center(
        child: Icon(Icons.pets, color: AppColors.textSecondary, size: 32.sp),
      ),
    );
  }
}
