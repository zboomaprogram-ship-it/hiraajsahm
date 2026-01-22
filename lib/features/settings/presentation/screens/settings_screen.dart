import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          'الإعدادات',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Settings Section
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildSectionTitle('إعدادات التطبيق', isDark),
            ),
            SizedBox(height: 12.h),
            FadeInUp(
              delay: const Duration(milliseconds: 50),
              duration: const Duration(milliseconds: 300),
              child: _buildSettingsCard([
                _buildThemeToggle(context, isDark),
                _buildDivider(),
                _buildLanguageOption(context, isDark),
              ], isDark),
            ),
            SizedBox(height: 24.h),

            // Support Section
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 300),
              child: _buildSectionTitle('الدعم والمساعدة', isDark),
            ),
            SizedBox(height: 12.h),
            FadeInUp(
              delay: const Duration(milliseconds: 150),
              duration: const Duration(milliseconds: 300),
              child: _buildSettingsCard([
                _buildSettingsTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'تواصل معنا',
                  subtitle: 'واتساب، هاتف',
                  isDark: isDark,
                  onTap: () => AppRouter.navigateTo(context, Routes.contactUs),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'سياسة الخصوصية',
                  subtitle: 'اقرأ سياسة الخصوصية',
                  isDark: isDark,
                  onTap: () => _openWebView(
                    context,
                    'سياسة الخصوصية',
                    'https://hiraajsahm.com/%d8%b3%d9%8a%d8%a7%d8%b3%d8%a9-%d8%a7%d9%84%d8%a7%d8%b3%d8%aa%d8%ae%d8%af%d8%a7%d9%85/',
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.description_outlined,
                  title: 'الشروط والأحكام',
                  subtitle: 'اقرأ الشروط والأحكام',
                  isDark: isDark,
                  onTap: () => _openWebView(
                    context,
                    'الشروط والأحكام',
                    'https://hiraajsahm.com/terms',
                  ),
                ),
              ], isDark),
            ),
            SizedBox(height: 24.h),

            // Security Section
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                if (state is! AuthAuthenticated) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      duration: const Duration(milliseconds: 300),
                      child: _buildSectionTitle('الأمان', isDark),
                    ),
                    SizedBox(height: 12.h),
                    FadeInUp(
                      delay: const Duration(milliseconds: 250),
                      duration: const Duration(milliseconds: 300),
                      child: _buildSettingsCard([
                        _buildSettingsTile(
                          icon: Icons.person_outline,
                          title: 'تعديل البيانات الشخصية',
                          subtitle: 'الاسم، البريد الإلكتروني',
                          isDark: isDark,
                          onTap: () =>
                              AppRouter.navigateTo(context, Routes.editProfile),
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: Icons.lock_outline,
                          title: 'تغيير كلمة المرور',
                          subtitle: 'تحديث كلمة المرور',
                          isDark: isDark,
                          onTap: () => AppRouter.navigateTo(
                            context,
                            Routes.changePassword,
                          ),
                        ),
                      ], isDark),
                    ),
                    SizedBox(height: 24.h),
                  ],
                );
              },
            ),

            // Logout Button
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                if (state is! AuthAuthenticated) {
                  return const SizedBox.shrink();
                }

                return FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 300),
                  child: _buildLogoutButton(context, isDark),
                );
              },
            ),
            SizedBox(height: 32.h),

            // App Version
            Center(
              child: Text(
                'الإصدار 1.0.0',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: AppColors.border, indent: 56.w);
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        return ListTile(
          leading: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: AppColors.primary,
              size: 22.sp,
            ),
          ),
          title: Text(
            'الوضع الداكن',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          trailing: Switch.adaptive(
            value: state.themeMode == ThemeMode.dark,
            onChanged: (value) {
              context.read<ThemeCubit>().setThemeMode(
                value ? ThemeMode.dark : ThemeMode.light,
              );
            },
            activeColor: AppColors.primary,
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, bool isDark) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          Icons.language_outlined,
          color: AppColors.accent,
          size: 22.sp,
        ),
      ),
      title: Text(
        'اللغة',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textLight : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        'العربية',
        style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppColors.textSecondary,
        size: 16.sp,
      ),
      onTap: () {
        // TODO: Language selection
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('قريباً: تغيير اللغة')));
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textLight : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppColors.textSecondary,
        size: 16.sp,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _showLogoutDialog(context),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 22.sp),
            SizedBox(width: 12.w),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().logout();
              AppRouter.navigateAndRemoveUntil(context, Routes.splash);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  void _openWebView(BuildContext context, String title, String url) {
    AppRouter.navigateTo(
      context,
      Routes.webView,
      arguments: {'title': title, 'url': url},
    );
  }
}
