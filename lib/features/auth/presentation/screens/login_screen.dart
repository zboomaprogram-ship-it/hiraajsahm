import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../cubit/auth_cubit.dart';

/// Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            AppRouter.navigateAndRemoveUntil(context, Routes.main);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 40.h),

                      // Logo & Header
                      FadeInDown(
                        duration: const Duration(milliseconds: 500),
                        child: _buildHeader(context, isDark),
                      ),

                      SizedBox(height: 48.h),

                      // Username Field
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: _buildUsernameField(isDark),
                      ),

                      SizedBox(height: 20.h),

                      // Password Field
                      FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        duration: const Duration(milliseconds: 500),
                        child: _buildPasswordField(isDark),
                      ),

                      SizedBox(height: 16.h),

                      // Remember Me & Forgot Password
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 500),
                        child: _buildRememberAndForgot(isDark),
                      ),

                      SizedBox(height: 20.h),

                      // Login Button
                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        duration: const Duration(milliseconds: 500),
                        child: _buildLoginButton(context, state),
                      ),

                      // SizedBox(height: 24.h),

                      // // Divider
                      // FadeInUp(
                      //   delay: const Duration(milliseconds: 400),
                      //   duration: const Duration(milliseconds: 500),
                      //   child: _buildDivider(isDark),
                      // ),

                      // SizedBox(height: 24.h),

                      // // Social Login
                      // FadeInUp(
                      //   delay: const Duration(milliseconds: 500),
                      //   duration: const Duration(milliseconds: 500),
                      //   child: _buildSocialLogin(isDark),
                      // ),
                      SizedBox(height: 32.h),

                      // Register Link
                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        duration: const Duration(milliseconds: 500),
                        child: _buildRegisterLink(context, isDark),
                      ),

                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 60.w,
                  height: 60.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'مرحباً بك',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'سجل دخولك للوصول إلى متجرك',
            style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'البريد الإلكتروني أو اسم المستخدم',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _usernameController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'أدخل بريدك الإلكتروني',
            prefixIcon: Icon(
              Icons.email_outlined,
              color: AppColors.textSecondary,
              size: 22.sp,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال البريد الإلكتروني';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'كلمة المرور',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'أدخل كلمة المرور',
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
              size: 22.sp,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 22.sp,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال كلمة المرور';
            }
            if (value.length < 6) {
              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRememberAndForgot(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              width: 24.w,
              height: 24.h,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'تذكرني',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // Navigate to forgot password
          },
          child: Text(
            'نسيت كلمة المرور؟',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context, AuthState state) {
    final isLoading = state is AuthLoading;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                if (_formKey.currentState!.validate()) {
                  context.read<AuthCubit>().login(
                    username: _usernameController.text.trim(),
                    password: _passwordController.text,
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'تسجيل الدخول',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'أو',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLogin(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(
          icon: Icons.g_mobiledata_rounded,
          color: const Color(0xFFDB4437),
          onTap: () {},
        ),
        SizedBox(width: 20.w),
        _buildSocialButton(
          icon: Icons.facebook_rounded,
          color: const Color(0xFF1877F2),
          onTap: () {},
        ),
        SizedBox(width: 20.w),
        _buildSocialButton(
          icon: Icons.apple_rounded,
          color: isDark ? Colors.white : Colors.black,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 32.sp),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟',
          style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: () {
            AppRouter.navigateTo(context, Routes.register);
          },
          child: Text(
            'سجل الآن',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
