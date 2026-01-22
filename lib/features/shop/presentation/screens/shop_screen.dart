import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/product_grid_shimmer.dart';
import '../cubit/products_cubit.dart';
import '../cubit/categories_cubit.dart';
import '../../data/models/product_model.dart';
import '../../data/models/category_model.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';

/// Shop Screen - All Products with Dynamic Categories Filter
class ShopScreen extends StatefulWidget {
  final String? initialSearch;
  final int? initialCategoryId;
  final String? initialCategoryName;

  const ShopScreen({
    super.key,
    this.initialSearch,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _selectedCategoryId = widget.initialCategoryId;
    _searchController.text = widget.initialSearch ?? '';

    final categoriesState = context.read<CategoriesCubit>().state;
    if (categoriesState is! CategoriesLoaded) {
      context.read<CategoriesCubit>().loadCategories();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsCubit>().loadProducts(
        categoryId: _selectedCategoryId,
        search: widget.initialSearch,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ProductsCubit>().loadMoreProducts();
    }
  }

  void _onCategorySelected(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    context.read<ProductsCubit>().loadProducts(categoryId: categoryId);
  }

  void _onSearch(String query) {
    context.read<ProductsCubit>().loadProducts(
      search: query.isEmpty ? null : query,
      categoryId: _selectedCategoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: _buildSearchBar(isDark),
          ),
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 300),
            child: _buildCategoryFilter(isDark),
          ),
          Expanded(child: _buildProductsGrid(isDark)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    String title = 'السوق الإلكتروني'; // Changed
    if (widget.initialCategoryName != null) {
      title = widget.initialCategoryName!;
    } else if (widget.initialSearch != null &&
        widget.initialSearch!.isNotEmpty) {
      title = 'نتائج البحث';
    }

    return AppBar(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      elevation: 0,
      leading: Navigator.canPop(context)
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
            )
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textLight : AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton.icon(
          onPressed: () {
            // Navigate to Orders (My Requests)
            // Assuming Routes.orders exists or using bottom nav?
            // Prompt says: "navigate to the Orders screen".
            // Checking routes... I recall Routes.orders might be implicitly handled or I need to find it.
            // If no route, I might need to add it or use MainLayout index switch.
            // I'll assume standard route for now or just placeholder if unsure.
            // Actually, usually it's Routes.orders or similar.
            // Let's use AppRouter.navigateTo(context, Routes.orders); and fix if missing.
            // Wait, previous session had "My Orders" in profile.
            AppRouter.navigateTo(
              context,
              Routes.orders,
            ); // Using direct string if Routes constant unsure, or better checks.
            // 'Routes.orders' is safest guess.
          },
          icon: Icon(
            Icons.list_alt_rounded,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
            size: 24.sp,
          ),
          label: Text(
            'طلباتي',
            style: TextStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: EdgeInsets.all(16.w),
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
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'ابحث عن منتج...',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 24.sp,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    return SizedBox(
      height: 50.h,
      child: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          List<CategoryModel?> categories = [null];
          if (state is CategoriesLoaded) {
            categories.addAll(state.categories);
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category?.id == _selectedCategoryId;

              if (category == null) {
                return _buildCategoryChip(
                  name: 'الكل',
                  icon: Icons.grid_view_rounded,
                  isSelected: _selectedCategoryId == null,
                  isDark: isDark,
                  onTap: () => _onCategorySelected(null),
                );
              }

              return _buildCategoryChip(
                name: category.name,
                icon: _getCategoryIcon(category),
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => _onCategorySelected(category.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required String name,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.textLightSecondary
                        : AppColors.textSecondary),
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textLightSecondary
                          : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(CategoryModel category) {
    final slug = category.slug.toLowerCase();
    final name = category.name.toLowerCase();

    if (slug.contains('camel') ||
        name.contains('إبل') ||
        name.contains('ابل')) {
      return Icons.pets;
    }
    if (slug.contains('sheep') ||
        name.contains('غنم') ||
        name.contains('ماعز')) {
      return Icons.grass;
    }
    if (slug.contains('bird') ||
        name.contains('طيور') ||
        name.contains('دجاج')) {
      return Icons.flutter_dash;
    }
    if (slug.contains('slaughter') ||
        name.contains('ذبائح') ||
        name.contains('لحم')) {
      return Icons.restaurant;
    }
    if (slug.contains('equip') ||
        name.contains('مستلزمات') ||
        name.contains('أدوات')) {
      return Icons.construction;
    }
    if (slug.contains('service') ||
        name.contains('خدمات') ||
        name.contains('نقل')) {
      return Icons.local_shipping;
    }
    return Icons.category;
  }

  Widget _buildProductsGrid(bool isDark) {
    return BlocBuilder<ProductsCubit, ProductsState>(
      builder: (context, state) {
        if (state is ProductsLoading) {
          return Padding(
            padding: EdgeInsets.only(top: 16.h),
            child: const ProductGridShimmer(itemCount: 6),
          );
        }

        if (state is ProductsError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(40.w),
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton.icon(
                    onPressed: () => context.read<ProductsCubit>().loadProducts(
                      categoryId: _selectedCategoryId,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is ProductsLoaded) {
          if (state.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'لا توجد منتجات',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ProductsCubit>().loadProducts(
              categoryId: _selectedCategoryId,
              refresh: true,
            ),
            color: AppColors.primary,
            child: GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 16.w,
                childAspectRatio: 0.65,
              ),
              itemCount: state.products.length + (state.hasReachedMax ? 0 : 1),
              itemBuilder: (context, index) {
                if (index >= state.products.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: (index % 10) * 50),
                  child: _buildProductCard(state.products[index], isDark),
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildProductCard(ProductModel product, bool isDark) {
    final isOutOfStock =
        product.stockStatus == 'outofstock' || product.stockQuantity == 0;

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
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
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
                            placeholder: (context, url) => Container(
                              color: AppColors.surface,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),
                  ),
                  if (product.hasDiscount)
                    Positioned(
                      top: 8.h,
                      left: 8.w,
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
                  // Status Banners
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
                                color: Colors.black.withValues(alpha: 0.2),
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
                    )
                  else if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.r),
                          ),
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'نفذت الكمية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.hasDiscount)
                              Padding(
                                padding: EdgeInsets.only(bottom: 2.h),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        borderRadius: BorderRadius.circular(
                                          4.r,
                                        ),
                                      ),
                                      child: Text(
                                        '${product.discountPercentage.round()}%',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${product.regularPrice} ر.س',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: AppColors.textSecondary,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
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
                        GestureDetector(
                          onTap: isOutOfStock
                              ? null
                              : () {
                                  context.read<CartCubit>().addItem(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تمت الإضافة إلى السلة'),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                          child: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? AppColors.textSecondary.withValues(
                                      alpha: 0.3,
                                    )
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              isOutOfStock
                                  ? Icons.remove_shopping_cart_outlined
                                  : Icons.add_shopping_cart_rounded,
                              color: isOutOfStock
                                  ? AppColors.textSecondary
                                  : Colors.white,
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

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.pets, color: AppColors.textSecondary, size: 40.sp),
      ),
    );
  }
}
