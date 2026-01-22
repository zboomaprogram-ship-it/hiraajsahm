import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/routes.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/product_grid_shimmer.dart';
import '../cubit/home_content_cubit.dart';
import '../../shop/presentation/cubit/categories_cubit.dart';
import '../../shop/data/models/product_model.dart';
import '../../shop/data/models/category_model.dart';
// ✅ Import Notification Cubit
import '../../notifications/presentation/cubit/notifications_cubit.dart';

/// Hiraaj Sahm - Home Screen
/// Livestock marketplace home with categories, auctions, and products
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Icon mapping for categories based on slug or name
  IconData _getCategoryIcon(CategoryModel category) {
    final slug = category.slug.toLowerCase();
    final name = category.name.toLowerCase();

    if (slug.contains('camel') ||
        name.contains('إبل') ||
        name.contains('ابل')) {
      return Icons.pets;
    } else if (slug.contains('sheep') ||
        name.contains('غنم') ||
        name.contains('ماعز')) {
      return Icons.grass;
    } else if (slug.contains('bird') ||
        name.contains('طيور') ||
        name.contains('دجاج')) {
      return Icons.flutter_dash;
    } else if (slug.contains('slaughter') ||
        name.contains('ذبائح') ||
        name.contains('لحم')) {
      return Icons.restaurant;
    } else if (slug.contains('equip') ||
        name.contains('مستلزمات') ||
        name.contains('أدوات')) {
      return Icons.construction;
    } else if (slug.contains('service') ||
        name.contains('خدمات') ||
        name.contains('نقل')) {
      return Icons.local_shipping;
    }
    return Icons.category;
  }

  // Color mapping for categories
  Color _getCategoryColor(int index) {
    final colors = [
      const Color(0xFFD4A574), // Camel brown
      const Color(0xFF8BC34A), // Green
      const Color(0xFF03A9F4), // Blue
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFFF9800), // Orange
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF795548), // Brown
    ];
    return colors[index % colors.length];
  }

  @override
  void initState() {
    super.initState();
    // Load categories and home content
    context.read<CategoriesCubit>().loadCategories();
    context.read<HomeContentCubit>().loadHomeContent();

    // ✅ Load Notifications to get badge count
    context.read<NotificationsCubit>().loadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      // Navigate to shop with search query
      AppRouter.navigateTo(
        context,
        Routes.products,
        arguments: {'search': query},
      );
    }
  }

  void _onCategoryTap(CategoryModel category) {
    // Navigate to shop with category filter
    AppRouter.navigateTo(
      context,
      Routes.products,
      arguments: {'categoryId': category.id, 'categoryName': category.name},
    );
  }

  void _onViewAllProducts() {
    AppRouter.navigateTo(context, Routes.products);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<CategoriesCubit>().loadCategories();
          await context.read<HomeContentCubit>().loadHomeContent();
          // ✅ Refresh Notifications on Pull-to-Refresh
          await context.read<NotificationsCubit>().loadNotifications();
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header with Search
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // Categories
            SliverToBoxAdapter(
              child: FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: _buildCategories(context, isDark),
              ),
            ),

            // Latest Listings Section
            SliverToBoxAdapter(
              child: FadeInUp(
                delay: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 400),
                child: _buildSectionHeader(
                  'أحدث الإعلانات',
                  _onViewAllProducts,
                ),
              ),
            ),

            // Products Grid - Uses HomeContentCubit
            _buildProductsGrid(context, isDark),

            // Bottom Spacing
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16.h,
        left: 20.w,
        right: 20.w,
        bottom: 24.h,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row - Logo & Notifications
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo2.png',
                        width: 28.w,
                        height: 28.w,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'هراج سهم',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'سوق المواشي الأول',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // ✅ Dynamic Notification Icon
                  BlocBuilder<NotificationsCubit, NotificationsState>(
                    builder: (context, state) {
                      int unreadCount = 0;
                      if (state is NotificationsLoaded) {
                        unreadCount = state.notifications
                            .where((n) => !n.isRead)
                            .length;
                      }

                      return _buildHeaderIcon(
                        Icons.notifications_outlined,
                        badge: unreadCount,
                        onTap: () {
                          AppRouter.navigateTo(context, Routes.notifications);
                        },
                      );
                    },
                  ),
                  SizedBox(width: 12.w),
                  _buildHeaderIcon(
                    Icons.shopping_cart_outlined,
                    onTap: () {
                      AppRouter.navigateTo(context, Routes.cart);
                    },
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              onSubmitted: (_) => _onSearch(),
              decoration: InputDecoration(
                hintText: 'ابحث عن إبل، غنم، طيور...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
                suffixIcon: GestureDetector(
                  onTap: _onSearch,
                  child: Container(
                    margin: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, {int? badge, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(icon, color: Colors.white, size: 24.sp),
            ),
            if (badge != null && badge > 0)
              Positioned(
                top: 6.h,
                right: 6.w,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge > 99 ? '99+' : badge.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
          child: Text(
            'الأقسام',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
        ),
        BlocBuilder<CategoriesCubit, CategoriesState>(
          builder: (context, state) {
            if (state is CategoriesLoading) {
              return const CategoryShimmer();
            }

            if (state is CategoriesLoaded) {
              final categories = state.categories;

              return SizedBox(
                height: 110.h,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => SizedBox(width: 16.w),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _buildCategoryItem(
                      category,
                      _getCategoryIcon(category),
                      _getCategoryColor(index),
                      isDark,
                    );
                  },
                ),
              );
            }

            return Center(
              child: Text(
                'لا توجد أقسام',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryItem(
    CategoryModel category,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _onCategoryTap(category),
      child: Column(
        children: [
          Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: category.hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: CachedNetworkImage(
                      imageUrl: category.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Icon(icon, color: color, size: 32.sp),
                      errorWidget: (_, __, ___) =>
                          Icon(icon, color: color, size: 32.sp),
                    ),
                  )
                : Icon(icon, color: color, size: 32.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: Row(
              children: [
                Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.primary,
                  size: 14.sp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(BuildContext context, bool isDark) {
    return BlocBuilder<HomeContentCubit, HomeContentState>(
      builder: (context, state) {
        if (state is HomeContentLoading) {
          return SliverToBoxAdapter(child: ProductGridShimmer(itemCount: 4));
        }

        if (state is HomeContentError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40.w),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48.sp,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<HomeContentCubit>().loadHomeContent(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is HomeContentLoaded) {
          final products = state.latestProducts.take(6).toList();

          if (products.isEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: Text(
                    'لا توجد منتجات حالياً',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            );
          }

          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                return _buildProductCard(products[index], isDark);
              }, childCount: products.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 16.w,
                childAspectRatio: 0.7,
              ),
            ),
          );
        }

        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  Widget _buildProductCard(ProductModel product, bool isDark) {
    return GestureDetector(
      onTap: () {
        AppRouter.navigateTo(
          context,
          Routes.productDetails,
          arguments: product,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.card,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
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
                                child: Icon(
                                  Icons.image_outlined,
                                  color: AppColors.textSecondary,
                                  size: 32.sp,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surface,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textSecondary,
                                  size: 32.sp,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.surface,
                            child: Center(
                              child: Icon(
                                Icons.pets,
                                color: AppColors.textSecondary,
                                size: 32.sp,
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

            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
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
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (product.hasDiscount)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 4.h),
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
                                        product.regularPrice,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.textSecondary,
                                          decoration:
                                              TextDecoration.lineThrough,
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 16.sp,
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
}
