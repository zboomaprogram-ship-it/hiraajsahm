import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../vendor/presentation/screens/vendor_dashboard_screen.dart';
import '../../../auth/data/models/user_model.dart';
import '../widgets/subscription_card.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/profile_cubit.dart';

/// Profile Screen - Customer/Vendor Dashboard
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => sl<ProfileCubit>(),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          if (authState is AuthAuthenticated) {
            return BlocConsumer<ProfileCubit, ProfileState>(
              listener: (context, profileState) {
                if (profileState is ProfileImageUpdated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث الصورة الشخصية بنجاح'),
                    ),
                  );
                  // Optionally refresh auth user data if needed to show new image instantly
                  // context.read<AuthCubit>().refreshProfile();
                } else if (profileState is ProfileError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'فشل تحديث الصورة: ${profileState.message}',
                      ),
                    ),
                  );
                }
              },
              builder: (context, profileState) {
                return _buildCustomerProfile(
                  context,
                  authState,
                  isDark,
                  profileState,
                );
              },
            );
          }

          // Not authenticated
          return _buildLoginPrompt(context, isDark);
        },
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 60.sp,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 400),
                child: Text(
                  'مرحباً بك',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              FadeInUp(
                delay: const Duration(milliseconds: 150),
                duration: const Duration(milliseconds: 400),
                child: Text(
                  'سجل دخولك للوصول إلى حسابك وإدارة طلباتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Login Button
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 400),
                child: Container(
                  width: double.infinity,
                  height: 52.h,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      AppRouter.navigateTo(context, Routes.login);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Register Button
              FadeInUp(
                delay: const Duration(milliseconds: 250),
                duration: const Duration(milliseconds: 400),
                child: OutlinedButton(
                  onPressed: () {
                    AppRouter.navigateTo(context, Routes.register);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 52.h),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'إنشاء حساب جديد',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerProfile(
    BuildContext context,
    AuthAuthenticated state,
    bool isDark,
    ProfileState profileState,
  ) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: _buildProfileHeader(context, state, isDark, profileState),
          ),

          // Subscription Plan Card
          SliverToBoxAdapter(
            child: FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: SubscriptionCard(user: state.user),
            ),
          ),

          // Vendor Banner - different for vendors vs customers
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 400),
              child: state.user.isVendor
                  ? _buildVendorDashboardBanner(context)
                  : _buildBecomeVendorBanner(context),
            ),
          ),

          // Menu Items
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    duration: const Duration(milliseconds: 400),
                    child: _buildMenuSection(
                      title: 'طلباتي',
                      items: [
                        _MenuItem(
                          icon: Icons.shopping_bag_outlined,
                          title: 'طلباتي',
                          subtitle: 'تتبع حالة طلباتك',
                          onTap: () =>
                              AppRouter.navigateTo(context, Routes.orders),
                        ),
                      ],
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  FadeInUp(
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 400),
                    child: _buildMenuSection(
                      title: 'الإعدادات',
                      items: [
                        _MenuItem(
                          icon: Icons.settings_outlined,
                          title: 'الإعدادات العامة',
                          onTap: () =>
                              AppRouter.navigateTo(context, Routes.settings),
                        ),
                        _MenuItem(
                          icon: Icons.location_on_outlined,
                          title: 'العناوين',
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.notifications_outlined,
                          title: 'الإشعارات',
                          onTap: () {},
                        ),
                      ],
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 400),
                    child: _buildMenuSection(
                      title: 'أخرى',
                      items: [
                        _MenuItem(
                          icon: Icons.help_outline_rounded,
                          title: 'المساعدة والدعم',
                          onTap: () =>
                              AppRouter.navigateTo(context, Routes.contactUs),
                        ),
                        _MenuItem(
                          icon: Icons.info_outline_rounded,
                          title: 'عن التطبيق',
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.logout_rounded,
                          title: 'تسجيل الخروج',
                          color: AppColors.error,
                          onTap: () {
                            _showLogoutDialog(context);
                          },
                        ),
                      ],
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 100.h)),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    AuthAuthenticated state,
    bool isDark,
    ProfileState profileState,
  ) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20.h,
        left: 20.w,
        right: 20.w,
        bottom: 30.h,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32.r)),
      ),
      child: Column(
        children: [
          // Avatar with Tier Badge Ring
          GestureDetector(
            onTap: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
              );
              if (image != null && context.mounted) {
                context.read<ProfileCubit>().uploadProfileImage(
                  File(image.path),
                );
              }
            },
            child: Stack(
              children: [
                Container(
                  width: 110.w,
                  height: 110.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getTierColor(state.user.tier),
                      width: 4.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getTierColor(state.user.tier).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      image: (profileState is ProfileImageUpdated)
                          ? DecorationImage(
                              image: NetworkImage(profileState.imageUrl),
                              fit: BoxFit.cover,
                            )
                          : (state.user.avatarUrl != null &&
                                state.user.avatarUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(state.user.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        (profileState is ProfileImageUpdated ||
                            (state.user.avatarUrl != null &&
                                state.user.avatarUrl!.isNotEmpty))
                        ? null
                        : Center(
                            child: profileState is ProfileLoading
                                ? const CircularProgressIndicator()
                                : Text(
                                    state.user.displayName.isNotEmpty
                                        ? state.user.displayName[0]
                                              .toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 40.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                  ),
                ),
                if (profileState is ProfileLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Name with Al-Zabayeh red check
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.user.fullName.isNotEmpty ? state.user.fullName : 'مستخدم',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (state.user.hasAlZabayehTier) ...[
                SizedBox(width: 6.w),
                Icon(Icons.check_circle, color: Colors.red, size: 20.sp),
              ],
            ],
          ),
          SizedBox(height: 4.h),

          // User Tier Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _getTierColor(state.user.tier).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: _getTierColor(state.user.tier).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Text(
              _getTierName(state.user.tier),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 8.h),

          // Email
          Text(
            state.user.email,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 20.h),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('طلباتي', '0'),
              Container(
                width: 1,
                height: 40.h,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildStatItem('التقييمات', '0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBecomeVendorBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppRouter.navigateTo(context, Routes.vendorSubscription);
      },
      child: Container(
        margin: EdgeInsets.all(20.w),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                Icons.store_rounded,
                color: Colors.white,
                size: 32.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كن بائعاً معنا',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'ابدأ ببيع منتجاتك وحقق أرباحاً',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorDashboardBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VendorDashboardScreen()),
        );
      },
      child: Container(
        margin: EdgeInsets.all(20.w),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 32.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لوحة التحكم',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'إدارة متجرك ومنتجاتك',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MenuItem> items,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    leading: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: (item.color ?? AppColors.primary).withOpacity(
                          0.1,
                        ),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.color ?? AppColors.primary,
                        size: 22.sp,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            item.color ??
                            (isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary),
                      ),
                    ),
                    subtitle: item.subtitle != null
                        ? Text(
                            item.subtitle!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                    trailing:
                        item.trailing ??
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16.sp,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (index < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 70.w,
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthCubit>().logout();
              Navigator.pop(ctx);
              AppRouter.navigateAndRemoveUntil(context, Routes.login);
            },
            child: Text('خروج', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(UserTier tier) {
    switch (tier) {
      case UserTier.gold:
        return const Color(0xFFFFD700);
      case UserTier.silver:
        return const Color(0xFFC0C0C0);
      case UserTier.bronze:
        return const Color(0xFFCD7F32);
    }
  }

  String _getTierName(UserTier tier) {
    switch (tier) {
      case UserTier.gold:
        return 'ذهبي';
      case UserTier.silver:
        return 'فضي';
      case UserTier.bronze:
        return 'برونزي';
    }
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
    required this.onTap,
  });
}
