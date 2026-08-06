import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../cubit/cart_cubit.dart';
import '../../../../core/widgets/custom_button.dart';

/// Cart Screen - Shows cart items and checkout
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('طلباتي'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              if (state is CartLoaded && !state.isEmpty) {
                return TextButton(
                  onPressed: () {
                    _showClearCartDialog(context);
                  },
                  child: Text(
                    'مسح الكل',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state is CartLoaded) {
            if (state.isEmpty) {
              return _buildEmptyCart(context);
            }

            return Column(
              children: [
                // Cart Items List
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
                      return FadeInUp(
                        duration: const Duration(milliseconds: 300),
                        delay: Duration(milliseconds: index * 50),
                        child: _buildCartItem(
                          context,
                          state.items[index],
                          isDark,
                        ),
                      );
                    },
                  ),
                ),

                // Order Summary & Checkout
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: _buildOrderSummary(context, state, isDark),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 60.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'طلباتي فارغة',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'لم تقم بإضافة أي اعلان إلى طلباتي بعد',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(200.w, 52.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                'تصفح الاعلانات',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, bool isDark) {
    return Dismissible(
      key: Key(item.product.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.white, size: 28.sp),
      ),
      onDismissed: (_) {
        context.read<CartCubit>().removeItem(item.product.id);
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
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
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: item.product.images.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.product.images.first,
                      width: 80.w,
                      height: 80.w,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildImagePlaceholder(),
                      errorWidget: (context, url, error) =>
                          _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
            SizedBox(width: 12.w),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  // Payment Mode Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: item.isDeposit
                          ? AppColors.secondary.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      item.isDeposit
                          ? 'معاينة (${(item.depositPercentage * 100).toStringAsFixed(0)}%)'
                          : 'شراء كامل',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: item.isDeposit
                            ? AppColors.secondary
                            : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${item.totalPrice.toStringAsFixed(2)} ر.س',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),

            // Marketplace listings are unique: one product per cart item.
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                'قطعة واحدة',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80.w,
      height: 80.w,
      color: AppColors.surface,
      child: Icon(Icons.pets, color: AppColors.textSecondary, size: 32.sp),
    );
  }

  Widget _buildOrderSummary(
    BuildContext context,
    CartLoaded state,
    bool isDark,
  ) {
    final firstItem = state.items.isNotEmpty ? state.items.first : null;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total (المجموع الكلي)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المجموع الكلي',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${state.total.toStringAsFixed(2)} ر.س',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Divider(color: AppColors.border),
            SizedBox(height: 12.h),

            // Subtotal (المجموع الفرعي - اختياري)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المجموع الفرعي (اختياري)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                if (firstItem != null && firstItem.customPrice != null)
                  GestureDetector(
                    onTap: () {
                      context.read<CartCubit>().updateCustomPrice(
                        firstItem.product.id,
                        null,
                      );
                    },
                    child: Text(
                      'إلغاء التعديل',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            if (firstItem != null)
              _CustomPriceInputField(
                key: ValueKey(
                  'price_field_${firstItem.product.id}_${firstItem.customPrice}',
                ),
                initialValue:
                    firstItem.customPrice ??
                    (double.tryParse(firstItem.product.price) ?? 0.0),
                onPriceChanged: (val) {
                  context.read<CartCubit>().updateCustomPrice(
                    firstItem.product.id,
                    val,
                  );
                },
                isDark: isDark,
              ),

            SizedBox(height: 20.h),

            // Checkout Button
            CustomButton(
              text: 'إتمام الطلب',
              onPressed: () {
                AppRouter.navigateTo(context, Routes.checkout);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح طلباتي'),
        content: const Text('هل أنت متأكد من مسح جميع الاعلانات من طلباتي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<CartCubit>().clearCart();
              Navigator.pop(context);
            },
            child: Text('مسح', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _CustomPriceInputField extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double?> onPriceChanged;
  final bool isDark;

  const _CustomPriceInputField({
    super.key,
    required this.initialValue,
    required this.onPriceChanged,
    required this.isDark,
  });

  @override
  State<_CustomPriceInputField> createState() => _CustomPriceInputFieldState();
}

class _CustomPriceInputFieldState extends State<_CustomPriceInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue > 0
          ? widget.initialValue.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.primary),
      ),
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (val) {
          final trimmed = val.trim();
          if (trimmed.isEmpty) {
            widget.onPriceChanged(null);
          } else {
            final price = double.tryParse(trimmed);
            widget.onPriceChanged(price);
          }
        },
        decoration: InputDecoration(
          hintText: 'أدخل السعر المطلوب (اختياري)',
          hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          suffixText: 'ر.س',
          suffixStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        ),
      ),
    );
  }
}
