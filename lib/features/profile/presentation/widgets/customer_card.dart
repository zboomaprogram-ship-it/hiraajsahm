import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/colors.dart';
import '../../../auth/data/models/user_model.dart';

class ProfileQRCard extends StatelessWidget {
  final UserModel user;

  const ProfileQRCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final hasQr = user.customerQrUrl != null && user.customerQrUrl!.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: (user.tier == UserTier.gold || user.tier == UserTier.zabayeh)
            ? AppColors.goldGradient
            : user.tier == UserTier.silver
            ? AppColors.silverGradient
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color:
                ((user.tier == UserTier.gold || user.tier == UserTier.zabayeh)
                        ? Colors.orange
                        : user.tier == UserTier.silver
                        ? Colors.blueGrey
                        : AppColors.primary)
                    .withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        _getTierName(user.tier),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // App Logo or Icon
              Image.asset(
                'assets/images/logo.png', // Fallback to icon if not found
                height: 40.h,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.stars_rounded, color: Colors.white, size: 40.sp),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // QR Code Section
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: hasQr
                ? CachedNetworkImage(
                    imageUrl: user.customerQrUrl!,
                    height: 120.h,
                    width: 120.h,
                    placeholder: (context, url) => SizedBox(
                      height: 120.h,
                      width: 120.h,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.qr_code_2_rounded,
                      size: 80.sp,
                      color: Colors.grey[400],
                    ),
                  )
                : Icon(
                    Icons.qr_code_2_rounded,
                    size: 80.sp,
                    color: Colors.grey[400],
                  ),
          ),
        ],
      ),
    );
  }

  String _getTierName(UserTier tier) {
    switch (tier) {
      case UserTier.gold:
      case UserTier.zabayeh:
        return 'العضوية الذهبية';
      case UserTier.silver:
        return 'العضوية الفضية';
      case UserTier.bronze:
        return 'العضوية البرونزية';
    }
  }
}
