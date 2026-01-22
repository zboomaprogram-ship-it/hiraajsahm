import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';

import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/storage_service.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Subscription Screen - Display vendor subscription tiers
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  List<ProductModel> _subscriptionPacks = [];
  String? _errorMessage;
  String? _currentUserTier;

  // Al-Zabayeh pack ID - restricted to Silver/Gold members only
  static const int _zabayehPackId = 29318;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Get current user tier
    final storageService = di.sl<StorageService>();
    _currentUserTier = await storageService.getUserTier();

    // Load subscription packs
    await _loadSubscriptionPacks();
  }

  Future<void> _loadSubscriptionPacks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch products from "Packages" category (ID: 122)
      final response = await _dio.get(
        'https://hiraajsahm.com/wp-json/wc/v3/products?consumer_key=ck_78ec6d3f6325ae403400781192045474f592b24a&consumer_secret=cs_0accb11f98ea7516ab4630e521748e73ce3d3b54&category=122',
        queryParameters: {
          // 'consumer_key': AppConfig.wcConsumerKey,
          // 'consumer_secret': AppConfig.wcConsumerSecret,
          // 'category': '122', // Packages category ID++++
          // 'status': 'publish',
          // 'per_page': 20,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        setState(() {
          _subscriptionPacks = data
              .map((json) => ProductModel.fromJson(json))
              .toList();
          _isLoading = false;
        });

        // If no products found, show empty state
        if (_subscriptionPacks.isEmpty) {
          setState(() {
            _errorMessage = 'لا توجد باقات متاحة حالياً';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'فشل في تحميل باقات الاشتراك';
        });
      }
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.response?.statusCode == 404
            ? 'لم يتم العثور على باقات الاشتراك'
            : 'تحقق من اتصال الإنترنت';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ غير متوقع';
      });
    }
  }

  /// Get tier level (higher = better)
  int _getTierLevel(int? packId) {
    switch (packId) {
      case 29030:
        return 3; // Gold
      case 29028:
        return 2; // Silver
      case 29026:
        return 1; // Bronze
      case 29318:
        return 4; // Zabayeh (special)
      default:
        return 0;
    }
  }

  /// Check if Al-Zabayeh pack is locked for current user
  bool _isZabayehLocked(int packId) {
    if (packId != _zabayehPackId) return false;
    // Al-Zabayeh is only available to Silver or Gold members
    return !(_currentUserTier == 'silver' || _currentUserTier == 'gold');
  }

  /// Get current user's pack ID
  int? _getCurrentPackId() {
    final authCubit = context.read<AuthCubit>();
    return authCubit.currentUser?.subscriptionPackId;
  }

  void _subscribeToPack(ProductModel pack) {
    // Check if trying to subscribe to locked Al-Zabayeh pack
    if (_isZabayehLocked(pack.id)) {
      _showLockedPackDialog();
      return;
    }

    // Check if user already has Al-Zabayeh tier (for pack 29318)
    if (pack.id == _zabayehPackId) {
      final authCubit = context.read<AuthCubit>();
      if (authCubit.currentUser?.hasAlZabayehTier == true) {
        _showAlreadyHasZabayehDialog();
        return;
      }
    }

    final currentPackId = _getCurrentPackId();
    final currentLevel = _getTierLevel(currentPackId);
    final newLevel = _getTierLevel(pack.id);

    // Prevent purchasing same tier
    if (currentPackId == pack.id) {
      _showAlreadySubscribedDialog();
      return;
    }

    // Prevent downgrade (except Zabayeh which is special)
    if (pack.id != 29318 && newLevel <= currentLevel && currentLevel > 0) {
      _showDowngradeNotAllowedDialog();
      return;
    }

    // Navigate to subscription confirmation (simplified - no checkout form)
    _showSubscriptionConfirmDialog(pack);
  }

  void _showAlreadySubscribedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary, size: 24.sp),
            SizedBox(width: 8.w),
            const Expanded(child: Text('أنت مشترك بالفعل')),
          ],
        ),
        content: const Text('أنت مشترك في هذه الباقة حالياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showDowngradeNotAllowedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.block, color: AppColors.warning, size: 24.sp),
            SizedBox(width: 8.w),
            const Expanded(child: Text('غير مسموح')),
          ],
        ),
        content: const Text('لا يمكنك الاشتراك في باقة أقل من باقتك الحالية.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showAlreadyHasZabayehDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24.sp),
            SizedBox(width: 8.w),
            const Expanded(child: Text('أنت مشترك بالفعل')),
          ],
        ),
        content: const Text('لديك بالفعل اشتراك في قسم الذبائح.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionConfirmDialog(ProductModel pack) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text('تأكيد الاشتراك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الباقة: ${pack.name}'),
            SizedBox(height: 8.h),
            Text(
              'السعر: ${pack.price} ر.س',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 16.h),
            const Text('سيتم تفعيل الباقة فوراً بعد التأكيد.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Add pack to cart and navigate to checkout
              context.read<CartCubit>().clearCart();
              context.read<CartCubit>().addItem(pack);
              AppRouter.navigateTo(context, Routes.checkout);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('تأكيد الاشتراك'),
          ),
        ],
      ),
    );
  }

  void _showLockedPackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.warning, size: 24.sp),
            SizedBox(width: 8.w),
            const Expanded(child: Text('باقة مقيدة')),
          ],
        ),
        content: const Text(
          'باقة الزباية متاحة فقط لمشتركي الباقة الفضية أو الذهبية.\n\nيرجى الترقية أولاً للوصول إلى هذه الباقة المميزة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

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
          'باقات الاشتراك',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : _subscriptionPacks.isEmpty
          ? _buildEmptyState()
          : _buildSubscriptionList(isDark),
    );
  }

  Widget _buildErrorState() {
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
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _loadSubscriptionPacks,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_membership_rounded,
              size: 64.sp,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16.h),
            Text(
              'لا توجد باقات اشتراك متاحة حالياً',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'يرجى المحاولة لاحقاً',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionList(bool isDark) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _subscriptionPacks.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index * 100),
          child: _buildSubscriptionCard(
            _subscriptionPacks[index],
            isDark,
            index,
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionCard(ProductModel pack, bool isDark, int index) {
    // Determine tier styling based on product name or index
    final tierInfo = _getTierInfo(pack.name, index);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        gradient: tierInfo.gradient,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: tierInfo.shadowColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(2.w),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tier Badge
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: tierInfo.gradient,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tierInfo.icon, color: Colors.white, size: 16.sp),
                      SizedBox(width: 6.w),
                      Text(
                        tierInfo.tierName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${pack.price} ر.س',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Pack Name
            Text(
              pack.name,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),

            // Description
            if (pack.shortDescription.isNotEmpty)
              Text(
                pack.shortDescription.replaceAll(RegExp(r'<[^>]*>'), ''),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            SizedBox(height: 16.h),

            // Features List
            ...tierInfo.features.map(
              (feature) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Subscribe Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _subscribeToPack(pack),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isZabayehLocked(pack.id)
                      ? AppColors.textSecondary.withValues(alpha: 0.5)
                      : tierInfo.buttonColor,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isZabayehLocked(pack.id)) ...[
                      Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Text(
                      _isZabayehLocked(pack.id)
                          ? 'مقيد - ترقية مطلوبة'
                          : 'اشترك الآن',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  _TierInfo _getTierInfo(String packName, int index) {
    final nameLower = packName.toLowerCase();

    if (nameLower.contains('ذهبي') ||
        nameLower.contains('gold') ||
        index == 2) {
      return _TierInfo(
        tierName: 'ذهبي',
        icon: Icons.workspace_premium,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        shadowColor: const Color(0xFFFFD700),
        buttonColor: const Color(0xFFFFB300),
        features: [
          'عرض مميز للإعلانات',
          'دعم فني متقدم',
          'إحصائيات مفصلة',
          'بدون عمولة',
        ],
      );
    } else if (nameLower.contains('فضي') ||
        nameLower.contains('silver') ||
        index == 1) {
      return _TierInfo(
        tierName: 'فضي',
        icon: Icons.verified,
        gradient: const LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
        ),
        shadowColor: const Color(0xFF808080),
        buttonColor: const Color(0xFF9E9E9E),
        features: ['ظهور أفضل في البحث', 'دعم فني سريع', 'عمولة مخفضة'],
      );
    } else if (nameLower.contains('الزباية') || nameLower.contains('zabayeh')) {
      return _TierInfo(
        tierName: 'الزباية',
        icon: Icons.check_circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
        ),
        shadowColor: AppColors.error,
        buttonColor: AppColors.error,
        features: [
          'شارة الزباية المميزة',
          'أولوية في العرض',
          'دعم VIP',
          'بدون عمولة',
        ],
      );
    } else {
      // Bronze / Default
      return _TierInfo(
        tierName: 'برونزي',
        icon: Icons.star,
        gradient: const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
        ),
        shadowColor: const Color(0xFFCD7F32),
        buttonColor: const Color(0xFFCD7F32),
        features: ['حساب تاجر أساسي', 'إضافة إعلانات', 'دعم فني'],
      );
    }
  }
}

class _TierInfo {
  final String tierName;
  final IconData icon;
  final LinearGradient gradient;
  final Color shadowColor;
  final Color buttonColor;
  final List<String> features;

  _TierInfo({
    required this.tierName,
    required this.icon,
    required this.gradient,
    required this.shadowColor,
    required this.buttonColor,
    required this.features,
  });
}
