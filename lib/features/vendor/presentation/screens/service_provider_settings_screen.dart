import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';

class ServiceProviderSettingsScreen extends StatelessWidget {
  const ServiceProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(
          'مقدمي الخدمة',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildRoleCard(
                context,
                title: 'تسجيل كمندوب توصيل',
                icon: Icons.delivery_dining_rounded,
                color: Colors.blue,
                description: 'انضم إلينا وقم بتوصيل الطلبات للعملاء.',
                onTap: () => _registerAsProvider(context, 'Delivery'),
                isDark: isDark,
              ),
            ),
            SizedBox(height: 20.h),
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 300),
              child: _buildRoleCard(
                context,
                title: 'تسجيل كمعاين',
                icon: Icons.fact_check_rounded,
                color: Colors.green,
                description: 'كن خبيراً في فحص المنتجات ومطابقتها.',
                onTap: () => _registerAsProvider(context, 'Inspector'),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32.sp),
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
                  SizedBox(height: 8.h),
                  Text(
                    description,
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
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  void _registerAsProvider(BuildContext context, String type) {
    // Placeholder logic
    debugPrint('Selected Provider Type: $type');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم اختيار التسجيل كـ: ${type == 'Delivery' ? 'مندوب توصيل' : 'معاين'}',
        ),
        backgroundColor: AppColors.success,
      ),
    );
    // Future: Show dialog to confirm phone/region
  }
}
