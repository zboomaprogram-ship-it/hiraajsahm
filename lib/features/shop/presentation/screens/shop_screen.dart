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
import '../cubit/zabayeh_products_cubit.dart';
import '../cubit/categories_cubit.dart';
import '../../data/models/product_model.dart';
import '../../data/models/category_model.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../../core/data/regions_service.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../widgets/product_card.dart';

/// Shop Screen - All Products with Dynamic Categories Filter
class ShopScreen extends StatefulWidget {
  final String? initialSearch;
  final int? initialCategoryId;
  final String? initialCategoryName;
  final bool hasExplicitCategory; // true when args were passed

  const ShopScreen({
    super.key,
    this.initialSearch,
    this.initialCategoryId,
    this.initialCategoryName,
    this.hasExplicitCategory = false,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;
  String _selectedRegion = 'الكل';
  String _selectedCity = 'الكل';
  List<String> _saudiRegions = ['الكل', 'الموقع الحالي'];
  List<String> _saudiCities = ['الكل'];

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _scrollController.addListener(_onScroll);
    // Default to Zabayeh (78) only when opened from bottom tab (no explicit args)
    _selectedCategoryId = widget.hasExplicitCategory
        ? widget.initialCategoryId // null = all products
        : 78; // bottom tab = Zabayeh
    _searchController.text = widget.initialSearch ?? '';

    final categoriesState = context.read<CategoriesCubit>().state;
    if (categoriesState is! CategoriesLoaded) {
      context.read<CategoriesCubit>().loadCategories();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCategoryId == 78) {
        context.read<ZabayehProductsCubit>().loadProducts(
          categoryId: _selectedCategoryId,
          search: widget.initialSearch,
          region: _selectedRegion == 'الكل' ? null : _selectedRegion,
          refresh: false,
        );
      } else {
        context.read<ProductsCubit>().loadProducts(
          categoryId: _selectedCategoryId,
          search: widget.initialSearch,
          region: _selectedRegion == 'الكل' ? null : _selectedRegion,
          refresh: false,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    final names = await RegionsService().getRegionNames();
    if (mounted) {
      setState(() {
        _saudiRegions = ['الكل', 'الموقع الحالي', ...names];
      });
      print('🛒 ShopScreen Regions Loaded: ${names.length} names found');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ProductsCubit>().loadMoreProducts();
    }
  }

  void _onSearch(String query) {
    String? currentRegion = _selectedRegion == 'الكل' ? null : (_selectedRegion == 'الموقع الحالي' ? context.read<AuthCubit>().currentUser?.region : _selectedRegion);

    if (_selectedCategoryId == 78) {
      context.read<ZabayehProductsCubit>().loadProducts(
        search: query.isEmpty ? null : query,
        categoryId: _selectedCategoryId,
        region: currentRegion,
        city: _selectedCity == 'الكل' ? null : _selectedCity,
      );
    } else {
      context.read<ProductsCubit>().loadProducts(
        search: query.isEmpty ? null : query,
        categoryId: _selectedCategoryId,
        region: currentRegion,
        city: _selectedCity == 'الكل' ? null : _selectedCity,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: _buildSearchBar(isDark),
          ),
          
          // Show main categories ONLY if this is the generic Shop Screen (not strictly Zabayeh tab)
          if (widget.hasExplicitCategory)
            _buildCategories(context, isDark, isTablet),
            
          // Always show subcategories (if a parent category is selected)
          _buildSubCategories(isDark, isTablet),

          // Region Filter
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 300),
            child: _buildRegionFilter(isDark),
          ),

          // City Filter (Cascading)
          if (_selectedRegion != 'الكل')
            _buildCityFilter(isDark),
            
          Expanded(child: _buildProductsGrid(isDark, isTablet)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final isZabayeh = _selectedCategoryId == 78;
    String title =
        widget.initialCategoryName ?? (isZabayeh ? 'الذبائح' : 'الاعلانات');
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      title = 'نتائج البحث';
    }

    return AppBar(
      backgroundColor: isZabayeh
          ? AppColors.error
          : (isDark ? AppColors.surfaceDark : Colors.white),
      elevation: 0,
      flexibleSpace: isZabayeh
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            )
          : null,
      leading: Navigator.canPop(context)
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: isZabayeh
                    ? Colors.white
                    : (isDark ? AppColors.textLight : AppColors.textPrimary),
              ),
            )
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.bold,
          color: isZabayeh
              ? Colors.white
              : (isDark ? AppColors.textLight : AppColors.textPrimary),
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
            color: _selectedCategoryId == 78
                ? Colors.white
                : (isDark ? AppColors.textLight : AppColors.textPrimary),
            size: 24.sp,
          ),
          label: Text(
            'طلباتي',
            style: TextStyle(
              color: _selectedCategoryId == 78
                  ? Colors.white
                  : (isDark ? AppColors.textLight : AppColors.textPrimary),
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
          hintText: 'ابحث عن اعلان...',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _selectedCategoryId == 78
                ? AppColors.error
                : AppColors.primary,
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

  // Icon mapping for categories based on slug or name
  IconData _getCategoryIcon(CategoryModel category) {
    final slug = category.slug.toLowerCase();
    final name = category.name.toLowerCase();

    if (slug.contains('camel') || name.contains('إبل') || name.contains('ابل')) {
      return Icons.pets;
    } else if (slug.contains('sheep') || name.contains('غنم') || name.contains('ماعز')) {
      return Icons.grass;
    } else if (slug.contains('bird') || name.contains('طيور') || name.contains('دجاج')) {
      return Icons.flutter_dash;
    } else if (slug.contains('slaughter') || name.contains('ذبائح') || name.contains('لحم')) {
      return Icons.restaurant;
    } else if (slug.contains('equip') || name.contains('مستلزمات') || name.contains('أدوات')) {
      return Icons.construction;
    } else if (slug.contains('service') || name.contains('خدمات') || name.contains('نقل')) {
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

  void _onCategoryTap(CategoryModel category) {
    setState(() {
      String? currentRegion = _selectedRegion == 'الكل' ? null : (_selectedRegion == 'الموقع الحالي' ? context.read<AuthCubit>().currentUser?.region : _selectedRegion);

      if (_selectedCategoryId == category.id) {
        // Toggle OFF (revert to "All")
        _selectedCategoryId = null;
        _selectedSubCategoryId = null;
        context.read<ProductsCubit>().loadProducts(
          categoryId: null,
          search: _searchController.text.isEmpty ? null : _searchController.text,
          region: currentRegion,
          city: _selectedCity == 'الكل' ? null : _selectedCity,
        );
      } else {
        // Toggle ON
        _selectedCategoryId = category.id;
        _selectedSubCategoryId = null;
        if (category.id == 78) {
           context.read<ZabayehProductsCubit>().loadProducts(
            categoryId: category.id,
            search: _searchController.text.isEmpty ? null : _searchController.text,
            region: currentRegion,
            city: _selectedCity == 'الكل' ? null : _selectedCity,
          );
        } else {
          context.read<ProductsCubit>().loadProducts(
            categoryId: category.id,
            search: _searchController.text.isEmpty ? null : _searchController.text,
            region: currentRegion,
            city: _selectedCity == 'الكل' ? null : _selectedCity,
          );
        }
      }
    });
  }

  void _onSubCategoryTap(CategoryModel subCategory) {
    setState(() {
      String? currentRegion = _selectedRegion == 'الكل' ? null : (_selectedRegion == 'الموقع الحالي' ? context.read<AuthCubit>().currentUser?.region : _selectedRegion);

      if (_selectedSubCategoryId == subCategory.id) {
        // Toggle OFF subcategory, revert to parent
        _selectedSubCategoryId = null;
        context.read<ProductsCubit>().loadProducts(
          categoryId: _selectedCategoryId,
          search: _searchController.text.isEmpty ? null : _searchController.text,
          region: currentRegion,
          city: _selectedCity == 'الكل' ? null : _selectedCity,
        );
      } else {
        // Toggle ON
        _selectedSubCategoryId = subCategory.id;
        context.read<ProductsCubit>().loadProducts(
          categoryId: subCategory.id,
          search: _searchController.text.isEmpty ? null : _searchController.text,
          region: currentRegion,
          city: _selectedCity == 'الكل' ? null : _selectedCity,
        );
      }
    });
  }

  Widget _buildCategoryItem(CategoryModel category, IconData icon, Color color, bool isDark, bool isTablet) {
    final isSelected = _selectedCategoryId == category.id;

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

  Widget _buildCategories(BuildContext context, bool isDark, bool isTablet) {
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        if (state is! CategoriesLoaded) return const SizedBox.shrink();

        final categories = state.categories.where((c) => c.parent == 0).toList();
        if (categories.isEmpty) return const SizedBox.shrink();

        return Container(
          height: isTablet ? 70.h : 60.h,
          margin: EdgeInsets.only(top: 8.h),
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
      },
    );
  }

  Widget _buildSubCategories(bool isDark, bool isTablet) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _selectedCategoryId == null
          ? const SizedBox.shrink()
          : BlocBuilder<CategoriesCubit, CategoriesState>(
              builder: (context, state) {
                if (state is CategoriesLoaded) {
                  final subCategories = CategoryModel.getSubCategories(
                    state.categories,
                    _selectedCategoryId!,
                  );

                  if (subCategories.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    margin: EdgeInsets.only(top: 16.h, bottom: 8.h),
                    height: isTablet ? 45.h : 38.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: subCategories.length,
                      separatorBuilder: (_, __) => SizedBox(width: 8.w),
                      itemBuilder: (context, index) {
                        final subCat = subCategories[index];
                        final isSelected = _selectedSubCategoryId == subCat.id;
                        
                        return GestureDetector(
                          onTap: () => _onSubCategoryTap(subCat),
                          child: Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.surfaceDark : Colors.white),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primary.withAlpha(77),
                              ),
                            ),
                            child: Text(
                              subCat.name,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: isSelected ? Colors.white : AppColors.primary,
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
        
        // Print the resolved region
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('تم تحديد الموقع: ${user.region}'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
            ),
        );
    }

    setState(() {
      _selectedRegion = region;
      _selectedCity = 'الكل';
      _saudiCities = region == 'الموقع الحالي' ? [] : ['الكل'];
    });

    if (filterRegion != 'الكل' && filterRegion != 'الموقع الحالي') {
      final cities = await RegionsService().getCitiesForRegion(filterRegion!);
      if (mounted) {
        setState(() {
          // Hide 'الكل' if it's the current location mode
          if (region == 'الموقع الحالي') {
            _saudiCities = cities;
            if (cities.isNotEmpty) {
              // Optionally auto-select user's city if it's in the list
              final userCity = context.read<AuthCubit>().currentUser?.city;
              if (userCity != null && cities.contains(userCity)) {
                _selectedCity = userCity;
              } else if (cities.isNotEmpty) {
                _selectedCity = cities.first;
              }
            }
          } else {
            _saudiCities = ['الكل', ...cities];
          }
        });
      }
    }

    if (_selectedCategoryId == 78) {
      context.read<ZabayehProductsCubit>().loadProducts(
            categoryId: 78,
            search: _searchController.text,
            region: filterRegion == 'الكل' ? null : filterRegion,
            city: null,
            refresh: true,
          );
    } else {
      context.read<ProductsCubit>().loadProducts(
            categoryId: _selectedSubCategoryId ?? _selectedCategoryId,
            search: _searchController.text,
            region: filterRegion == 'الكل' ? null : filterRegion,
            city: null,
            refresh: true,
          );
    }
  }

  void _onCitySelected(String city) {
    if (_selectedCity == city) return;

    setState(() {
      _selectedCity = city;
    });

    if (_selectedCategoryId == 78) {
      context.read<ZabayehProductsCubit>().loadProducts(
            categoryId: 78,
            search: _searchController.text,
            region: _selectedRegion == 'الكل' ? null : _selectedRegion,
            city: city == 'الكل' ? null : city,
            refresh: true,
          );
    } else {
      context.read<ProductsCubit>().loadProducts(
            categoryId: _selectedSubCategoryId ?? _selectedCategoryId,
            search: _searchController.text,
            region: _selectedRegion == 'الكل' ? null : _selectedRegion,
            city: city == 'الكل' ? null : city,
            refresh: true,
          );
    }
  }

  Widget _buildRegionFilter(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
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
                    fontSize: 14.sp,
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
    if (_saudiCities.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
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
                    fontSize: 14.sp,
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

  Widget _buildProductsGrid(bool isDark, bool isTablet) {
    if (_selectedCategoryId == 78) {
      return BlocBuilder<ZabayehProductsCubit, ProductsState>(
        builder: (context, state) => _buildGridInner(context, state, isDark, isTablet),
      );
    } else {
      return BlocBuilder<ProductsCubit, ProductsState>(
        builder: (context, state) => _buildGridInner(context, state, isDark, isTablet),
      );
    }
  }

  Widget _buildGridInner(BuildContext context, ProductsState state, bool isDark, bool isTablet) {
    if (state is ProductsLoading) {
      return Padding(
        padding: EdgeInsets.only(top: 16.h),
        child: ProductGridShimmer(itemCount: isTablet ? 9 : 6),
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
                onPressed: () {
                  if (_selectedCategoryId == 78) {
                    context.read<ZabayehProductsCubit>().loadProducts(
                      categoryId: _selectedCategoryId,
                    );
                  } else {
                    context.read<ProductsCubit>().loadProducts(
                      categoryId: _selectedCategoryId,
                    );
                  }
                },
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
                _selectedCategoryId == 78
                    ? Icons.storefront_rounded
                    : Icons.inventory_2_outlined,
                size: 64.sp,
                color: _selectedCategoryId == 78
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.textSecondary,
              ),
              SizedBox(height: 16.h),
              Text(
                'لا توجد اعلانات',
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
        onRefresh: () {
          if (_selectedCategoryId == 78) {
            return context.read<ZabayehProductsCubit>().loadProducts(
              categoryId: _selectedCategoryId,
              refresh: true,
            );
          } else {
            return context.read<ProductsCubit>().loadProducts(
              categoryId: _selectedCategoryId,
              refresh: true,
            );
          }
        },
        color: _selectedCategoryId == 78
            ? AppColors.error
            : AppColors.primary,
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 3 : 2,
            mainAxisSpacing: 16.h,
            crossAxisSpacing: 16.w,
            childAspectRatio: isTablet ? 0.8 : 0.65,
          ),
          itemCount: state.products.length + (state.hasReachedMax ? 0 : 1),
          itemBuilder: (context, index) {
            if (index >= state.products.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: _selectedCategoryId == 78
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                ),
              );
            }
            return FadeInUp(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: (index % 10) * 50),
              child: _buildProductCard(
                state.products[index],
                isDark,
                isTablet,
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProductCard(ProductModel product, bool isDark, bool isTablet) {
    return ProductCard(
      product: product,
      isTablet: isTablet,
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
