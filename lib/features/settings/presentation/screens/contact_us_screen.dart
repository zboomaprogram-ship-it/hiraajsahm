import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';

/// Contact Us Screen
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  // TODO: Replace with actual contact info
  static const String whatsappNumber = '+966500000000';
  static const String phoneNumber = '+966500000000';
  static const String email = 'support@hiraajsahm.com';

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
          'تواصل معنا',
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
          children: [
            // Header Image/Icon
            FadeInDown(
              duration: const Duration(milliseconds: 400),
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 60.sp,
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Title
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 400),
              child: Text(
                'كيف يمكننا مساعدتك؟',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            FadeInDown(
              delay: const Duration(milliseconds: 150),
              duration: const Duration(milliseconds: 400),
              child: Text(
                'اختر طريقة التواصل المفضلة لديك',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(height: 40.h),

            // WhatsApp Card
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 400),
              child: _buildContactCard(
                icon: Icons.message_rounded,
                iconColor: const Color(0xFF25D366),
                title: 'واتساب',
                subtitle: 'تواصل معنا عبر الواتساب',
                isDark: isDark,
                onTap: () => _launchWhatsApp(),
              ),
            ),
            SizedBox(height: 16.h),

            // Phone Card
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 400),
              child: _buildContactCard(
                icon: Icons.phone_rounded,
                iconColor: AppColors.primary,
                title: 'الهاتف',
                subtitle: phoneNumber,
                isDark: isDark,
                onTap: () => _launchPhone(),
              ),
            ),
            SizedBox(height: 16.h),

            // Email Card
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 400),
              child: _buildContactCard(
                icon: Icons.email_rounded,
                iconColor: AppColors.accent,
                title: 'البريد الإلكتروني',
                subtitle: email,
                isDark: isDark,
                onTap: () => _launchEmail(),
              ),
            ),
            SizedBox(height: 40.h),

            // Working Hours
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: EdgeInsets.all(20.w),
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
                child: Column(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primary,
                      size: 32.sp,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'أوقات العمل',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'السبت - الخميس\n9:00 صباحاً - 6:00 مساءً',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                        height: 1.5,
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

  Widget _buildContactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.w),
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
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(icon, color: iconColor, size: 28.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/${whatsappNumber.replaceAll('+', '')}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone() async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _launchEmail() async {
    final url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
