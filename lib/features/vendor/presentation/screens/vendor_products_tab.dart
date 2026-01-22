import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/routes/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../shop/data/models/product_model.dart';
import '../cubit/vendor_products_cubit.dart';
import 'add_product_screen.dart';

class VendorProductsTab extends StatefulWidget {
  const VendorProductsTab({super.key});

  @override
  State<VendorProductsTab> createState() => _VendorProductsTabState();
}

class _VendorProductsTabState extends State<VendorProductsTab> {
  @override
  void initState() {
    super.initState();
    // Load products when tab is accessed
    context.read<VendorProductsCubit>().loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('منتجاتي'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.read<VendorProductsCubit>().loadProducts(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vendor_add_product_fab',
        onPressed: () {
          Navigator.pushNamed(context, Routes.addProduct).then((_) {
            // Refresh list after returning from add product
            if (mounted) {
              context.read<VendorProductsCubit>().loadProducts();
            }
          });
        },
        label: const Text('إضافة منتج'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<VendorProductsCubit, VendorProductsState>(
        builder: (context, state) {
          if (state is VendorProductsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is VendorProductsError) {
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
                        context.read<VendorProductsCubit>().loadProducts(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state is VendorProductsLoaded) {
            final products = state.products;

            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 80.sp,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'لا توجد منتجات',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'قم بإضافة منتجك الأول لتبدأ البيع',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () =>
                  context.read<VendorProductsCubit>().loadProducts(),
              color: AppColors.primary,
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: products.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  return _buildProductItem(context, products[index], isDark);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildProductItem(
    BuildContext context,
    ProductModel product,
    bool isDark,
  ) {
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
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: SizedBox(
            width: 60.w,
            height: 60.w,
            child: product.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.images.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surface,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  )
                : Container(
                    color: AppColors.surface,
                    child: const Icon(Icons.image_outlined),
                  ),
          ),
        ),
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              '${product.price} ر.س',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                _buildStatusBadge(product.status, product.isLocked),
                if (product.stockStatus.isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  Text(
                    product.stockStatus == 'instock'
                        ? 'متوفر'
                        : 'نفذت الكمية', // Simplified check
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: product.stockStatus == 'instock'
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProductScreen(productToEdit: product),
            ),
          ).then((_) {
            if (context.mounted) {
              context.read<VendorProductsCubit>().loadProducts();
            }
          });
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isLocked) {
    String label = status;
    Color color = AppColors.textSecondary;

    if (isLocked) {
      label = 'مغلق/مباع';
      color = AppColors.error;
    } else if (status == 'publish') {
      label = 'منشور';
      color = AppColors.success;
    } else if (status == 'pending') {
      label = 'قيد المراجعة';
      color = AppColors.warning;
    } else if (status == 'draft') {
      label = 'مسودة';
      color = AppColors.textSecondary;
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
