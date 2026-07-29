import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../data/models/product_model.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/favorites_service.dart';

/// Premium Unified Product Card
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isTablet;

  const ProductCard({super.key, required this.product, this.isTablet = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOutOfStock =
        product.stockStatus == 'outofstock' || product.stockQuantity == 0;

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
          border: isZabayeh
              ? Border.all(color: AppColors.error.withOpacity(0.3), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 11,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20.r),
                    ),
                    child: product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: isTablet ? 900 : 600,
                            maxWidthDiskCache: 1200,
                            placeholder: (context, url) =>
                                _buildPlaceholder(isDark),
                            errorWidget: (context, url, error) =>
                                _buildPlaceholder(isDark),
                          )
                        : _buildPlaceholder(isDark),
                  ),

                  // Discount Badge
                  if (product.hasDiscount)
                    Positioned(
                      top: 10.h,
                      left: 10.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
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
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.restaurant_menu,
                          color: AppColors.error,
                          size: 16.sp,
                        ),
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
                        child: Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 18.sp,
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 8.h,
                    left: 8.w,
                    child: ValueListenableBuilder<Set<int>>(
                      valueListenable: FavoritesService.instance.productIds,
                      builder: (context, favorites, _) {
                        final selected = favorites.contains(product.id);
                        return Material(
                          color: Colors.black.withValues(alpha: .42),
                          borderRadius: BorderRadius.circular(11.r),
                          child: IconButton(
                            constraints: BoxConstraints.tightFor(
                              width: 34.w,
                              height: 34.w,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.standard,
                            tooltip: selected
                                ? 'إزالة من المفضلة'
                                : 'إضافة إلى المفضلة',
                            onPressed: () => FavoritesService.instance.toggle(
                              sl<Dio>(),
                              product.id,
                            ),
                            icon: Icon(
                              selected
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: selected ? Colors.redAccent : Colors.white,
                              size: 20.sp,
                            ),
                          ),
                        );
                      },
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
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'قيد المعاينة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details Section
            Expanded(
              flex: 9,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    SizedBox(
                      height: isTablet ? 29.h : 37.h,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTablet ? 9.sp : 14.sp,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),

                    // Location Info
                    SizedBox(
                      height: 16.h,
                      child: product.productRegion != null
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 11.sp,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    '${product.productRegion} ${product.productCity != null ? "• ${product.productCity}" : ""}',
                                    style: TextStyle(
                                      fontSize: isTablet ? 8.sp : 10.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Price and Action Row
                    SizedBox(
                      height: 30.h,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Price
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.bottomStart,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.bottomStart,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (product.hasDiscount)
                                      Text(
                                        '${product.regularPrice} ر.س',
                                        style: TextStyle(
                                          fontSize: isTablet ? 8.sp : 11.sp,
                                          color: AppColors.textSecondary,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                    Text(
                                      '${product.price.trim().isEmpty ? '0' : product.price} ر.س',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: isTablet ? 12.sp : 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Open the listing to contact the vendor.
                          GestureDetector(
                            onTap: isOutOfStock
                                ? null
                                : () => AppRouter.navigateTo(
                                    context,
                                    Routes.productDetails,
                                    arguments: product,
                                  ),
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: isOutOfStock
                                    ? Colors.grey[400]
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(12.r),
                                boxShadow: isOutOfStock
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Icon(
                                isOutOfStock
                                    ? Icons.block_outlined
                                    : Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: isTablet ? 11.sp : 17.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
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
