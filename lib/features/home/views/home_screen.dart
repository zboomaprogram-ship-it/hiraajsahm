import 'package:flutter/material.dart';
import '../../../../core/data/regions_service.dart';
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
import '../../cart/presentation/cubit/cart_cubit.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../shop/presentation/widgets/product_card.dart';

/// Hiraaj Sahm - Home Screen
/// Livestock marketplace home with categories, auctions, and products
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  int? _selectedParentCategoryId;
  String _selectedRegion = 'الكل';
  String _selectedCity = 'الكل';
  int? _selectedSubCategoryId;

  List<String> _saudiRegions = [
    'الكل',
  ];
  List<String> _saudiCities = [
    'الكل',
  ];

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

    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final names = await RegionsService().getRegionNames();
    if (mounted) {
      setState(() {
        _saudiRegions = ['الكل', 'الموقع الحالي', ...names];
      });
      print('🏘️ HomeScreen Regions Loaded: ${names.length} names found');
    }
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
    setState(() {
      if (_selectedParentCategoryId == category.id) {
        // Toggle OFF
        _selectedParentCategoryId = null;
        _selectedSubCategoryId = null;
        context.read<HomeContentCubit>().loadHomeContent(
          categoryId: null,
          region: _selectedRegion == 'الكل' ? null : (_selectedRegion == 'الموقع الحالي' ? context.read<AuthCubit>().currentUser?.region : _selectedRegion),
          city: _selectedCity == 'الكل' ? null : _selectedCity,
        );
      } else {
        // Toggle ON
        _selectedParentCategoryId = category.id;
        _selectedSubCategoryId = null;
        context.read<HomeContentCubit>().loadHomeContent(
          categoryId: category.id,
          region: _selectedRegion == 'الكل' ? null : (_selectedRegion == 'الموقع الحالي' ? context.read<AuthCubit>().currentUser?.region : _selectedRegion),
          city: _selectedCity == 'الكل' ? null : _selectedCity,
        );
      }
    });
  }

  void _onSubCategoryTap(CategoryModel subCategory) {
    // Filter in-place; keep parent selected so subcategory row stays visible
    setState(() {
      if (_selectedSubCategoryId == subCategory.id) {
        // Toggle OFF subcategory → revert to parent
        _selectedSubCategoryId = null;
        context.read<HomeContentCubit>().loadHomeContent(
          categoryId: _selectedParentCategoryId,
          region: _selectedRegion == 'الكل' ? null : (_selectedRegion == 'الموقع الحالي' ? context.read<AuthCubit>().currentUser?.region : _selectedRegion),
          city: _selectedCity == 'الكل' ? null : _selectedCity,
        );
      } else {
        _selectedSubCategoryId = subCategory.id;
        context.read<HomeContentCubit>().loadHomeContent(
          categoryId: subCategory.id,
          region: _selectedRegion == 'الكل' ? null : (_selectedRegion == 'الموقع الحالي' ? context.read<AuthCubit>().currentUser?.region : _selectedRegion),
          city: _selectedCity == 'الكل' ? null : _selectedCity,
        );
      }
    });
  }

  void _onRegionSelected(String region) async {
    if (_selectedRegion == region) return;

    String? filterRegion = region;
    if (region == 'الموقع الحالي') {
      final user = context.read<AuthCubit>().currentUser;
      if (user == null || user.region == null || user.region!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء تسجيل الدخول أولاً أو تحديد موقعك في الملف الشخصي'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      filterRegion = user.region;
    }

    setState(() {
      _selectedRegion = region;
      _selectedCity = 'الكل';
      _saudiCities = ['الكل'];
    });

    if (filterRegion != 'الكل' && filterRegion != 'الموقع الحالي') {
        final cities = await RegionsService().getCitiesForRegion(filterRegion!);
        if (mounted) {
          setState(() {
            _saudiCities = ['الكل', ...cities];
          });
        }
    }

    // Trigger content reload
    if (mounted) {
      context.read<HomeContentCubit>().loadHomeContent(
            categoryId: _selectedSubCategoryId ?? _selectedParentCategoryId,
            region: filterRegion == 'الكل' ? null : filterRegion,
            city: null,
          );
    }
  }

  void _onCitySelected(String city) {
    if (_selectedCity == city) return;

    setState(() {
      _selectedCity = city;
    });

    context.read<HomeContentCubit>().loadHomeContent(
          categoryId: _selectedSubCategoryId ?? _selectedParentCategoryId,
          region: _selectedRegion == 'الكل' ? null : _selectedRegion,
          city: city == 'الكل' ? null : city,
        );
  }

  void _onViewAllProducts() {
    // Pass explicit null so ShopScreen loads ALL products, not Zabayeh
    AppRouter.navigateTo(context, Routes.products, arguments: {
      'categoryId': null,
      'categoryName': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

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
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Header with Search
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // Categories
            SliverToBoxAdapter(
              child: FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: _buildCategories(context, isDark, isTablet),
              ),
            ),

            // Subcategories (Animated depending on selection)
            SliverToBoxAdapter(child: _buildSubCategories(isDark, isTablet)),

            // Region Filter
            SliverToBoxAdapter(
              child: FadeInUp(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 400),
                child: _buildRegionFilter(isDark),
              ),
            ),

            // City Filter (Cascading)
            if (_selectedRegion != 'الكل')
              SliverToBoxAdapter(
                key: ValueKey('city_filter_sliver_$_selectedRegion'),
                child: FadeInUp(
                  key: ValueKey('city_filter_fade_$_selectedRegion'),
                  duration: const Duration(milliseconds: 400),
                  child: _buildCityFilter(isDark),
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
            _buildProductsGrid(context, isDark, isTablet),

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
                        'حراج سهم',
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
                    Icons.shopping_bag_outlined,
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

  Widget _buildCategories(BuildContext context, bool isDark, bool isTablet) {
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
              final categories = state.categories
                  .where((c) => c.parent == 0)
                  .toList();

              return SizedBox(
                height: isTablet ? 70.h : 60.h,
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
                      isTablet,
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
    bool isTablet,
  ) {
    final isSelected = _selectedParentCategoryId == category.id;

    return GestureDetector(
      onTap: () => _onCategoryTap(category),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isTablet ? 110.w : 80.w,
            height: isTablet ? 55.h : 48.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.surfaceVariantDark : Colors.grey[200]),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(77), // 0.3 opacity
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCategories(bool isDark, bool isTablet) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _selectedParentCategoryId == null
          ? const SizedBox.shrink()
          : BlocBuilder<CategoriesCubit, CategoriesState>(
              builder: (context, state) {
                if (state is CategoriesLoaded) {
                  final subCategories = CategoryModel.getSubCategories(
                    state.categories,
                    _selectedParentCategoryId!,
                  );

                  if (subCategories.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    margin: EdgeInsets.only(top: 16.h),
                    height: isTablet ? 45.h : 38.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: subCategories.length,
                      separatorBuilder: (_, __) => SizedBox(width: 8.w),
                      itemBuilder: (context, index) {
                        final subCat = subCategories[index];
                        return GestureDetector(
                          onTap: () => _onSubCategoryTap(subCat),
                          child: Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: _selectedSubCategoryId == subCat.id
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.surfaceDark
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: _selectedSubCategoryId == subCat.id
                                    ? AppColors.primary
                                    : AppColors.primary.withAlpha(77),
                              ),
                            ),
                            child: Text(
                              subCat.name,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: _selectedSubCategoryId == subCat.id
                                    ? Colors.white
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
    );
  }

  Widget _buildRegionFilter(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6.w),
                Text(
                  'المنطقة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              scrollDirection: Axis.horizontal,
              itemCount: _saudiRegions.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final region = _saudiRegions[index];
                final isSelected = _selectedRegion == region;

                return GestureDetector(
                  onTap: () => _onRegionSelected(region),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.surfaceVariantDark
                                : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      region,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityFilter(bool isDark) {
    if (_saudiCities.length <= 1 && _selectedRegion == 'الكل') return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.location_city_rounded,
                  size: 18.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6.w),
                Text(
                  'المدينة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              scrollDirection: Axis.horizontal,
              itemCount: _saudiCities.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final city = _saudiCities[index];
                final isSelected = _selectedCity == city;

                return GestureDetector(
                  onTap: () => _onCitySelected(city),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.surfaceVariantDark
                                : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      city,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
                  ),
                );
              },
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

  Widget _buildProductsGrid(BuildContext context, bool isDark, bool isTablet) {
    return BlocBuilder<HomeContentCubit, HomeContentState>(
      builder: (context, state) {
        if (state is HomeContentLoading) {
          return SliverToBoxAdapter(
            child: ProductGridShimmer(itemCount: isTablet ? 6 : 4),
          );
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
          final products = state.latestProducts.take(isTablet ? 9 : 6).toList();

          if (products.isEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: Text(
                    'لا توجد اعلانات حالياً',
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
                return _buildProductCard(products[index], isDark, isTablet);
              }, childCount: products.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 16.w,
                childAspectRatio: isTablet ? 0.8 : 0.7,
              ),
            ),
          );
        }

        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  Widget _buildProductCard(ProductModel product, bool isDark, bool isTablet) {
    return ProductCard(
      product: product,
      isTablet: isTablet,
    );
  }
}
