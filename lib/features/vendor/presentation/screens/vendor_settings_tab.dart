import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class VendorSettingsTab extends StatelessWidget {
  const VendorSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.login,
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.background,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              _buildProfileCard(context, isDark),
              SizedBox(height: 24.h),
              _buildSettingsSection(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool isDark) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final user = state.user;
          return Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.card,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: ClipOval(
                    child: (user.avatarUrl ?? '').isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const CircularProgressIndicator(),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.person),
                          )
                        : const Icon(
                            Icons.person,
                            color: AppColors.textSecondary,
                          ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.firstName} ${user.lastName}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => AppRouter.navigateTo(
                    context,
                    Routes.storeDetails,
                    arguments: user.id,
                  ),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            context,
            icon: Icons.person_outline_rounded,
            title: 'عرض المتجر',
            onTap: () {
              // Get current user ID from AuthCubit
              final state = context.read<AuthCubit>().state;
              if (state is AuthAuthenticated) {
                AppRouter.navigateTo(
                  context,
                  Routes.storeDetails,
                  arguments: state.user.id,
                );
              }
            },
            isDark: isDark,
          ),
          const Divider(height: 1),
          // Modify Profile (Added)
          _buildSettingsItem(
            context,
            icon: Icons.edit_note_rounded,
            title: 'تعديل الملف الشخصي',
            onTap: () {
              final state = context.read<AuthCubit>().state;
              if (state is AuthAuthenticated) {
                Navigator.pushNamed(
                  context,
                  Routes.vendorEditProfile,
                  arguments: state.user.id,
                );
              }
            },
            isDark: isDark,
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'تغيير كلمة المرور',
            onTap: () => Navigator.pushNamed(context, Routes.changePassword),
            isDark: isDark,
          ),
          const Divider(height: 1),
          // Theme Toggle
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              final isDarkMode = state.themeMode == ThemeMode.dark;
              return SwitchListTile(
                title: Text(
                  'الوضع الليلي',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                secondary: Icon(
                  isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: AppColors.primary,
                ),
                value: isDarkMode,
                onChanged: (value) {
                  context.read<ThemeCubit>().toggleTheme();
                },
                activeThumbColor: AppColors.primary,
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            context,
            icon: Icons.support_agent_rounded,
            title: 'الدعم الفني',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم تفعيل الدعم قريباً')),
              );
            },
            isDark: isDark,
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            context,
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            color: AppColors.error,
            onTap: () => _showLogoutDialog(context),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 20.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color:
              color ?? (isDark ? AppColors.textLight : AppColors.textPrimary),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthCubit>().logout();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}
